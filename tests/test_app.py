"""Integration tests for the PedalShare API."""
import io
import os
import pytest

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("UPLOAD_DIR", "/tmp/ps_test_uploads")

import database as db_module
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Use in-memory SQLite with StaticPool so all connections share one DB
_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
_Session = sessionmaker(autocommit=False, autoflush=False, bind=_engine)

db_module.engine = _engine
db_module.SessionLocal = _Session

import models
models.Base.metadata.create_all(bind=_engine)

from fastapi.testclient import TestClient
from main import app

# Override the get_db dependency so the app uses our test session
from database import get_db

def _override_get_db():
    db = _Session()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = _override_get_db

client = TestClient(app)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _img():
    return ("test.jpg", io.BytesIO(b"\xff\xd8\xff" + b"\x00" * 20), "image/jpeg")


def _register(email="u@example.com", pw="test1234", name="Test User"):
    return client.post(
        "/api/auth/register",
        data={"name": name, "email": email, "password": pw},
        files={"id_document": _img(), "selfie": _img()},
    )


def _login(email="u@example.com", pw="test1234"):
    return client.post(
        "/api/auth/login",
        data={"username": email, "password": pw},
    )


def _headers(email="u@example.com", pw="test1234"):
    r = _login(email, pw)
    assert r.status_code == 200, r.text
    return {"Authorization": "Bearer " + r.json()["access_token"]}


def _make_admin(email):
    with _Session() as db:
        u = db.query(models.User).filter(models.User.email == email).first()
        u.role = models.UserRole.admin
        u.verified = True
        db.commit()


def _make_verified(email):
    with _Session() as db:
        u = db.query(models.User).filter(models.User.email == email).first()
        u.verified = True
        db.commit()


def _give_points(email, pts):
    with _Session() as db:
        u = db.query(models.User).filter(models.User.email == email).first()
        tx = models.PointTransaction(user_id=u.id, type=models.PointType.bonus, amount=pts, description="test")
        db.add(tx)
        db.commit()


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

def test_register_creates_unverified_user():
    r = _register("new@test.com")
    assert r.status_code == 201
    d = r.json()
    assert d["email"] == "new@test.com"
    assert d["verified"] is False
    assert d["points_balance"] == 0


def test_register_duplicate_email():
    _register("dup@test.com")
    assert _register("dup@test.com").status_code == 409


def test_login_success():
    _register("log@test.com")
    r = _login("log@test.com")
    assert r.status_code == 200
    assert "access_token" in r.json()


def test_login_wrong_password():
    _register("bad@test.com")
    r = client.post("/api/auth/login", data={"username": "bad@test.com", "password": "wrong"})
    assert r.status_code == 401


# ---------------------------------------------------------------------------
# User / Profile
# ---------------------------------------------------------------------------

def test_get_profile():
    _register("prof@test.com")
    h = _headers("prof@test.com")
    r = client.get("/api/users/me", headers=h)
    assert r.status_code == 200
    assert r.json()["email"] == "prof@test.com"


def test_update_name():
    _register("upd@test.com")
    h = _headers("upd@test.com")
    r = client.patch("/api/users/me", json={"name": "New Name"}, headers=h)
    assert r.status_code == 200
    assert r.json()["name"] == "New Name"


def test_gamification_endpoint():
    _register("gamer@test.com")
    h = _headers("gamer@test.com")
    r = client.get("/api/users/me/gamification", headers=h)
    assert r.status_code == 200
    assert "xp" in r.json()


# ---------------------------------------------------------------------------
# Bikes
# ---------------------------------------------------------------------------

def _create_bike(email, **kwargs):
    _register(email)
    _make_verified(email)
    h = _headers(email)
    defaults = {
        "title": "Test Bike", "type": "city",
        "hourly_price": 3.0, "daily_price": 18.0, "deposit": 50.0,
        "current_lat": 52.52, "current_lon": 13.405,
    }
    defaults.update(kwargs)
    return client.post("/api/bikes/", json=defaults, headers=h), h


