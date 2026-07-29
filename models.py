import math
import hashlib
import hmac
import json
import os
import enum
from datetime import date, datetime
from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, Date,
    ForeignKey, Enum, Text, UniqueConstraint,
)
from sqlalchemy.orm import relationship
from database import Base


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class UserRole(str, enum.Enum):
    user = "user"
    admin = "admin"


class BikeType(str, enum.Enum):
    city = "city"
    road = "road"
    mountain = "mountain"
    electric = "electric"
    cargo = "cargo"
    folding = "folding"


class BikeStatus(str, enum.Enum):
    available = "available"
    reserved = "reserved"
    in_delivery = "in_delivery"
    maintenance = "maintenance"
    offline = "offline"


class RentalStatus(str, enum.Enum):
    pending = "pending"
    active = "active"
    completed = "completed"
    cancelled = "cancelled"


class DeliveryJobStatus(str, enum.Enum):
    open = "open"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"


class SegmentStatus(str, enum.Enum):
    active = "active"
    completed = "completed"
    cancelled = "cancelled"


class PointType(str, enum.Enum):
    earned = "earned"
    spent = "spent"
    referral = "referral"
    bonus = "bonus"
    adjustment = "adjustment"


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    email = Column(String(200), unique=True, index=True, nullable=False)
    password_hash = Column(String(256), nullable=False)
    id_document_url = Column(String(512), nullable=True)
    selfie_url = Column(String(512), nullable=True)
    verified = Column(Boolean, default=False)
    role = Column(Enum(UserRole), default=UserRole.user)
    rating = Column(Float, default=5.0)
    created_at = Column(DateTime, default=datetime.utcnow)

    bikes = relationship("Bike", back_populates="owner", foreign_keys="Bike.owner_id")
    rentals = relationship("Rental", back_populates="renter", foreign_keys="Rental.renter_id")
    delivery_segments = relationship("DeliverySegment", back_populates="user")
    point_transactions = relationship(
        "PointTransaction", back_populates="user", cascade="all, delete-orphan"
    )
    reviews = relationship("Review", back_populates="reviewer", foreign_keys="Review.reviewer_id")
    redemptions = relationship("Redemption", back_populates="user")
    gamification = relationship(
        "UserGamification", back_populates="user", uselist=False,
        cascade="all, delete-orphan"
    )

    @property
    def points_balance(self) -> int:
        return sum(t.amount for t in self.point_transactions)


