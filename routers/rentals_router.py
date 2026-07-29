from datetime import datetime, timedelta
import hmac
import os
import uuid
from typing import List
import aiofiles
import stripe
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user
import models
import schemas
from models import _haversine

POINTS_PER_HOUR = 5   # bonus points for completing a rental
RESERVATION_MINUTES = 15
RETURN_PHOTO_DIR = os.path.join(os.getenv("UPLOAD_DIR", "data/uploads"), "rental_returns")
os.makedirs(RETURN_PHOTO_DIR, exist_ok=True)
PARKING_ZONES = [
    {"id": "old-town", "name": "Old Town", "lat": 50.0870, "lon": 14.4208, "radius_m": 650},
    {"id": "karlin", "name": "Karlín", "lat": 50.0920, "lon": 14.4530, "radius_m": 650},
    {"id": "vinohrady", "name": "Vinohrady", "lat": 50.0755, "lon": 14.4378, "radius_m": 650},
]
router = APIRouter(prefix="/rentals", tags=["rentals"])


@router.get("/parking-zones", response_model=List[schemas.ParkingZoneOut])
def list_parking_zones():
    return PARKING_ZONES


@router.post("/payment-intent", response_model=schemas.PaymentIntentOut)
def create_payment_intent(
    body: schemas.PaymentIntentCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bike = db.query(models.Bike).filter(models.Bike.id == body.bike_id).first()
    if not bike or bike.status != models.BikeStatus.available:
        raise HTTPException(status_code=409, detail="Bike is not available")
    amount = round(max(bike.deposit, bike.daily_price, bike.hourly_price), 2)
    secret = os.getenv("STRIPE_SECRET_KEY")
    if not secret:
        return {"provider": "demo", "payment_intent_id": f"demo_{uuid.uuid4().hex}",
                "authorized_amount": amount, "currency": "eur"}
    stripe.api_key = secret
    intent = stripe.PaymentIntent.create(
        amount=max(50, int(amount * 100)), currency="eur", capture_method="manual",
        automatic_payment_methods={"enabled": True},
        metadata={"bike_id": bike.id, "user_id": current_user.id},
    )
    return {"provider": "stripe", "payment_intent_id": intent.id,
            "client_secret": intent.client_secret, "authorized_amount": amount,
            "currency": "eur"}


@router.post("/", response_model=schemas.RentalOut, status_code=status.HTTP_201_CREATED)
def book_bike(
    body: schemas.RentalCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Reserve a bike.  User must be verified and within 1 km of the bike."""
    if not current_user.verified:
        raise HTTPException(status_code=403, detail="Account not yet verified")

    existing = (
        db.query(models.Rental)
        .filter(
            models.Rental.renter_id == current_user.id,
            models.Rental.status.in_([
                models.RentalStatus.pending,
                models.RentalStatus.active,
            ]),
        )
        .order_by(models.Rental.created_at.desc())
        .first()
    )
    if existing and existing.status == models.RentalStatus.pending:
        expires_at = existing.created_at + timedelta(minutes=RESERVATION_MINUTES)
        if datetime.utcnow() > expires_at:
            existing.status = models.RentalStatus.cancelled
            existing.bike.status = models.BikeStatus.available
            db.commit()
            existing = None
    if existing:
        raise HTTPException(
            status_code=409,
            detail="Finish or cancel your current rental before booking another bike",
        )

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

    payment_provider = "demo" if body.payment_intent_id.startswith("demo_") else "stripe"
    authorized_amount = round(max(bike.deposit, bike.daily_price, bike.hourly_price), 2)
    if payment_provider == "stripe":
        secret = os.getenv("STRIPE_SECRET_KEY")
        if not secret:
            raise HTTPException(status_code=503, detail="Stripe is not configured")
        stripe.api_key = secret
        intent = stripe.PaymentIntent.retrieve(body.payment_intent_id)
        if intent.status != "requires_capture" or str(intent.metadata.get("user_id")) != str(current_user.id):
            raise HTTPException(status_code=402, detail="Payment authorization is incomplete")

    bike.status = models.BikeStatus.reserved
    rental = models.Rental(
        bike_id=bike.id,
        renter_id=current_user.id,
        pickup_lat=body.pickup_lat,
        pickup_lon=body.pickup_lon,
        status=models.RentalStatus.pending,
        payment_provider=payment_provider,
        payment_intent_id=body.payment_intent_id,
        payment_status="authorized",
        authorized_amount=authorized_amount,
    )
    db.add(rental)
    db.commit()
    db.refresh(rental)
    return rental


@router.post("/{rental_id}/return-photo", response_model=schemas.RentalOut)
async def upload_return_photo(
    rental_id: int,
    photo: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rental = _get_rental(db, rental_id, current_user.id)
    if rental.status != models.RentalStatus.active:
        raise HTTPException(status_code=409, detail="Rental is not active")
    if photo.content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(status_code=400, detail="Return photo must be JPEG, PNG, or WebP")
    content = await photo.read()
    if not content or len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Return photo must be under 10 MB")
    extension = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}[photo.content_type]
    filename = f"rental-{rental.id}-{uuid.uuid4().hex}{extension}"
    async with aiofiles.open(os.path.join(RETURN_PHOTO_DIR, filename), "wb") as output:
        await output.write(content)
    rental.return_photo_url = f"/uploads/rental_returns/{filename}"
    db.commit()
    db.refresh(rental)
    return rental


@router.get("/{rental_id}/lock", response_model=schemas.RentalLockOut)
def get_rental_lock(
    rental_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rental = _get_rental(db, rental_id, current_user.id)
    if rental.status not in (models.RentalStatus.pending, models.RentalStatus.active):
        raise HTTPException(status_code=409, detail="Lock details are no longer available")
    bike = rental.bike
    return {"lock_type": bike.lock_type,
            "instructions": bike.lock_instructions if bike.lock_type == "manual" else None,
            "provider": bike.smart_lock_provider if bike.lock_type == "smart" else None,
            "status": bike.smart_lock_status if bike.lock_type == "smart" else "owner_managed"}


@router.post("/{rental_id}/start", response_model=schemas.RentalOut)
def start_rental(
    rental_id: int,
    body: schemas.RentalStart,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Confirm bike pickup — starts the rental clock."""
    rental = _get_rental(db, rental_id, current_user.id)
    if rental.status != models.RentalStatus.pending:
        raise HTTPException(status_code=409, detail=f"Rental is {rental.status}")
    if not hmac.compare_digest(body.bike_qr.strip(), rental.bike.identity_qr):
        raise HTTPException(status_code=403, detail="This QR code belongs to a different bike")
    if rental.bike.lock_type == "smart" and rental.bike.smart_lock_status != "connected":
        raise HTTPException(status_code=409, detail="The smart lock is not connected")
    if datetime.utcnow() > rental.created_at + timedelta(minutes=RESERVATION_MINUTES):
        rental.status = models.RentalStatus.cancelled
        rental.bike.status = models.BikeStatus.available
        db.commit()
        raise HTTPException(status_code=410, detail="Reservation expired")
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
    if not rental.return_photo_url:
        raise HTTPException(status_code=409, detail="Add a parked-bike photo before finishing")
    if not body.lock_confirmed:
        raise HTTPException(status_code=409, detail="Confirm that the bike is locked")
    in_zone = any(
        _haversine(body.return_lat, body.return_lon, zone["lat"], zone["lon"])
        <= zone["radius_m"] / 1000
        for zone in PARKING_ZONES
    )
    if not in_zone:
        raise HTTPException(status_code=400, detail="Park inside a marked Bicikleta parking zone")

    now = datetime.utcnow()
    duration_hours = max(0.25, (now - rental.start_time).total_seconds() / 3600)
    price = round(rental.bike.hourly_price * duration_hours, 2)
    points = max(1, int(duration_hours * POINTS_PER_HOUR))

    rental.end_time = now
    rental.return_lat = body.return_lat
    rental.return_lon = body.return_lon
    rental.total_price = price
    rental.lock_confirmed = True
    rental.status = models.RentalStatus.completed
    if rental.payment_provider == "stripe" and rental.payment_intent_id:
        stripe.api_key = os.environ["STRIPE_SECRET_KEY"]
        stripe.PaymentIntent.capture(rental.payment_intent_id,
                                     amount_to_capture=max(50, int(price * 100)))
    rental.payment_status = "captured"

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
    if rental.payment_provider == "stripe" and rental.payment_intent_id:
        stripe.api_key = os.environ["STRIPE_SECRET_KEY"]
        stripe.PaymentIntent.cancel(rental.payment_intent_id)
    rental.payment_status = "cancelled"
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