def test_create_bike_requires_verified():
    _register("unv@test.com")
    h = _headers("unv@test.com")
    r = client.post("/api/bikes/", json={
        "title": "B", "type": "city", "hourly_price": 3, "daily_price": 18,
        "deposit": 50, "current_lat": 52.52, "current_lon": 13.405,
    }, headers=h)
    assert r.status_code == 403


def test_create_and_list_bike():
    r, h = _create_bike("lister@test.com")
    assert r.status_code == 201
    assert r.json()["title"] == "Test Bike"
    listed = client.get("/api/bikes/mine", headers=h).json()
    assert any(b["id"] == r.json()["id"] for b in listed)


def test_bike_search():
    _create_bike("searcher@test.com", current_lat=52.52, current_lon=13.405)
    # Different user searches
    _register("finder@test.com")
    h = _headers("finder@test.com")
    r = client.post("/api/bikes/search", json={"user_lat": 52.52, "user_lon": 13.405, "radius_km": 5.0}, headers=h)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_delete_bike_owner_only():
    r, h = _create_bike("del_owner@test.com")
    bike_id = r.json()["id"]
    # Other user cannot delete
    _register("other@test.com")
    h2 = _headers("other@test.com")
    assert client.delete(f"/api/bikes/{bike_id}", headers=h2).status_code == 403
    # Owner can delete
    assert client.delete(f"/api/bikes/{bike_id}", headers=h).status_code == 204


# ---------------------------------------------------------------------------
# Rentals
# ---------------------------------------------------------------------------

def test_full_rental_flow():
    bike_r, owner_h = _create_bike("bike_owner@test.com", current_lat=52.520, current_lon=13.405)
    bike_id = bike_r.json()["id"]

    _register("renter@test.com")
    _make_verified("renter@test.com")
    renter_h = _headers("renter@test.com")

    # Book
    r = client.post("/api/rentals/", json={"bike_id": bike_id, "pickup_lat": 52.520, "pickup_lon": 13.405}, headers=renter_h)
    assert r.status_code == 201
    rental_id = r.json()["id"]

    # Start
    r = client.post(f"/api/rentals/{rental_id}/start", headers=renter_h)
    assert r.status_code == 200
    assert r.json()["status"] == "active"

    # End
    r = client.post(f"/api/rentals/{rental_id}/end", json={"return_lat": 52.530, "return_lon": 13.415}, headers=renter_h)
    assert r.status_code == 200
    assert r.json()["status"] == "completed"
    assert r.json()["total_price"] >= 0

    # Check points awarded
    profile = client.get("/api/users/me", headers=renter_h).json()
    assert profile["points_balance"] > 0


def test_cannot_book_unavailable_bike():
    bike_r, _ = _create_bike("nobooker@test.com")
    bike_id = bike_r.json()["id"]
    _register("renter2@test.com")
    _make_verified("renter2@test.com")
    h = _headers("renter2@test.com")
    # Book once
    client.post("/api/rentals/", json={"bike_id": bike_id, "pickup_lat": 52.52, "pickup_lon": 13.405}, headers=h)
    # Try booking again — should fail
    r = client.post("/api/rentals/", json={"bike_id": bike_id, "pickup_lat": 52.52, "pickup_lon": 13.405}, headers=h)
    assert r.status_code == 409


# ---------------------------------------------------------------------------
# Delivery
# ---------------------------------------------------------------------------

