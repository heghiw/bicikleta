from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user, require_admin
import models
import schemas

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=schemas.UserOut)
def get_profile(current_user: models.User = Depends(get_current_user)):
    """Return the authenticated user's profile."""
    return current_user


@router.patch("/me", response_model=schemas.UserOut)
def update_profile(
    body: schemas.UserUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update name and/or email."""
    if body.email and body.email != current_user.email:
        if db.query(models.User).filter(models.User.email == body.email).first():
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already in use")
        current_user.email = body.email
    if body.name:
        current_user.name = body.name
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/me/trips", response_model=List[schemas.TripOut])
def get_my_trips(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """History of all trips for the current user."""
    return current_user.trips


@router.get("/me/points", response_model=List[schemas.PointTransactionOut])
def get_point_history(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Full point transaction ledger for the current user."""
    return current_user.point_transactions


@router.get("/me/redemptions", response_model=List[schemas.RedemptionOut])
def get_redemptions(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """History of discount redemptions for the current user."""
    rows = (
        db.query(models.Redemption, models.PartnerOffer)
        .join(models.PartnerOffer, models.Redemption.offer_id == models.PartnerOffer.id)
        .filter(models.Redemption.user_id == current_user.id)
        .all()
    )
    result = []
    for redemption, offer in rows:
        result.append(
            schemas.RedemptionOut(
                id=redemption.id,
                offer_id=offer.id,
                partner_name=offer.partner_name,
                discount_code=offer.discount_code,
                redeemed_at=redemption.redeemed_at,
            )
        )
    return result


# Admin: verify a user after manual ID review
@router.post("/{user_id}/verify", response_model=schemas.UserOut)
def verify_user(
    user_id: int,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_admin),
):
    """Admin-only: mark a user as verified after reviewing their ID and face photo."""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.verified = True
    db.commit()
    db.refresh(user)
    return user


# Admin: list unverified users pending review
@router.get("/pending-verification", response_model=List[schemas.UserOut])
def list_pending_users(
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_admin),
):
    """Admin-only: list users awaiting ID verification."""
    return db.query(models.User).filter(models.User.verified == False).all()  # noqa: E712
