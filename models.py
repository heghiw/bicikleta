import math
import enum
from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Enum, Text
)
from sqlalchemy.orm import relationship
from database import Base


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class UserRole(str, enum.Enum):
    user = "user"
    admin = "admin"


class BikeStatus(str, enum.Enum):
    available = "available"
    in_transit = "in_transit"
    delivered = "delivered"


class TripStatus(str, enum.Enum):
    active = "active"
    completed = "completed"
    partial = "partial"   # bike dropped partway — relay allowed
    cancelled = "cancelled"


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    email = Column(String(200), unique=True, index=True, nullable=False)
    password_hash = Column(String(256), nullable=False)
    id_photo_url = Column(String(512), nullable=True)
    face_photo_url = Column(String(512), nullable=True)
    verified = Column(Boolean, default=False)
    role = Column(Enum(UserRole), default=UserRole.user)
    points_balance = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

    trips = relationship("Trip", back_populates="user", cascade="all, delete-orphan")
    point_transactions = relationship(
        "PointTransaction", back_populates="user", cascade="all, delete-orphan"
    )
    redemptions = relationship("Redemption", back_populates="user", cascade="all, delete-orphan")


class Bike(Base):
    __tablename__ = "bikes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=True)
    current_lat = Column(Float, nullable=False)
    current_lon = Column(Float, nullable=False)
    target_lat = Column(Float, nullable=False)
    target_lon = Column(Float, nullable=False)
    status = Column(Enum(BikeStatus), default=BikeStatus.available)
    points_per_km = Column(Float, default=1.0)
    created_at = Column(DateTime, default=datetime.utcnow)

    trips = relationship("Trip", back_populates="bike")

    def distance_to(self, lat: float, lon: float) -> float:
        """Haversine distance in km from bike current position to given coordinates."""
        return _haversine(self.current_lat, self.current_lon, lat, lon)

    def total_route_km(self) -> float:
        return _haversine(self.current_lat, self.current_lon, self.target_lat, self.target_lon)


class Trip(Base):
    __tablename__ = "trips"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    bike_id = Column(Integer, ForeignKey("bikes.id"), nullable=False)
    start_lat = Column(Float, nullable=False)
    start_lon = Column(Float, nullable=False)
    end_lat = Column(Float, nullable=True)
    end_lon = Column(Float, nullable=True)
    km = Column(Float, default=0.0)
    points_earned = Column(Integer, default=0)
    status = Column(Enum(TripStatus), default=TripStatus.active)
    started_at = Column(DateTime, default=datetime.utcnow)
    ended_at = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="trips")
    bike = relationship("Bike", back_populates="trips")
    location_updates = relationship(
        "LocationUpdate", back_populates="trip", cascade="all, delete-orphan"
    )


class LocationUpdate(Base):
    __tablename__ = "location_updates"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id"), nullable=False)
    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)
    recorded_at = Column(DateTime, default=datetime.utcnow)

    trip = relationship("Trip", back_populates="location_updates")


class PointTransaction(Base):
    __tablename__ = "point_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    delta = Column(Integer, nullable=False)    # positive = earn, negative = spend
    reason = Column(String(256), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="point_transactions")


class PartnerOffer(Base):
    __tablename__ = "partner_offers"

    id = Column(Integer, primary_key=True, index=True)
    partner_name = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    points_cost = Column(Integer, nullable=False)
    discount_code = Column(String(100), nullable=False)
    active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    redemptions = relationship("Redemption", back_populates="offer")


class Redemption(Base):
    __tablename__ = "redemptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    offer_id = Column(Integer, ForeignKey("partner_offers.id"), nullable=False)
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
