from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user
import models
import schemas
from models import _haversine

POINTS_PER_KM_DEFAULT = 1.0
# Tolerance in km: consider trip complete if user is within this distance of drop target
COMPLETION_TOLERANCE_KM = 0.2

router = APIRouter(prefix="/trips", tags=["trips"])


@router.post("/", response_model=schemas.TripOut, status_code=status.HTTP_201_CREATED)
def start_trip(
    body: schemas.StartTripRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Start transporting a bike.  The bike must be *available* and the user
    must be within 0.5 km of the bike's current position.
    """
    if not current_user.verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account not yet verified. Please wait for admin review.",
        )

    bike = db.query(models.Bike).filter(models.Bike.id == body.bike_id).first()
    if not bike:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bike not found")
    if bike.status != models.BikeStatus.available:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bike is not available")

    dist = bike.distance_to(body.start_lat, body.start_lon)
    if dist > 0.5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You are {dist:.2f} km from the bike. Must be within 0.5 km to start.",
        )

    bike.status = models.BikeStatus.in_transit
    trip = models.Trip(
        user_id=current_user.id,
        bike_id=bike.id,
        start_lat=body.start_lat,
        start_lon=body.start_lon,
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return trip


@router.post("/{trip_id}/complete", response_model=schemas.TripOut)
def complete_trip(
    trip_id: int,
    body: schemas.CompleteTripRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Mark a trip as complete (or partial if dropping midway).

    - **Full completion**: the bike is marked *delivered*.
    - **Partial drop** (`partial=true`): the bike is returned to *available*
      at its new position so another user can continue the relay.
    Points are awarded proportionally to the km covered.
    """
    trip = _get_active_trip(db, trip_id, current_user.id)
    bike = trip.bike

    km = _haversine(trip.start_lat, trip.start_lon, body.end_lat, body.end_lon)
    points = max(1, int(km * bike.points_per_km))

    trip.end_lat = body.end_lat
    trip.end_lon = body.end_lon
    trip.km = km
    trip.points_earned = points
    trip.ended_at = datetime.utcnow()

    if body.partial:
        trip.status = models.TripStatus.partial
        # Update bike position to current drop-off; keep it available for relay
        bike.current_lat = body.end_lat
        bike.current_lon = body.end_lon
        bike.status = models.BikeStatus.available
    else:
        trip.status = models.TripStatus.completed
        bike.current_lat = body.end_lat
        bike.current_lon = body.end_lon
        bike.status = models.BikeStatus.delivered

    # Award points
    current_user.points_balance += points
    tx = models.PointTransaction(
        user_id=current_user.id,
        delta=points,
        reason=f"Trip #{trip.id} — {km:.2f} km",
    )
    db.add(tx)
    db.commit()
    db.refresh(trip)
    return trip


@router.post("/{trip_id}/cancel", response_model=schemas.TripOut)
def cancel_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Cancel an active trip.  No points are awarded; bike returns to available."""
    trip = _get_active_trip(db, trip_id, current_user.id)
    trip.status = models.TripStatus.cancelled
    trip.ended_at = datetime.utcnow()
    trip.bike.status = models.BikeStatus.available
    db.commit()
    db.refresh(trip)
    return trip


@router.get("/", response_model=List[schemas.TripOut])
def list_my_trips(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    return current_user.trips


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_active_trip(db: Session, trip_id: int, user_id: int) -> models.Trip:
    trip = (
        db.query(models.Trip)
        .filter(models.Trip.id == trip_id, models.Trip.user_id == user_id)
        .first()
    )
    if not trip:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    if trip.status != models.TripStatus.active:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Trip is already {trip.status}",
        )
    return trip
