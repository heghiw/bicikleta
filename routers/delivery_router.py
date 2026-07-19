from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user
import models
import schemas
from models import _haversine

router = APIRouter(prefix="/api/delivery", tags=["delivery"])


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
