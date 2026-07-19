from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user, require_admin
import models
import schemas

router = APIRouter(prefix="/api/users", tags=["users"])


def _user_out(user: models.User) -> schemas.UserOut:
    return schemas.UserOut(
        id=user.id,
        name=user.name,
        email=user.email,
        id_document_url=user.id_document_url,
        selfie_url=user.selfie_url,
        verified=user.verified,
        role=user.role,
        rating=user.rating,
        points_balance=user.points_balance,
        created_at=user.created_at,
    )


@router.get("/me", response_model=schemas.UserOut)
def get_profile(current_user: models.User = Depends(get_current_user)):
    return _user_out(current_user)


@router.patch("/me", response_model=schemas.UserOut)
def update_profile(
    body: schemas.UserUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if body.email and body.email != current_user.email:
        if db.query(models.User).filter(models.User.email == body.email).first():
            raise HTTPException(status_code=409, detail="Email already in use")
        current_user.email = body.email
    if body.name:
        current_user.name = body.name
    db.commit()
    db.refresh(current_user)
    return _user_out(current_user)


@router.get("/me/points", response_model=List[schemas.PointTransactionOut])
def get_point_ledger(current_user: models.User = Depends(get_current_user)):
    return current_user.point_transactions


@router.get("/me/rentals", response_model=List[schemas.RentalOut])
def get_my_rentals(current_user: models.User = Depends(get_current_user)):
    return current_user.rentals


@router.get("/me/deliveries", response_model=List[schemas.SegmentOut])
def get_my_deliveries(current_user: models.User = Depends(get_current_user)):
    return current_user.delivery_segments


@router.get("/me/gamification", response_model=schemas.GamificationOut)
def get_gamification(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    g = current_user.gamification
    if not g:
        g = models.UserGamification(user_id=current_user.id)
        db.add(g)
        db.commit()
        db.refresh(g)
    return g


@router.get("/me/redemptions", response_model=List[schemas.RedemptionOut])
def get_redemptions(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(models.Redemption, models.PartnerOffer)
        .join(models.PartnerOffer)
        .filter(models.Redemption.user_id == current_user.id)
        .all()
    )
    return [
        schemas.RedemptionOut(
            id=r.id,
            offer_id=o.id,
            partner_name=o.partner_name,
            title=o.title,
            discount_code=o.discount_code,
            points_spent=r.points_spent,
            redeemed_at=r.redeemed_at,
        )
        for r, o in rows
    ]


# Admin: list pending verification
@router.get("/pending-verification", response_model=List[schemas.UserOut])
def list_pending(
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    return [_user_out(u) for u in db.query(models.User).filter(models.User.verified == False).all()]  # noqa: E712


# Admin: verify user
@router.post("/{user_id}/verify", response_model=schemas.UserOut)
def verify_user(
    user_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.verified = True
    db.commit()
    db.refresh(user)
    return _user_out(user)
