from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(..., min_length=8)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


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
    id_photo_url: Optional[str]
    face_photo_url: Optional[str]
    verified: bool
    role: str
    points_balance: int
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=120)
    email: Optional[EmailStr] = None


# ---------------------------------------------------------------------------
# Bike
# ---------------------------------------------------------------------------

class BikeCreate(BaseModel):
    name: Optional[str] = None
    current_lat: float = Field(..., ge=-90, le=90)
    current_lon: float = Field(..., ge=-180, le=180)
    target_lat: float = Field(..., ge=-90, le=90)
    target_lon: float = Field(..., ge=-180, le=180)
    points_per_km: float = Field(1.0, ge=0)


class BikeOut(BaseModel):
    id: int
    name: Optional[str]
    current_lat: float
    current_lon: float
    target_lat: float
    target_lon: float
    status: str
    points_per_km: float
    total_route_km: float
    distance_from_user: Optional[float] = None

    model_config = {"from_attributes": True}


class BikeSearchResult(BikeOut):
    overlap_km: Optional[float] = None
    partial_possible: bool = False


# ---------------------------------------------------------------------------
# Trip
# ---------------------------------------------------------------------------

class StartTripRequest(BaseModel):
    bike_id: int
    start_lat: float = Field(..., ge=-90, le=90)
    start_lon: float = Field(..., ge=-180, le=180)


class CompleteTripRequest(BaseModel):
    end_lat: float = Field(..., ge=-90, le=90)
    end_lon: float = Field(..., ge=-180, le=180)
    partial: bool = False


class TripOut(BaseModel):
    id: int
    bike_id: int
    start_lat: float
    start_lon: float
    end_lat: Optional[float]
    end_lon: Optional[float]
    km: float
    points_earned: int
    status: str
    started_at: datetime
    ended_at: Optional[datetime]

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Location
# ---------------------------------------------------------------------------

class LocationPayload(BaseModel):
    trip_id: int
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)


# ---------------------------------------------------------------------------
# Points
# ---------------------------------------------------------------------------

class PointTransactionOut(BaseModel):
    id: int
    delta: int
    reason: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

class PartnerOfferCreate(BaseModel):
    partner_name: str = Field(..., min_length=1, max_length=200)
    description: str
    points_cost: int = Field(..., ge=1)
    discount_code: str = Field(..., min_length=1, max_length=100)


class PartnerOfferUpdate(BaseModel):
    partner_name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    points_cost: Optional[int] = Field(None, ge=1)
    active: Optional[bool] = None


class PartnerOfferOut(BaseModel):
    id: int
    partner_name: str
    description: str
    points_cost: int
    active: bool
    # discount_code is omitted from public view; revealed only on redemption
    discount_code: Optional[str] = None

    model_config = {"from_attributes": True}


class RedemptionOut(BaseModel):
    id: int
    offer_id: int
    partner_name: str
    discount_code: str
    redeemed_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Route search
# ---------------------------------------------------------------------------

class RouteSearchRequest(BaseModel):
    user_lat: float = Field(..., ge=-90, le=90)
    user_lon: float = Field(..., ge=-180, le=180)
    dest_lat: Optional[float] = Field(None, ge=-90, le=90)
    dest_lon: Optional[float] = Field(None, ge=-180, le=180)
    radius_km: Optional[float] = Field(None, ge=0.1)
