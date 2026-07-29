from datetime import datetime, date
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ---------------------------------------------------------------------------
# User
# ---------------------------------------------------------------------------

class UserOut(BaseModel):
    id: int
    name: str
    email: str
    id_document_url: Optional[str] = None
    selfie_url: Optional[str] = None
    verified: bool
    role: str
    rating: float
    points_balance: int
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=120)
    email: Optional[EmailStr] = None


# ---------------------------------------------------------------------------
# Gamification
# ---------------------------------------------------------------------------

class GamificationOut(BaseModel):
    xp: int
    level: int
    total_km: float
    co2_saved_kg: float
    streak_days: int
    last_activity_date: Optional[date] = None
    total_deliveries: int
    total_rentals: int

    model_config = {"from_attributes": True}


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: int
    name: str
    xp: int
    level: int
    total_deliveries: int


# ---------------------------------------------------------------------------
# Bike
# ---------------------------------------------------------------------------

class BikeCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    type: str = "city"
    brand: Optional[str] = None
    frame_size: Optional[str] = None
    hourly_price: float = Field(0.0, ge=0)
    daily_price: float = Field(0.0, ge=0)
    deposit: float = Field(0.0, ge=0)
    current_lat: float = Field(..., ge=-90, le=90)
    current_lon: float = Field(..., ge=-180, le=180)
    lock_type: str = Field("manual", pattern="^(manual|smart)$")
    lock_instructions: Optional[str] = Field(None, max_length=1000)
    smart_lock_provider: Optional[str] = Field(None, max_length=80)
    smart_lock_device_id: Optional[str] = Field(None, max_length=200)


class BikeUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    brand: Optional[str] = None
    frame_size: Optional[str] = None
    hourly_price: Optional[float] = Field(None, ge=0)
    daily_price: Optional[float] = Field(None, ge=0)
    deposit: Optional[float] = Field(None, ge=0)
    current_lat: Optional[float] = Field(None, ge=-90, le=90)
    current_lon: Optional[float] = Field(None, ge=-180, le=180)
    status: Optional[str] = None
    lock_type: Optional[str] = Field(None, pattern="^(manual|smart)$")
    lock_instructions: Optional[str] = Field(None, max_length=1000)
    smart_lock_provider: Optional[str] = Field(None, max_length=80)
    smart_lock_device_id: Optional[str] = Field(None, max_length=200)


class BikeOut(BaseModel):
    id: int
    owner_id: int
    title: str
    description: Optional[str] = None
    photo_urls: List[str] = []
    type: str
    brand: Optional[str] = None
    frame_size: Optional[str] = None
    hourly_price: float
    daily_price: float
    deposit: float
    current_lat: float
    current_lon: float
    status: str
    lock_type: str
    smart_lock_status: str
    avg_rating: float = 0.0
    review_count: int = 0
    distance_from_user: Optional[float] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class BikeSearchRequest(BaseModel):
    user_lat: float = Field(..., ge=-90, le=90)
    user_lon: float = Field(..., ge=-180, le=180)
    radius_km: float = Field(10.0, ge=0.1, le=200)
    type: Optional[str] = None
    max_hourly_price: Optional[float] = None
    max_daily_price: Optional[float] = None


class BikeIdentityOut(BaseModel):
    bike_id: int
    identity_qr: str
    qr_version: int


class RentalLockOut(BaseModel):
    lock_type: str
    instructions: Optional[str] = None
    provider: Optional[str] = None
    status: str


class PaymentIntentCreate(BaseModel):
    bike_id: int


class PaymentIntentOut(BaseModel):
    provider: str
    payment_intent_id: str
    client_secret: Optional[str] = None
    authorized_amount: float
    currency: str = "eur"


class ParkingZoneOut(BaseModel):
    id: str
    name: str
    lat: float
    lon: float
    radius_m: int


class TrackerPairRequest(BaseModel):
    provider: str = Field(..., min_length=1, max_length=80)
    provider_device_id: str = Field(..., min_length=3, max_length=200)
    connection_type: str = Field("rest", pattern="^(rest|webhook|mqtt|tcp|polling|gateway)$")
    activation_code: Optional[str] = Field(None, min_length=3, max_length=200)


class TrackerOut(BaseModel):
    id: int
    bike_id: int
    provider: str
    provider_device_id: str
    connection_type: str
    status: str
    installation_status: str
    battery_level: Optional[float] = None
    signal_strength: Optional[float] = None
    firmware_version: Optional[str] = None
    last_seen_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Rental
# ---------------------------------------------------------------------------

