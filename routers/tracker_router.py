from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from auth import get_current_user
from database import get_db
import models
import schemas

router = APIRouter(prefix="/bikes", tags=["gps-trackers"])


def _owned_bike(db: Session, bike_id: int, user_id: int) -> models.Bike:
    bike = db.query(models.Bike).filter(models.Bike.id == bike_id).first()
    if not bike:
        raise HTTPException(status_code=404, detail="Bike not found")
    if bike.owner_id != user_id:
        raise HTTPException(status_code=403, detail="Not your bike")
    return bike


@router.post("/{bike_id}/tracker/pair", response_model=schemas.TrackerOut, status_code=status.HTTP_201_CREATED)
def pair_tracker(
    bike_id: int,
    body: schemas.TrackerPairRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Register a tracker for provider validation.

    Activation codes are deliberately not persisted. A provider adapter will
    exchange them for encrypted credentials in the secrets layer.
    """
    bike = _owned_bike(db, bike_id, current_user.id)
    if bike.gps_device:
        raise HTTPException(status_code=409, detail="Bike already has a tracker")
    tracker = models.GPSDevice(
        bike_id=bike.id,
        provider=body.provider.strip().lower(),
        provider_device_id=body.provider_device_id.strip(),
        connection_type=body.connection_type,
    )
    db.add(tracker)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Tracker is already paired")
    db.refresh(tracker)
    return tracker


@router.get("/{bike_id}/tracker", response_model=schemas.TrackerOut)
def get_tracker(
    bike_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bike = _owned_bike(db, bike_id, current_user.id)
    if not bike.gps_device:
        raise HTTPException(status_code=404, detail="Tracker not connected")
    return bike.gps_device


@router.delete("/{bike_id}/tracker", status_code=status.HTTP_204_NO_CONTENT)
def remove_tracker(
    bike_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bike = _owned_bike(db, bike_id, current_user.id)
    if not bike.gps_device:
        raise HTTPException(status_code=404, detail="Tracker not connected")
    db.delete(bike.gps_device)
    db.commit()
