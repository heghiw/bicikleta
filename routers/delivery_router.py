from datetime import datetime
from typing import List
import math
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user
import models
import schemas
from models import _haversine

router = APIRouter(prefix="/delivery", tags=["delivery"])


# ---------------------------------------------------------------------------
# Jobs
# ---------------------------------------------------------------------------

@router.post("/jobs", response_model=schemas.DeliveryJobOut, status_code=201)
def post_job(
    body: schemas.DeliveryJobCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Post a delivery job for one of your bikes (or any bike as admin)."""
    bike = db.query(models.Bike).filter(models.Bike.id == body.bike_id).first()
    if not bike:
        raise HTTPException(status_code=404, detail="Bike not found")
    if bike.owner_id != current_user.id and current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your bike")
    if bike.status not in (models.BikeStatus.available, models.BikeStatus.maintenance):
        raise HTTPException(status_code=409, detail=f"Bike is {bike.status}, cannot post job")

    dist = _haversine(bike.current_lat, bike.current_lon, body.dropoff_lat, body.dropoff_lon)
    job = models.DeliveryJob(
        bike_id=bike.id,
        posted_by_id=current_user.id,
        pickup_lat=bike.current_lat,
        pickup_lon=bike.current_lon,
        dropoff_lat=body.dropoff_lat,
        dropoff_lon=body.dropoff_lon,
        distance_km=round(dist, 2),
        reward_points=body.reward_points,
    )
    bike.status = models.BikeStatus.in_delivery
    db.add(job)
    db.commit()
    db.refresh(job)
    return job


@router.get("/jobs", response_model=List[schemas.DeliveryJobOut])
def list_open_jobs(
    _: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(models.DeliveryJob).filter(
        models.DeliveryJob.status == models.DeliveryJobStatus.open
    ).all()


@router.post("/jobs/search", response_model=List[schemas.DeliveryJobOut])
def search_jobs(
    body: schemas.DeliverySearchRequest,
    _: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Find open delivery jobs whose pickup point is within radius_km of the user."""
    jobs = db.query(models.DeliveryJob).filter(
        models.DeliveryJob.status == models.DeliveryJobStatus.open
    ).all()
    results = []
    for job in jobs:
        dist = _haversine(job.pickup_lat, job.pickup_lon, body.user_lat, body.user_lon)
        if dist <= body.radius_km:
            results.append(job)
    results.sort(key=lambda j: j.reward_points, reverse=True)
    return results


@router.post("/jobs/directional-search", response_model=List[schemas.DirectionalDeliveryMatchOut])
def directional_search_jobs(
    body: schemas.DirectionalDeliverySearchRequest,
    _: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Find open bike moves aligned with a user's planned journey."""
    route_km = _haversine(body.origin_lat, body.origin_lon,
                          body.destination_lat, body.destination_lon)
    if route_km < 0.1:
        raise HTTPException(status_code=400, detail="Origin and destination are too close")

    matches = []
    jobs = db.query(models.DeliveryJob).filter(
        models.DeliveryJob.status == models.DeliveryJobStatus.open
    ).all()
    for job in jobs:
        pickup_progress, pickup_corridor_km = _route_projection(
            body.origin_lat, body.origin_lon, body.destination_lat,
            body.destination_lon, job.pickup_lat, job.pickup_lon)
        drop_progress, drop_corridor_km = _route_projection(
            body.origin_lat, body.origin_lon, body.destination_lat,
            body.destination_lon, job.dropoff_lat, job.dropoff_lon)
        if pickup_corridor_km > body.max_detour_km or drop_progress <= pickup_progress:
            continue

        pickup_distance = _haversine(body.origin_lat, body.origin_lon,
                                     job.pickup_lat, job.pickup_lon)
        if drop_progress <= 1.0 and drop_corridor_km <= body.max_detour_km:
            completion_type = "full"
            suggested_lat, suggested_lon = job.dropoff_lat, job.dropoff_lon
            carried_km = job.distance_km
            journey_km = pickup_distance + job.distance_km + _haversine(
                job.dropoff_lat, job.dropoff_lon,
                body.destination_lat, body.destination_lon)
        else:
            completion_type = "partial"
            suggested_lat, suggested_lon = body.destination_lat, body.destination_lon
            carried_km = _haversine(job.pickup_lat, job.pickup_lon,
                                    suggested_lat, suggested_lon)
            journey_km = pickup_distance + carried_km

        added_km = max(0.0, journey_km - route_km)
        if added_km > body.max_detour_km:
            continue
        share = min(1.0, carried_km / job.distance_km) if job.distance_km else 1.0
        matches.append({
            "job": job,
            "completion_type": completion_type,
            "pickup_distance_km": round(pickup_distance, 2),
            "added_distance_km": round(added_km, 2),
            "route_progress": round(max(0.0, min(1.0, pickup_progress)), 3),
            "suggested_dropoff_lat": suggested_lat,
            "suggested_dropoff_lon": suggested_lon,
            "estimated_reward_points": max(1, int(job.reward_points * share)),
        })
    matches.sort(key=lambda item: (item["added_distance_km"],
                                   -item["estimated_reward_points"]))
    return matches[:body.limit]


@router.get("/jobs/{job_id}", response_model=schemas.DeliveryJobOut)
def get_job(
    job_id: int,
    _: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _get_job_or_404(db, job_id)


# ---------------------------------------------------------------------------
# Segments (relay)
# ---------------------------------------------------------------------------

@router.post("/jobs/{job_id}/accept", response_model=schemas.SegmentOut, status_code=201)
def accept_segment(
    job_id: int,
    body: schemas.AcceptSegmentRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Accept a delivery job (or relay leg).
    
    A job must be *open* (no active segment).  The user must be within 0.5 km
    of the pickup point.
    """
    if not current_user.verified:
        raise HTTPException(status_code=403, detail="Account not yet verified")

    job = _get_job_or_404(db, job_id)
    if job.status not in (models.DeliveryJobStatus.open,):
        raise HTTPException(status_code=409, detail=f"Job is {job.status}")

    # Ensure no active segment already running
    active_seg = db.query(models.DeliverySegment).filter(
        models.DeliverySegment.job_id == job_id,
        models.DeliverySegment.status == models.SegmentStatus.active,
    ).first()
    if active_seg:
        raise HTTPException(status_code=409, detail="Job already has an active courier")

    # Check proximity to pickup
    dist = _haversine(job.pickup_lat, job.pickup_lon, body.start_lat, body.start_lon)
    if dist > 0.5:
        raise HTTPException(
            status_code=400,
            detail=f"You are {dist:.2f} km from the pickup point. Must be within 0.5 km.",
        )

    seg = models.DeliverySegment(
        job_id=job.id,
        user_id=current_user.id,
        start_lat=body.start_lat,
        start_lon=body.start_lon,
    )
    job.status = models.DeliveryJobStatus.in_progress
    db.add(seg)
    db.commit()
    db.refresh(seg)
    return seg


@router.post("/segments/{segment_id}/complete", response_model=schemas.SegmentOut)
def complete_segment(
    segment_id: int,
    body: schemas.CompleteSegmentRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Complete a delivery segment.
    
    - `relay=False` (default): full delivery — bike reaches destination.
    - `relay=True`: partial drop; job returns to *open* for next courier.
    Points awarded proportional to km covered.
    """
    seg = _get_segment(db, segment_id, current_user.id)
    job = seg.job
    bike = job.bike

    km = _haversine(seg.start_lat, seg.start_lon, body.end_lat, body.end_lon)
    # Points proportional to share of total job distance
    share = min(1.0, km / job.distance_km) if job.distance_km > 0 else 1.0
    points = max(1, int(job.reward_points * share))

    seg.end_lat = body.end_lat
    seg.end_lon = body.end_lon
    seg.distance_km = round(km, 3)
    seg.earned_points = points
    seg.status = models.SegmentStatus.completed
    seg.ended_at = datetime.utcnow()

    # Update bike position
    bike.current_lat = body.end_lat
    bike.current_lon = body.end_lon

    if body.relay:
        # Partial drop: update job pickup to current position, reopen
        job.pickup_lat = body.end_lat
        job.pickup_lon = body.end_lon
        remaining = _haversine(body.end_lat, body.end_lon, job.dropoff_lat, job.dropoff_lon)
        job.distance_km = round(remaining, 2)
        job.reward_points = max(1, int(job.reward_points * (1 - share)))
        job.status = models.DeliveryJobStatus.open
        bike.status = models.BikeStatus.in_delivery
    else:
        job.status = models.DeliveryJobStatus.completed
        bike.status = models.BikeStatus.available

    # Award points
    tx = models.PointTransaction(
        user_id=current_user.id,
        type=models.PointType.earned,
        amount=points,
        description=f"Delivery job #{job.id} — {km:.2f} km",
    )
    db.add(tx)

    # Gamification
    g = current_user.gamification
    if g:
        g.add_activity(km=km, deliveries=1)

    db.commit()
    db.refresh(seg)
    return seg


@router.get("/segments", response_model=List[schemas.SegmentOut])
def list_my_segments(current_user: models.User = Depends(get_current_user)):
    return current_user.delivery_segments


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _route_projection(origin_lat, origin_lon, destination_lat, destination_lon,
                      point_lat, point_lon) -> tuple[float, float]:
    mean_lat = math.radians((origin_lat + destination_lat) / 2)
    scale_x, scale_y = 111.32 * math.cos(mean_lat), 110.57
    route_x = (destination_lon - origin_lon) * scale_x
    route_y = (destination_lat - origin_lat) * scale_y
    point_x = (point_lon - origin_lon) * scale_x
    point_y = (point_lat - origin_lat) * scale_y
    length_sq = route_x * route_x + route_y * route_y
    if length_sq == 0:
        return 0.0, math.hypot(point_x, point_y)
    progress = (point_x * route_x + point_y * route_y) / length_sq
    clamped = max(0.0, min(1.0, progress))
    corridor = math.hypot(point_x - clamped * route_x,
                          point_y - clamped * route_y)
    return progress, corridor


def _get_job_or_404(db: Session, job_id: int) -> models.DeliveryJob:
    job = db.query(models.DeliveryJob).filter(models.DeliveryJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Delivery job not found")
    return job


def _get_segment(db: Session, seg_id: int, user_id: int) -> models.DeliverySegment:
    seg = db.query(models.DeliverySegment).filter(
        models.DeliverySegment.id == seg_id,
        models.DeliverySegment.user_id == user_id,
        models.DeliverySegment.status == models.SegmentStatus.active,
    ).first()
    if not seg:
        raise HTTPException(status_code=404, detail="Active segment not found")
    return seg
