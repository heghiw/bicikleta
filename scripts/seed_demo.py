"""Reset the local development database and populate a complete demo dataset."""
from datetime import date, datetime, timedelta
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from auth import hash_password
from database import Base, SessionLocal, engine
from models import (
    Bike, BikeStatus, BikeType, DeliveryJob, DeliveryJobStatus,
    DeliverySegment, GPSDevice, GPSLog, PartnerOffer, PointTransaction,
    PointType, Redemption, Rental, RentalStatus, Review, SegmentStatus,
    User, UserGamification, UserRole, _haversine,
)


def seed() -> None:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    now = datetime.utcnow()
    try:
        admin = User(
            name="Javo Lando", email="admin@pedalshare.test",
            password_hash=hash_password("PedalShareAdmin!2026"),
            verified=True, role=UserRole.admin, rating=4.9,
        )
        partner = User(
            name="Tasio Potassio", email="tasio@pedalshare.test",
            password_hash=hash_password("DemoRider!2026"),
            verified=True, role=UserRole.user, rating=4.8,
        )
        db.add_all([admin, partner])
        db.flush()
        db.add_all([
            UserGamification(user_id=admin.id, xp=1860, level=29,
                total_km=142.6, co2_saved_kg=29.95, streak_days=8,
                last_activity_date=date.today(), total_deliveries=17,
                total_rentals=9),
            UserGamification(user_id=partner.id, xp=420, level=15,
                total_km=38.4, co2_saved_kg=8.06, streak_days=3,
                last_activity_date=date.today(), total_deliveries=3,
                total_rentals=5),
        ])

        # Prague locations clustered around the map's default centre. The final
        # value is a human-readable pickup point shown in the bike description.
        bike_specs = [
            ("Old Town City Bike", BikeType.city, 50.0870, 14.4208, BikeStatus.available, "Old Town Square"),
            ("Riverside E-Bike", BikeType.electric, 50.0755, 14.4142, BikeStatus.available, "Náplavka riverfront"),
            ("Karlín Commuter", BikeType.city, 50.0923, 14.4532, BikeStatus.available, "Karlín Square"),
            ("Holešovice Road Bike", BikeType.road, 50.1044, 14.4437, BikeStatus.available, "Strossmayer Square"),
            ("Vinohrady Hybrid", BikeType.city, 50.0752, 14.4377, BikeStatus.available, "Náměstí Míru"),
            ("Žižkov Electric", BikeType.electric, 50.0833, 14.4500, BikeStatus.available, "Jiřího z Poděbrad"),
            ("Smíchov Cargo Bike", BikeType.cargo, 50.0722, 14.4037, BikeStatus.available, "Anděl"),
            ("Letná Park Cruiser", BikeType.city, 50.0964, 14.4256, BikeStatus.available, "Letná Park"),
            ("Dejvice Folder", BikeType.folding, 50.1004, 14.3958, BikeStatus.reserved, "Vítězné Square"),
            ("Pankrác Mountain Bike", BikeType.mountain, 50.0518, 14.4396, BikeStatus.maintenance, "Pankrác"),
            ("Florenc Delivery E-Bike", BikeType.electric, 50.0902, 14.4397, BikeStatus.in_delivery, "Florenc"),
            ("Main Station City Bike", BikeType.city, 50.0830, 14.4354, BikeStatus.in_delivery, "Prague Main Station"),
            ("Invalidovna Road Bike", BikeType.road, 50.0961, 14.4644, BikeStatus.in_delivery, "Invalidovna"),
            ("Podolí Move Bike", BikeType.city, 50.0617, 14.4178, BikeStatus.in_delivery, "Podolí waterfront"),
            ("Bubeneč Move Bike", BikeType.city, 50.1053, 14.4018, BikeStatus.in_delivery, "Bubeneč"),
            ("Strašnice Move E-Bike", BikeType.electric, 50.0731, 14.4931, BikeStatus.in_delivery, "Strašnice"),
            ("Libeň Move Bike", BikeType.city, 50.1048, 14.4742, BikeStatus.in_delivery, "Libeň"),
            ("Vyšehrad Move Bike", BikeType.folding, 50.0643, 14.4196, BikeStatus.in_delivery, "Vyšehrad"),
            ("Břevnov Move Cargo", BikeType.cargo, 50.0845, 14.3578, BikeStatus.in_delivery, "Břevnov"),
            ("Vršovice Move Bike", BikeType.city, 50.0675, 14.4670, BikeStatus.in_delivery, "Vršovice"),
        ]
        bikes = []
        brands = ["Favorit", "KTM", "Trek", "Tern", "Author", "Specialized", "Yuba"]
        for index, (title, kind, lat, lon, status, location) in enumerate(bike_specs):
            bike = Bike(owner_id=admin.id, title=title,
                description=f"Demo bike. Pickup near {location}, Prague.",
                type=kind, brand=brands[index % len(brands)],
                frame_size="M", hourly_price=3.5 + index,
                daily_price=19 + index * 3, deposit=60 + index * 10,
                current_lat=lat, current_lon=lon, status=status)
            db.add(bike)
            bikes.append(bike)
        guest_bike = Bike(owner_id=partner.id, title="Tasio's Blue Hybrid",
            description="Comfortable hybrid used in the completed demo rental.",
            type=BikeType.city, brand="Author", frame_size="S",
            hourly_price=4.0, daily_price=22.0, deposit=70.0,
            current_lat=50.0755, current_lon=14.4378,
            status=BikeStatus.available)
        db.add(guest_bike)
        db.flush()

        db.add_all([
            GPSDevice(bike_id=bikes[0].id, provider="DemoTrack",
                provider_device_id="PS-DEMO-001", connection_type="mqtt",
                status="online", installation_status="installed",
                battery_level=87, signal_strength=92,
                firmware_version="2.4.1", last_seen_at=now),
            GPSDevice(bike_id=bikes[1].id, provider="DemoTrack",
                provider_device_id="PS-DEMO-002", connection_type="rest",
                status="online", installation_status="installed",
                battery_level=63, signal_strength=78,
                firmware_version="2.4.1", last_seen_at=now - timedelta(minutes=3)),
        ])

        destinations = [
            (50.1010, 14.5000, 120), (50.1210, 14.5200, 180),
            (50.1090, 14.4930, 145), (50.0755, 14.4378, 95),
            (50.0870, 14.4208, 110), (50.0920, 14.4530, 85),
            (50.0964, 14.4256, 130), (50.0722, 14.4037, 105),
            (50.0830, 14.4354, 160), (50.0902, 14.4397, 100),
        ]
        jobs = []
        move_bikes = [bike for bike in bikes if bike.status == BikeStatus.in_delivery]
        for bike, (lat, lon, reward) in zip(move_bikes, destinations):
            job = DeliveryJob(bike_id=bike.id, posted_by_id=admin.id,
                pickup_lat=bike.current_lat, pickup_lon=bike.current_lon,
                dropoff_lat=lat, dropoff_lon=lon,
                distance_km=round(_haversine(bike.current_lat, bike.current_lon, lat, lon), 2),
                reward_points=reward, status=DeliveryJobStatus.open)
            db.add(job)
            jobs.append(job)
        db.flush()

        completed_job = DeliveryJob(bike_id=bikes[6].id, posted_by_id=admin.id,
            pickup_lat=50.0500, pickup_lon=14.4100,
            dropoff_lat=bikes[6].current_lat, dropoff_lon=bikes[6].current_lon,
            distance_km=3.1, reward_points=75, status=DeliveryJobStatus.completed,
            created_at=now - timedelta(days=2))
        db.add(completed_job)
        db.flush()
        segment = DeliverySegment(job_id=completed_job.id, user_id=admin.id,
            start_lat=50.0500, start_lon=14.4100,
            end_lat=bikes[6].current_lat, end_lon=bikes[6].current_lon,
            distance_km=3.1, earned_points=75, status=SegmentStatus.completed,
            started_at=now - timedelta(days=2, hours=1),
            ended_at=now - timedelta(days=2))
        db.add(segment)

        rental = Rental(bike_id=guest_bike.id, renter_id=admin.id,
            start_time=now - timedelta(days=4, hours=2),
            end_time=now - timedelta(days=4),
            pickup_lat=50.0755, pickup_lon=14.4378,
            return_lat=50.0900, return_lon=14.4600,
            total_price=8.0, status=RentalStatus.completed,
            created_at=now - timedelta(days=4, hours=3))
        db.add(rental)
        db.flush()
        db.add(Review(bike_id=guest_bike.id, reviewer_id=admin.id,
            rental_id=rental.id, rating=5,
            comment="Smooth ride and easy pickup.",
            created_at=now - timedelta(days=4)))

        db.add_all([
            PointTransaction(user_id=admin.id, type=PointType.earned,
                amount=250, description="Demo delivery rewards"),
            PointTransaction(user_id=admin.id, type=PointType.bonus,
                amount=100, description="Eight-day streak bonus"),
            PointTransaction(user_id=admin.id, type=PointType.earned,
                amount=75, description="Completed delivery #demo"),
        ])
        for index, (lat, lon) in enumerate([(50.0500, 14.4100),
                (50.0600, 14.4200), (50.0710, 14.4300)]):
            db.add(GPSLog(user_id=admin.id, reference_id=completed_job.id,
                reference_type="delivery", lat=lat, lon=lon,
                timestamp=now - timedelta(days=2, minutes=20 - index * 10)))

        offers = [
            PartnerOffer(partner_name="Bike Café Prague", title="Free coffee",
                description="One barista coffee after a completed bike move.",
                points_cost=100, discount_code="PEDALCOFFEE", quantity=100),
            PartnerOffer(partner_name="CycleWorks", title="15% service discount",
                description="Discount on a standard bicycle service.",
                points_cost=250, discount_code="PEDAL15", quantity=25),
        ]
        db.add_all(offers)
        db.flush()
        db.add(Redemption(user_id=admin.id, offer_id=offers[0].id,
            points_spent=100, redeemed_at=now - timedelta(days=1)))
        db.add(PointTransaction(user_id=admin.id, type=PointType.spent,
            amount=-100, description="Redeemed Free coffee"))
        db.commit()
        print("Seeded demo database for admin@pedalshare.test")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
