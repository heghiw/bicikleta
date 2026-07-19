from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user
import models
import schemas
from models import _haversine

POINTS_PER_HOUR = 5   # bonus points for completing a rental
router = APIRouter(prefix="/api/rentals", tags=["rentals"])


@router.post("/", response_model=schemas.RentalOut, status_code=status.HTTP_201_CREATED)
def book_bike(
    body: schemas.RentalCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Reserve a bike.  User must be verified and within 1 km of the bike."""
    if not current_user.verified:
        raise HTTPException(status_code=403, detail="Account not yet verified")

    bike = db.query(models.Bike).filter(models.Bike.id == body.bike_id).first()
    if not bike:
        raise HTTPException(status_code=404, detail="Bike not found")
    if bike.status != models.BikeStatus.available:
        raise HTTPException(status_code=409, detail="Bike is not available")

    dist = bike.distance_to(body.pickup_lat, body.pickup_lon)
    if dist > 1.0:
        raise HTTPException(
            status_code=400,
            detail=f"You are {dist:.2f} km from the bike. Must be within 1 km to book.",
        )

    bike.status = models.BikeStatus.reserved
    rental = models.Rental(
        bike_id=bike.id,
        renter_id=current_user.id,
        pickup_lat=body.pickup_lat,
        pickup_lon=body.pickup_lon,
        status=models.RentalStatus.pending,
    )
    db.add(rental)
    db.commit()
    db.refresh(rental)
    return rental


@router.post("/{rental_id}/start", response_model=schemas.RentalOut)
def start_rental(
    rental_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Confirm bike pickup — starts the rental clock."""
    rental = _get_rental(db, rental_id, current_user.id)
    if rental.status != models.RentalStatus.pending:
        raise HTTPException(status_code=409, detail=f"Rental is {rental.status}")
    rental.status = models.RentalStatus.active
    rental.start_time = datetime.utcnow()
    db.commit()
    db.refresh(rental)
    return rental


@router.post("/{rental_id}/end", response_model=schemas.RentalOut)
def end_rental(
    rental_id: int,
    body: schemas.RentalEnd,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the bike and finalise payment + points."""
    rental = _get_rental(db, rental_id, current_user.id)
    if rental.status != models.RentalStatus.active:
        raise HTTPException(status_code=409, detail=f"Rental is {rental.status}")

    now = datetime.utcnow()
    duration_hours = max(0.25, (now - rental.start_time).total_seconds() / 3600)
    price = round(rental.bike.hourly_price * duration_hours, 2)
    points = max(1, int(duration_hours * POINTS_PER_HOUR))

    rental.end_time = now
    rental.return_lat = body.return_lat
    rental.return_lon = body.return_lon
    rental.total_price = price
    rental.status = models.RentalStatus.completed

    # Update bike location and status
    rental.bike.current_lat = body.return_lat
    rental.bike.current_lon = body.return_lon
    rental.bike.status = models.BikeStatus.available

    # Award points
    tx = models.PointTransaction(
        user_id=current_user.id,
        type=models.PointType.earned,
        amount=points,
        description=f"Rental #{rental.id} — {duration_hours:.1f}h",
    )
    db.add(tx)

    # Update gamification
    g = current_user.gamification
    if g:
        km = _haversine(rental.pickup_lat, rental.pickup_lon, body.return_lat, body.return_lon)
        g.add_activity(km=km, rentals=1)

    db.commit()
    db.refresh(rental)
    return rental


@router.post("/{rental_id}/cancel", response_model=schemas.RentalOut)
def cancel_rental(
    rental_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rental = _get_rental(db, rental_id, current_user.id)
    if rental.status not in (models.RentalStatus.pending, models.RentalStatus.active):
        raise HTTPException(status_code=409, detail=f"Cannot cancel — rental is {rental.status}")
    rental.status = models.RentalStatus.cancelled
    rental.bike.status = models.BikeStatus.available
    db.commit()
    db.refresh(rental)
    return rental


@router.get("/", response_model=List[schemas.RentalOut])
def list_my_rentals(current_user: models.User = Depends(get_current_user)):
    return current_user.rentals


@router.post("/{rental_id}/review", response_model=schemas.ReviewOut, status_code=201)
def leave_review(
    rental_id: int,
    body: schemas.ReviewCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Leave a review after completing a rental."""
    rental = _get_rental(db, rental_id, current_user.id)
    if rental.status != models.RentalStatus.completed:
        raise HTTPException(status_code=409, detail="Can only review completed rentals")

    existing = db.query(models.Review).filter(
        models.Review.rental_id == rental_id,
        models.Review.reviewer_id == current_user.id,
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Already reviewed this rental")

    review = models.Review(
        bike_id=rental.bike_id,
        reviewer_id=current_user.id,
        rental_id=rental_id,
        rating=body.rating,
        comment=body.comment,
    )
    db.add(review)

    # Update bike owner avg rating
    bike = rental.bike
    ratings = [r.rating for r in bike.reviews] + [body.rating]
    bike.owner.rating = round(sum(ratings) / len(ratings), 2)

    db.commit()
    db.refresh(review)
    return review


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_rental(db: Session, rental_id: int, user_id: int) -> models.Rental:
    rental = (
        db.query(models.Rental)
        .filter(models.Rental.id == rental_id, models.Rental.renter_id == user_id)
        .first()
    )
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")
    return rental