class Bike(Base):
    __tablename__ = "bikes"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    _photo_urls = Column("photo_urls", Text, default="[]")  # JSON list
    type = Column(Enum(BikeType), default=BikeType.city)
    brand = Column(String(100), nullable=True)
    frame_size = Column(String(20), nullable=True)
    hourly_price = Column(Float, default=0.0)
    daily_price = Column(Float, default=0.0)
    deposit = Column(Float, default=0.0)
    current_lat = Column(Float, nullable=False)
    current_lon = Column(Float, nullable=False)
    status = Column(Enum(BikeStatus), default=BikeStatus.available)
    lock_type = Column(String(20), default="manual", nullable=False)
    lock_instructions = Column(Text, nullable=True)
    smart_lock_provider = Column(String(80), nullable=True)
    smart_lock_device_id = Column(String(200), nullable=True)
    smart_lock_status = Column(String(30), default="not_connected", nullable=False)
    qr_version = Column(Integer, default=1, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    owner = relationship("User", back_populates="bikes", foreign_keys=[owner_id])
    rentals = relationship("Rental", back_populates="bike")
    delivery_jobs = relationship("DeliveryJob", back_populates="bike")
    reviews = relationship("Review", back_populates="bike")
    gps_device = relationship(
        "GPSDevice", back_populates="bike", uselist=False, cascade="all, delete-orphan"
    )

    @property
    def photo_urls(self):
        try:
            return json.loads(self._photo_urls or "[]")
        except (ValueError, TypeError):
            return []

    @photo_urls.setter
    def photo_urls(self, value):
        self._photo_urls = json.dumps(value or [])

    def distance_to(self, lat: float, lon: float) -> float:
        return _haversine(self.current_lat, self.current_lon, lat, lon)

    def avg_rating(self) -> float:
        if not self.reviews:
            return 0.0
        return sum(r.rating for r in self.reviews) / len(self.reviews)

    @property
    def identity_qr(self) -> str:
        secret = os.getenv("BIKE_QR_SECRET", "bicikleta-development-secret")
        payload = f"{self.id}:{self.qr_version}"
        signature = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()[:12]
        return f"BICI:{payload}:{signature}"


class Rental(Base):
    __tablename__ = "rentals"

    id = Column(Integer, primary_key=True, index=True)
    bike_id = Column(Integer, ForeignKey("bikes.id"), nullable=False)
    renter_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    start_time = Column(DateTime, nullable=True)
    end_time = Column(DateTime, nullable=True)
    pickup_lat = Column(Float, nullable=True)
    pickup_lon = Column(Float, nullable=True)
    return_lat = Column(Float, nullable=True)
    return_lon = Column(Float, nullable=True)
    total_price = Column(Float, default=0.0)
    status = Column(Enum(RentalStatus), default=RentalStatus.pending)
    created_at = Column(DateTime, default=datetime.utcnow)
    return_photo_url = Column(String(512), nullable=True)
    lock_confirmed = Column(Boolean, default=False)
    payment_provider = Column(String(30), default="demo", nullable=False)
    payment_intent_id = Column(String(200), nullable=True)
    payment_status = Column(String(40), default="not_started", nullable=False)
    authorized_amount = Column(Float, default=0.0)

    bike = relationship("Bike", back_populates="rentals")
    renter = relationship("User", back_populates="rentals", foreign_keys=[renter_id])
    reviews = relationship("Review", back_populates="rental")


class DeliveryJob(Base):
    """A request to move a bike from its current position to a target location."""
    __tablename__ = "delivery_jobs"

    id = Column(Integer, primary_key=True, index=True)
    bike_id = Column(Integer, ForeignKey("bikes.id"), nullable=False)
    posted_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    pickup_lat = Column(Float, nullable=False)
    pickup_lon = Column(Float, nullable=False)
    dropoff_lat = Column(Float, nullable=False)
    dropoff_lon = Column(Float, nullable=False)
    distance_km = Column(Float, default=0.0)
    reward_points = Column(Integer, default=0)
    status = Column(Enum(DeliveryJobStatus), default=DeliveryJobStatus.open)
    created_at = Column(DateTime, default=datetime.utcnow)

    bike = relationship("Bike", back_populates="delivery_jobs")
    posted_by = relationship("User", foreign_keys=[posted_by_id])
    segments = relationship(
        "DeliverySegment", back_populates="job", cascade="all, delete-orphan"
    )


class DeliverySegment(Base):
    """One leg of a relay delivery — a single courier's contribution."""
    __tablename__ = "delivery_segments"

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(Integer, ForeignKey("delivery_jobs.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    start_lat = Column(Float, nullable=False)
    start_lon = Column(Float, nullable=False)
    end_lat = Column(Float, nullable=True)
    end_lon = Column(Float, nullable=True)
    distance_km = Column(Float, default=0.0)
    earned_points = Column(Integer, default=0)
    status = Column(Enum(SegmentStatus), default=SegmentStatus.active)
    started_at = Column(DateTime, default=datetime.utcnow)
    ended_at = Column(DateTime, nullable=True)

    job = relationship("DeliveryJob", back_populates="segments")
    user = relationship("User", back_populates="delivery_segments")


class GPSLog(Base):
    __tablename__ = "gps_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reference_id = Column(Integer, nullable=False)
    reference_type = Column(String(20), nullable=False)  # "rental" | "delivery"
    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)


class GPSDevice(Base):
    """Tracker pairing metadata. Provider credentials belong in a secret store."""
    __tablename__ = "gps_devices"
    __table_args__ = (UniqueConstraint("provider", "provider_device_id"),)

    id = Column(Integer, primary_key=True, index=True)
    bike_id = Column(Integer, ForeignKey("bikes.id"), unique=True, nullable=False)
    provider = Column(String(80), nullable=False)
    provider_device_id = Column(String(200), nullable=False)
    connection_type = Column(String(30), nullable=False, default="rest")
    status = Column(String(30), nullable=False, default="pending_validation")
    installation_status = Column(String(30), nullable=False, default="pending")
    battery_level = Column(Float, nullable=True)
    signal_strength = Column(Float, nullable=True)
    firmware_version = Column(String(80), nullable=True)
    last_seen_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    bike = relationship("Bike", back_populates="gps_device")


class PointTransaction(Base):
    __tablename__ = "point_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    type = Column(Enum(PointType), default=PointType.earned)
    amount = Column(Integer, nullable=False)  # positive = credit, negative = debit
    description = Column(String(256), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="point_transactions")


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (UniqueConstraint("rental_id", "reviewer_id"),)

    id = Column(Integer, primary_key=True, index=True)
    bike_id = Column(Integer, ForeignKey("bikes.id"), nullable=False)
    reviewer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    rental_id = Column(Integer, ForeignKey("rentals.id"), nullable=True)
    rating = Column(Integer, nullable=False)  # 1-5
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    bike = relationship("Bike", back_populates="reviews")
    reviewer = relationship("User", back_populates="reviews", foreign_keys=[reviewer_id])
    rental = relationship("Rental", back_populates="reviews")


class UserGamification(Base):
    __tablename__ = "user_gamification"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    xp = Column(Integer, default=0)
    level = Column(Integer, default=1)
    total_km = Column(Float, default=0.0)
    co2_saved_kg = Column(Float, default=0.0)
    streak_days = Column(Integer, default=0)
    last_activity_date = Column(Date, nullable=True)
    total_deliveries = Column(Integer, default=0)
    total_rentals = Column(Integer, default=0)

    user = relationship("User", back_populates="gamification")

    def add_activity(self, km: float, deliveries: int = 0, rentals: int = 0):
        today = date.today()
        if self.last_activity_date == today:
            pass  # already active today
        elif self.last_activity_date and (today - self.last_activity_date).days == 1:
            self.streak_days += 1
        else:
            self.streak_days = 1
        self.last_activity_date = today
        self.total_km += km
        self.co2_saved_kg += km * 0.21  # ~210g CO₂ per km avoided vs car
        self.total_deliveries += deliveries
        self.total_rentals += rentals
        self.xp += int(km * 10) + deliveries * 50 + rentals * 30
        self.level = max(1, int(self.xp ** 0.45))  # soft level curve


class PartnerOffer(Base):
    __tablename__ = "partner_offers"

    id = Column(Integer, primary_key=True, index=True)
    partner_name = Column(String(200), nullable=False)
    title = Column(String(300), nullable=False)
    description = Column(Text, nullable=False)
    points_cost = Column(Integer, nullable=False)
    discount_code = Column(String(100), nullable=False)
    quantity = Column(Integer, nullable=True)  # NULL = unlimited
    active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    redemptions = relationship("Redemption", back_populates="offer")


class Redemption(Base):
    __tablename__ = "redemptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    offer_id = Column(Integer, ForeignKey("partner_offers.id"), nullable=False)
    points_spent = Column(Integer, nullable=False)
    redeemed_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="redemptions")
    offer = relationship("PartnerOffer", back_populates="redemptions")


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return great-circle distance in kilometres between two lat/lon points."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

