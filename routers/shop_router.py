from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user, require_admin
import models
import schemas

router = APIRouter(prefix="/shop", tags=["shop"])


# ---------------------------------------------------------------------------
# Public / user endpoints
# ---------------------------------------------------------------------------

@router.get("/offers", response_model=List[schemas.PartnerOfferOut])
def list_offers(
    db: Session = Depends(get_db),
    _user: models.User = Depends(get_current_user),
):
    """List all active partner offers (discount code hidden until redeemed)."""
    offers = db.query(models.PartnerOffer).filter(models.PartnerOffer.active == True).all()  # noqa: E712
    return [
        schemas.PartnerOfferOut(
            id=o.id,
            partner_name=o.partner_name,
            description=o.description,
            points_cost=o.points_cost,
            active=o.active,
            discount_code=None,  # hidden
        )
        for o in offers
    ]


@router.post("/offers/{offer_id}/redeem", response_model=schemas.RedemptionOut)
def redeem_offer(
    offer_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Spend points to redeem a partner discount.  Returns the discount code."""
    offer = db.query(models.PartnerOffer).filter(
        models.PartnerOffer.id == offer_id,
        models.PartnerOffer.active == True,  # noqa: E712
    ).first()
    if not offer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found or inactive")

    if current_user.points_balance < offer.points_cost:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Insufficient points. Need {offer.points_cost}, have {current_user.points_balance}.",
        )

    current_user.points_balance -= offer.points_cost
    tx = models.PointTransaction(
        user_id=current_user.id,
        delta=-offer.points_cost,
        reason=f"Redemption: {offer.partner_name} offer #{offer.id}",
    )
    redemption = models.Redemption(user_id=current_user.id, offer_id=offer.id)
    db.add(tx)
    db.add(redemption)
    db.commit()
    db.refresh(redemption)

    return schemas.RedemptionOut(
        id=redemption.id,
        offer_id=offer.id,
        partner_name=offer.partner_name,
        discount_code=offer.discount_code,
        redeemed_at=redemption.redeemed_at,
    )


# ---------------------------------------------------------------------------
# Admin endpoints
# ---------------------------------------------------------------------------

@router.post("/offers", response_model=schemas.PartnerOfferOut, status_code=status.HTTP_201_CREATED)
def create_offer(
    body: schemas.PartnerOfferCreate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_admin),
):
    """Admin-only: create a new partner offer."""
    offer = models.PartnerOffer(**body.model_dump())
    db.add(offer)
    db.commit()
    db.refresh(offer)
    return schemas.PartnerOfferOut(
        id=offer.id,
        partner_name=offer.partner_name,
        description=offer.description,
        points_cost=offer.points_cost,
        active=offer.active,
        discount_code=offer.discount_code,  # visible to admin
    )


@router.patch("/offers/{offer_id}", response_model=schemas.PartnerOfferOut)
def update_offer(
    offer_id: int,
    body: schemas.PartnerOfferUpdate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_admin),
):
    """Admin-only: update an existing partner offer."""
    offer = db.query(models.PartnerOffer).filter(models.PartnerOffer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found")
    for field, val in body.model_dump(exclude_none=True).items():
        setattr(offer, field, val)
    db.commit()
    db.refresh(offer)
    return schemas.PartnerOfferOut(
        id=offer.id,
        partner_name=offer.partner_name,
        description=offer.description,
        points_cost=offer.points_cost,
        active=offer.active,
        discount_code=offer.discount_code,
    )


@router.delete("/offers/{offer_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_offer(
    offer_id: int,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_admin),
):
    """Admin-only: permanently delete a partner offer."""
    offer = db.query(models.PartnerOffer).filter(models.PartnerOffer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found")
    db.delete(offer)
    db.commit()