class RentalCreate(BaseModel):
    bike_id: int
    pickup_lat: float = Field(..., ge=-90, le=90)
    pickup_lon: float = Field(..., ge=-180, le=180)
    payment_intent_id: str = Field(..., min_length=5, max_length=200)


class RentalEnd(BaseModel):
    return_lat: float = Field(..., ge=-90, le=90)
    return_lon: float = Field(..., ge=-180, le=180)
    lock_confirmed: bool


class RentalStart(BaseModel):
    bike_qr: str = Field(..., min_length=10, max_length=100)


class RentalOut(BaseModel):
    id: int
    bike_id: int
    renter_id: int
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    pickup_lat: Optional[float] = None
    pickup_lon: Optional[float] = None
    return_lat: Optional[float] = None
    return_lon: Optional[float] = None
    total_price: float
    status: str
    created_at: datetime
    return_photo_url: Optional[str] = None
    lock_confirmed: bool = False
    payment_provider: str = "demo"
    payment_status: str = "not_started"
    authorized_amount: float = 0.0

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Review
# ---------------------------------------------------------------------------

class ReviewCreate(BaseModel):
    bike_id: int
    rental_id: Optional[int] = None
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None


class ReviewOut(BaseModel):
    id: int
    bike_id: int
    reviewer_id: int
    rating: int
    comment: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Delivery
# ---------------------------------------------------------------------------

class DeliveryJobCreate(BaseModel):
    bike_id: int
    dropoff_lat: float = Field(..., ge=-90, le=90)
    dropoff_lon: float = Field(..., ge=-180, le=180)
    reward_points: int = Field(..., ge=1)


class DeliveryJobOut(BaseModel):
    id: int
    bike_id: int
    posted_by_id: int
    pickup_lat: float
    pickup_lon: float
    dropoff_lat: float
    dropoff_lon: float
    distance_km: float
    reward_points: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class AcceptSegmentRequest(BaseModel):
    start_lat: float = Field(..., ge=-90, le=90)
    start_lon: float = Field(..., ge=-180, le=180)


class CompleteSegmentRequest(BaseModel):
    end_lat: float = Field(..., ge=-90, le=90)
    end_lon: float = Field(..., ge=-180, le=180)
    relay: bool = False  # True = hand off to next courier


class SegmentOut(BaseModel):
    id: int
    job_id: int
    user_id: int
    start_lat: float
    start_lon: float
    end_lat: Optional[float] = None
    end_lon: Optional[float] = None
    distance_km: float
    earned_points: int
    status: str
    started_at: datetime
    ended_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class DeliverySearchRequest(BaseModel):
    user_lat: float = Field(..., ge=-90, le=90)
    user_lon: float = Field(..., ge=-180, le=180)
    radius_km: float = Field(20.0, ge=0.1, le=200)


class DirectionalDeliverySearchRequest(BaseModel):
    origin_lat: float = Field(..., ge=-90, le=90)
    origin_lon: float = Field(..., ge=-180, le=180)
    destination_lat: float = Field(..., ge=-90, le=90)
    destination_lon: float = Field(..., ge=-180, le=180)
    max_detour_km: float = Field(5.0, ge=0.1, le=100)
    limit: int = Field(20, ge=1, le=100)


class DirectionalDeliveryMatchOut(BaseModel):
    job: DeliveryJobOut
    completion_type: str
    pickup_distance_km: float
    added_distance_km: float
    route_progress: float
    suggested_dropoff_lat: float
    suggested_dropoff_lon: float
    estimated_reward_points: int


# ---------------------------------------------------------------------------
# Points
# ---------------------------------------------------------------------------

class PointTransactionOut(BaseModel):
    id: int
    type: str
    amount: int
    description: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

class PartnerOfferCreate(BaseModel):
    partner_name: str = Field(..., min_length=1, max_length=200)
    title: str = Field(..., min_length=1, max_length=300)
    description: str
    points_cost: int = Field(..., ge=1)
    discount_code: str = Field(..., min_length=1, max_length=100)
    quantity: Optional[int] = Field(None, ge=1)


class PartnerOfferUpdate(BaseModel):
    partner_name: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    points_cost: Optional[int] = Field(None, ge=1)
    quantity: Optional[int] = None
    active: Optional[bool] = None


class PartnerOfferOut(BaseModel):
    id: int
    partner_name: str
    title: str
    description: str
    points_cost: int
    quantity: Optional[int] = None
    active: bool
    discount_code: Optional[str] = None  # only revealed on redemption / admin

    model_config = {"from_attributes": True}


class RedemptionOut(BaseModel):
    id: int
    offer_id: int
    partner_name: str
    title: str
    discount_code: str
    points_spent: int
    redeemed_at: datetime

    model_config = {"from_attributes": True}
