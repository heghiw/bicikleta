from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user, require_admin
import models
import schemas
from models import _haversine

router = APIRouter(prefix="/bikes", tags=["bikes"])


@router.post("/", response_model=schemas.BikeOut, status_code=status.HTTP_201_CREATED)
def create_bike(
    body: schemas.BikeCreate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_admin),
):
    """Admin-only: add a new bike to the system."""
    bike = models.Bike(**body.model_dump())
    db.add(bike)
    db.commit()
    db.refresh(bike)
    return _bike_out(bike)


@router.get("/", response_model=List[schemas.BikeOut])
def list_bikes(
    status: Optional[str] = Query(None, description="Filter by status"),
    db: Session = Depends(get_db),
    _user: models.User = Depends(get_current_user),
):
    """List bikes, optionally filtered by status."""
    q = db.query(models.Bike)
    if status:
        q = q.filter(models.Bike.status == status)
    return [_bike_out(b) for b in q.all()]


@router.get("/{bike_id}", response_model=schemas.BikeOut)
def get_bike(
    bike_id: int,
    db: Session = Depends(get_db),
    _user: models.User = Depends(get_current_user),
):
    bike = _get_or_404(db, bike_id)
    return _bike_out(bike)


@router.patch("/{bike_id}/status", response_model=schemas.BikeOut)
def update_bike_status(
    bike_id: int,
    new_status: models.BikeStatus,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_admin),
):
    """Admin-only: manually update a bike's status."""
    bike = _get_or_404(db, bike_id)
    bike.status = new_status
    db.commit()
    db.refresh(bike)
    return _bike_out(bike)


@router.post("/search", response_model=List[schemas.BikeSearchResult])
def search_bikes(
    body: schemas.RouteSearchRequest,
    db: Session = Depends(get_db),
    _user: models.User = Depends(get_current_user),
):
    """Search for available bikes.

    Two modes:
    - **Delivery mode** (radius_km provided): return available bikes within *radius_km*
      of the user, ranked by reward points.
    - **Pick-up mode** (dest_lat/dest_lon provided): return bikes whose route
      overlaps the user's intended journey.  A bike qualifies if picking it up
      from its current position and dropping it at the destination (or the
      bike's target, whichever is closer) is within the user's direction of
      travel.  Partial transport is flagged when the bike target is further
      than the user destination.
    """
    available = (
        db.query(models.Bike)
        .filter(models.Bike.status == models.BikeStatus.available)
        .all()
    )

    results: List[schemas.BikeSearchResult] = []

    for bike in available:
        dist_to_user = bike.distance_to(body.user_lat, body.user_lon)

        if body.radius_km is not None:
            # Delivery mode
            if dist_to_user <= body.radius_km:
                out = _bike_out(bike, distance_from_user=dist_to_user)
                results.append(schemas.BikeSearchResult(**out.model_dump()))
        elif body.dest_lat is not None and body.dest_lon is not None:
            # Pick-up mode: does picking up this bike help the user reach their destination?
            user_to_dest = _haversine(body.user_lat, body.user_lon, body.dest_lat, body.dest_lon)
            user_to_bike = dist_to_user
            bike_to_dest = _haversine(bike.current_lat, bike.current_lon, body.dest_lat, body.dest_lon)
            bike_target_to_dest = _haversine(bike.target_lat, bike.target_lon, body.dest_lat, body.dest_lon)

            # Bike is "on the way" if picking it up doesn't add more than 20 % detour
            detour = user_to_bike + bike_to_dest
            if detour <= user_to_dest * 1.20:
                partial = bike_target_to_dest > 0.5  # bike target is not yet at user's dest
                overlap = min(
                    _haversine(bike.current_lat, bike.current_lon, bike.target_lat, bike.target_lon),
                    _haversine(bike.current_lat, bike.current_lon, body.dest_lat, body.dest_lon),
                )
                out = _bike_out(bike, distance_from_user=user_to_bike)
                results.append(
                    schemas.BikeSearchResult(
                        **out.model_dump(),
                        overlap_km=overlap,
                        partial_possible=partial,
                    )
                )

    # Sort by points reward (points_per_km × route km) descending
    results.sort(key=lambda r: r.points_per_km * r.total_route_km, reverse=True)
    return results


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_or_404(db: Session, bike_id: int) -> models.Bike:
    bike = db.query(models.Bike).filter(models.Bike.id == bike_id).first()
    if not bike:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bike not found")
    return bike


def _bike_out(bike: models.Bike, distance_from_user: Optional[float] = None) -> schemas.BikeOut:
    return schemas.BikeOut(
        id=bike.id,
        name=bike.name,
        current_lat=bike.current_lat,
        current_lon=bike.current_lon,
        target_lat=bike.target_lat,
        target_lon=bike.target_lon,
        status=bike.status,
        points_per_km=bike.points_per_km,
        total_route_km=bike.total_route_km(),
        distance_from_user=distance_from_user,
    )
