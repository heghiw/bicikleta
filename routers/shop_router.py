from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user, require_admin
import models
import schemas

router = APIRouter(prefix="/api/shop", tags=["shop"])


@router.get("/offers", response_model=List[schemas.PartnerOfferOut])
def list_offers(
    _: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    offers = db.query(models.PartnerOffer).filter(models.PartnerOffer.active == True).all()  # noqa: E712
    return [
        schemas.PartnerOfferOut(
            id=o.id, partner_name=o.partner_name, title=o.title,
            description=o.description, points_cost=o.points_cost,
            quantity=o.quantity, active=o.active, discount_code=None,
        )
        for o in offers
    ]


@router.post("/offers/{offer_id}/redeem", response_model=schemas.RedemptionOut)
def redeem_offer(
    offer_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    offer = db.query(models.PartnerOffer).filter(
        models.PartnerOffer.id == offer_id,
        models.PartnerOffer.active == True,  # noqa: E712
    ).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found or inactive")

    if offer.quantity is not None and offer.quantity <= 0:
        raise HTTPException(status_code=410, detail="Offer is sold out")

    balance = current_user.points_balance
    if balance < offer.points_cost:
        raise HTTPException(
            status_code=402,
            detail=f"Insufficient points. Need {offer.points_cost}, have {balance}.",
        )

    tx = models.PointTransaction(
        user_id=current_user.id,
        type=models.PointType.spent,
        amount=-offer.points_cost,
        description=f"Redeemed: {offer.partner_name} — {offer.title}",
    )
    redemption = models.Redemption(
        user_id=current_user.id,
        offer_id=offer.id,
        points_spent=offer.points_cost,
    )
    db.add(tx)
    db.add(redemption)
    if offer.quantity is not None:
        offer.quantity -= 1
    db.commit()
    db.refresh(redemption)

    return schemas.RedemptionOut(
        id=redemption.id,
        offer_id=offer.id,
        partner_name=offer.partner_name,
        title=offer.title,
        discount_code=offer.discount_code,
        points_spent=offer.points_cost,
        redeemed_at=redemption.redeemed_at,
    )


# Admin
@router.post("/offers", response_model=schemas.PartnerOfferOut, status_code=201)
def create_offer(
    body: schemas.PartnerOfferCreate,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    offer = models.PartnerOffer(**body.model_dump())
    db.add(offer)
    db.commit()
    db.refresh(offer)
    return schemas.PartnerOfferOut(
        id=offer.id, partner_name=offer.partner_name, title=offer.title,
        description=offer.description, points_cost=offer.points_cost,
        quantity=offer.quantity, active=offer.active,
        discount_code=offer.discount_code,
    )


@router.patch("/offers/{offer_id}", response_model=schemas.PartnerOfferOut)
def update_offer(
    offer_id: int,
    body: schemas.PartnerOfferUpdate,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    offer = db.query(models.PartnerOffer).filter(models.PartnerOffer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    for field, val in body.model_dump(exclude_none=True).items():
        setattr(offer, field, val)
    db.commit()
    db.refresh(offer)
    return schemas.PartnerOfferOut(
        id=offer.id, partner_name=offer.partner_name, title=offer.title,
        description=offer.description, points_cost=offer.points_cost,
        quantity=offer.quantity, active=offer.active,
        discount_code=offer.discount_code,
    )


@router.delete("/offers/{offer_id}", status_code=204)
def delete_offer(
    offer_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    offer = db.query(models.PartnerOffer).filter(models.PartnerOffer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    db.delete(offer)
    db.commit()