def test_full_delivery_flow():
    bike_r, owner_h = _create_bike("djob_owner@test.com", current_lat=52.510, current_lon=13.400)
    bike_id = bike_r.json()["id"]

    # Post delivery job
    r = client.post("/api/delivery/jobs", json={
        "bike_id": bike_id, "dropoff_lat": 52.540, "dropoff_lon": 13.430, "reward_points": 80
    }, headers=owner_h)
    assert r.status_code == 201
    job_id = r.json()["id"]

    # Courier accepts
    _register("courier@test.com")
    _make_verified("courier@test.com")
    c_h = _headers("courier@test.com")
    r = client.post(f"/api/delivery/jobs/{job_id}/accept", json={"start_lat": 52.510, "start_lon": 13.400}, headers=c_h)
    assert r.status_code == 201
    seg_id = r.json()["id"]

    # Courier completes
    r = client.post(f"/api/delivery/segments/{seg_id}/complete", json={
        "end_lat": 52.540, "end_lon": 13.430, "relay": False
    }, headers=c_h)
    assert r.status_code == 200
    assert r.json()["status"] == "completed"
    assert r.json()["earned_points"] > 0

    # Points awarded
    profile = client.get("/api/users/me", headers=c_h).json()
    assert profile["points_balance"] > 0


def test_relay_delivery():
    bike_r, owner_h = _create_bike("relay_owner@test.com", current_lat=52.500, current_lon=13.390)
    bike_id = bike_r.json()["id"]

    r = client.post("/api/delivery/jobs", json={
        "bike_id": bike_id, "dropoff_lat": 52.560, "dropoff_lon": 13.460, "reward_points": 100
    }, headers=owner_h)
    job_id = r.json()["id"]

    # Courier A does a partial relay
    _register("relay_a@test.com")
    _make_verified("relay_a@test.com")
    a_h = _headers("relay_a@test.com")
    seg_r = client.post(f"/api/delivery/jobs/{job_id}/accept", json={"start_lat": 52.500, "start_lon": 13.390}, headers=a_h)
    seg_id = seg_r.json()["id"]
    r = client.post(f"/api/delivery/segments/{seg_id}/complete", json={"end_lat": 52.530, "end_lon": 13.420, "relay": True}, headers=a_h)
    assert r.json()["status"] == "completed"

    # Job should be open again for next courier
    job = client.get(f"/api/delivery/jobs/{job_id}", headers=a_h).json()
    assert job["status"] == "open"


# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

def test_shop_redeem_flow():
    _register("shopper@test.com")
    _make_admin("shopper@test.com")
    _give_points("shopper@test.com", 200)
    h = _headers("shopper@test.com")

    r = client.post("/api/shop/offers", json={
        "partner_name": "CaféBike", "title": "10% off coffee",
        "description": "Get 10% off", "points_cost": 100, "discount_code": "BIKE10"
    }, headers=h)
    assert r.status_code == 201
    offer_id = r.json()["id"]

    # Public listing hides code
    offers = client.get("/api/shop/offers", headers=h).json()
    assert all(o.get("discount_code") is None for o in offers)

    # Redeem
    r = client.post(f"/api/shop/offers/{offer_id}/redeem", headers=h)
    assert r.status_code == 200
    assert r.json()["discount_code"] == "BIKE10"

    # Points deducted
    profile = client.get("/api/users/me", headers=h).json()
    assert profile["points_balance"] == 100  # 200 - 100


def test_redeem_insufficient_points():
    _register("broke2@test.com")
    _make_admin("broke2@test.com")
    h = _headers("broke2@test.com")
    r = client.post("/api/shop/offers", json={
        "partner_name": "X", "title": "Big discount",
        "description": "desc", "points_cost": 500, "discount_code": "BIG"
    }, headers=h)
    offer_id = r.json()["id"]
    r = client.post(f"/api/shop/offers/{offer_id}/redeem", headers=h)
    assert r.status_code == 402


# ---------------------------------------------------------------------------
# Gamification leaderboard
# ---------------------------------------------------------------------------

def test_leaderboard():
    _register("leader@test.com")
    h = _headers("leader@test.com")
    r = client.get("/api/gamification/leaderboard", headers=h)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

def test_health():
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"
