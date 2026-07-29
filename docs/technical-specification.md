# Technical Specification — Bike Rental, Tracking and Redistribution Platform

## 1. Product Overview

The platform allows users to register and track their own bicycles, rent bicycles from other users, list their bicycles for rent, request or perform bicycle delivery, relocate bicycles for rewards, and redeem earned points with partner businesses.

Each registered bicycle can optionally be connected to a personal GPS tracking device supplied and installed by the owner.

The product will initially be delivered as a mobile-first application with a backend API and an administrator web panel.

---

## 2. User Roles

A single account may use multiple roles.

### 2.1 Bike Owner

The owner can:

* register one or more bicycles;
* connect a compatible GPS tracker;
* monitor bicycle location and status;
* configure security alerts;
* publish a bicycle for rent;
* configure rental pricing and availability;
* request bicycle delivery;
* approve returns;
* report a bicycle as lost or stolen.

### 2.2 Renter

The renter can:

* search for bicycles;
* view bicycle details;
* reserve and pay for a bicycle;
* select pickup or delivery;
* track an active rental;
* return the bicycle;
* review the owner and bicycle.

### 2.3 Courier

The courier can:

* search for bicycle relocation tasks;
* receive tasks matching their planned route;
* accept full or partial transport;
* scan and collect a bicycle;
* transport and deliver it;
* earn points or monetary compensation;
* participate in relay deliveries.

### 2.4 Administrator

The administrator can:

* verify users;
* review identity documents;
* manage users and bicycles;
* manage rentals and delivery tasks;
* manage GPS integrations;
* resolve disputes;
* manage reward rates;
* manage partners and discount offers;
* review fraud and security alerts.

---

## 3. Application Navigation

The primary bottom navigation must contain:

1. Home
2. Explore
3. My Bikes
4. Activity
5. Profile

The Rewards section may be accessed from Home, Profile, or the points balance component.

---

## 4. Authentication and User Verification

### 4.1 Registration

The registration form must include:

* email;
* password;
* password confirmation;
* full name;
* phone number;
* acceptance of terms and privacy policy.

### 4.2 Authentication

The backend must support:

* email and password authentication;
* email verification;
* password reset;
* JWT access tokens;
* refresh tokens;
* logout;
* logout from all devices;
* token revocation.

### 4.3 Identity Verification

Identity verification is required before a user can:

* publish a bicycle;
* rent a bicycle;
* accept a delivery task;
* redeem rewards with monetary value.

The user must upload:

* government-issued identity document;
* selfie or face photo.

Verification statuses:

* not_started;
* pending;
* approved;
* rejected;
* resubmission_required.

Uploads must be stored in private object storage and only accessible through short-lived signed URLs.

### 4.4 User Profile

Profile data:

* full name;
* email;
* phone number;
* profile image;
* city;
* preferred language;
* account verification status;
* rating;
* points balance;
* payment and payout status.

---

## 5. Home Dashboard

The Home screen must include:

* current location;
* profile image;
* notification icon;
* points balance;
* active rental or delivery task;
* personal bicycle alerts;
* nearby rental bicycles;
* nearby delivery tasks;
* quick actions.

Quick actions:

* Rent a Bike
* Deliver a Bike
* Add My Bike
* Track My Bike
* List My Bike
* Rewards

### 5.1 Dashboard API

```http
GET /api/v1/dashboard
```

The response should include:

```json
{
  "user": {},
  "points_balance": 0,
  "active_activity": null,
  "bike_alerts": [],
  "nearby_bikes": [],
  "nearby_delivery_tasks": []
}
```

### 5.2 Dashboard States

The UI must support:

* loading;
* empty state;
* location permission denied;
* GPS unavailable;
* verification pending;
* network error;
* offline mode.

---

## 6. Bicycle Registration

### 6.1 Add Bicycle Form

Required fields:

* bicycle name;
* type;
* brand;
* model;
* color;
* frame size;
* serial number;
* main photo.

Optional fields:

* year;
* description;
* additional photos;
* purchase price;
* current estimated value;
* proof of ownership;
* electric bicycle battery details;
* insurance details.

Supported bicycle types:

* city;
* road;
* mountain;
* gravel;
* electric;
* cargo;
* folding;
* other.

### 6.2 Bicycle Statuses

```text
draft
active
available_for_rent
reserved
rented
awaiting_pickup
in_delivery
maintenance
disabled
lost
stolen
```

### 6.3 Bicycle API

```http
POST /api/v1/bikes
GET /api/v1/bikes
GET /api/v1/bikes/{bike_id}
PATCH /api/v1/bikes/{bike_id}
DELETE /api/v1/bikes/{bike_id}
POST /api/v1/bikes/{bike_id}/photos
```

### 6.4 Acceptance Criteria

* A user can register multiple bicycles.
* Serial numbers must be unique when provided.
* At least one bicycle photo is required before publication.
* Deleted bicycles must be soft-deleted.
* A bicycle involved in an active rental or delivery cannot be deleted.
* Editing ownership-sensitive fields must be recorded in an audit log.

---

## 7. Personal GPS Tracker Integration

### 7.1 Objective

Users can purchase and install their own compatible GPS tracker and connect it to a registered bicycle.

The platform must not assume that all trackers use the same protocol.

### 7.2 Initial Integration Types

The backend architecture must support providers using:

* REST API;
* webhooks;
* MQTT;
* TCP device protocol;
* periodic device polling;
* generic tracker gateway.

Bluetooth-only item trackers must not be treated as real-time GPS unless the provider offers a supported cloud integration.

### 7.3 Tracker Pairing Flow

1. User opens a bicycle.
2. User selects Connect Tracker.
3. User selects the provider or Generic GPS.
4. User scans a QR code or enters a device ID.
5. User enters an activation code if required.
6. Backend validates the device.
7. App displays a test location.
8. User confirms pairing.
9. Tracker becomes active.

### 7.4 GPS Tracker Data

The platform must store:

* tracker ID;
* bicycle ID;
* provider;
* provider device ID;
* connection type;
* last position;
* last seen timestamp;
* battery level;
* signal strength;
* firmware version;
* online status;
* installation status.

Secrets such as API keys and provider tokens must be encrypted and must not be returned to the client.

### 7.5 GPS Position Data

Each position record may include:

* latitude;
* longitude;
* altitude;
* accuracy;
* speed;
* heading;
* battery;
* signal;
* timestamp;
* source.

### 7.6 GPS APIs

```http
POST /api/v1/bikes/{bike_id}/tracker/pair
POST /api/v1/bikes/{bike_id}/tracker/test
GET /api/v1/bikes/{bike_id}/tracker
DELETE /api/v1/bikes/{bike_id}/tracker
GET /api/v1/bikes/{bike_id}/locations/latest
GET /api/v1/bikes/{bike_id}/locations/history
```

Provider callbacks:

```http
POST /api/v1/integrations/gps/{provider}/webhook
```

### 7.7 Security Features

The owner can configure:

* movement alert;
* geofence;
* battery alert;
* tracker offline alert;
* tamper alert;
* speed alert;
* night movement alert;
* crash alert where supported.

### 7.8 Bicycle Security Modes

```text
normal
armed
rental_active
delivery_active
lost_mode
stolen_mode
```

When Lost Mode is enabled:

* new rentals must be disabled;
* active reservations must be flagged;
* GPS update frequency should be increased when supported;
* movement alerts must be prioritized;
* location history must be preserved;
* the owner may export a police report package.

---

## 8. Explore and Search

The Explore screen must support two modes:

* Rental
* Delivery

The user may switch between map and list views.

### 8.1 Common Components

* location search;
* current location;
* map;
* map markers;
* result cards;
* filter button;
* sorting;
* Search This Area;
* saved items.

---

## 9. Rental Search

### 9.1 Rental Filters

* date and time;
* bicycle type;
* price range;
* distance;
* frame size;
* electric or non-electric;
* instant booking;
* delivery available;
* owner rating.

### 9.2 Rental Search API

```http
GET /api/v1/bikes/search
```

Parameters:

```text
latitude
longitude
radius_km
available_from
available_to
bike_type
frame_size
electric
min_price
max_price
instant_booking
delivery_available
sort
```

### 9.3 Result Ranking

Results should be ranked using:

* availability;
* distance;
* user preferences;
* price;
* rating;
* delivery availability;
* listing quality.

---

## 10. Bicycle Rental Listing

The bicycle detail screen must include:

* photos;
* bicycle name;
* brand and model;
* type;
* frame size;
* description;
* current approximate location;
* owner rating;
* rental price;
* deposit;
* availability calendar;
* pickup options;
* delivery options;
* cancellation policy;
* reviews;
* GPS verification badge where applicable.

Exact personal bicycle location must not be shown publicly before booking confirmation.

---

## 11. Rental Configuration for Owners

The owner can configure:

* hourly price;
* daily price;
* weekly price;
* security deposit;
* minimum rental duration;
* maximum rental duration;
* availability calendar;
* instant booking;
* manual approval;
* pickup instructions;
* delivery availability;
* delivery price;
* renter minimum rating;
* cancellation policy.

### 11.1 Listing APIs

```http
POST /api/v1/bikes/{bike_id}/listing
GET /api/v1/bikes/{bike_id}/listing
PATCH /api/v1/bikes/{bike_id}/listing
POST /api/v1/bikes/{bike_id}/listing/publish
POST /api/v1/bikes/{bike_id}/listing/unpublish
```

---

## 12. Rental Booking Flow

1. User selects a bicycle.
2. User selects rental dates.
3. User chooses pickup or delivery.
4. Backend validates availability.
5. Backend calculates price.
6. User confirms payment.
7. Deposit is authorized.
8. Booking is created.
9. Owner is notified.
10. Rental starts after pickup confirmation.

### 12.1 Rental Price Breakdown

The checkout must display:

* rental price;
* delivery fee;
* platform fee;
* discount;
* taxes where applicable;
* deposit authorization;
* total charged.

### 12.2 Rental Statuses

```text
pending
awaiting_owner_approval
confirmed
awaiting_pickup
active
awaiting_return_confirmation
completed
cancelled
disputed
```

### 12.3 Rental APIs

```http
POST /api/v1/rentals/quote
POST /api/v1/rentals
GET /api/v1/rentals/{rental_id}
POST /api/v1/rentals/{rental_id}/approve
POST /api/v1/rentals/{rental_id}/reject
POST /api/v1/rentals/{rental_id}/start
POST /api/v1/rentals/{rental_id}/return
POST /api/v1/rentals/{rental_id}/confirm-return
POST /api/v1/rentals/{rental_id}/cancel
POST /api/v1/rentals/{rental_id}/dispute
```

### 12.4 Pickup Validation

Pickup may require:

* QR code scan;
* GPS proximity check;
* bicycle condition photos;
* owner confirmation;
* renter confirmation.

### 12.5 Return Validation

Return may require:

* GPS location verification;
* QR scan;
* condition photos;
* owner confirmation;
* automatic deposit release;
* dispute creation when damage is reported.

---

## 13. Payments and Payouts

The payment system must support:

* card payments;
* deposits or payment authorization;
* refunds;
* owner payouts;
* courier payouts where enabled;
* platform commission;
* discount codes;
* payment transaction history.

Payment details must be handled by a payment provider and must not be stored directly in the application database.

### 13.1 Payment Statuses

```text
pending
authorized
captured
failed
refunded
partially_refunded
cancelled
```

---

## 14. Bicycle Delivery and Redistribution

A delivery task represents the transport of a bicycle from one location to another.

Tasks may be created by:

* bicycle owner;
* administrator;
* rental booking;
* redistribution algorithm;
* partner operator.

### 14.1 Delivery Task Data

* bicycle;
* pickup location;
* required destination;
* pickup time window;
* delivery deadline;
* estimated distance;
* reward points;
* monetary reward where applicable;
* priority;
* full delivery requirement;
* partial delivery allowed;
* handling instructions.

### 14.2 Delivery Statuses

```text
open
reserved
accepted
going_to_pickup
at_pickup
bike_collected
in_transport
partially_completed
awaiting_confirmation
completed
cancelled
failed
disputed
```

### 14.3 Delivery Search Filters

* distance from user;
* transport distance;
* minimum reward;
* maximum additional distance;
* pickup time;
* delivery deadline;
* full or partial task;
* bicycle type.

### 14.4 Delivery Search API

```http
GET /api/v1/delivery-tasks/search
```

Parameters:

```text
latitude
longitude
radius_km
destination_latitude
destination_longitude
min_reward
max_task_distance
max_detour_distance
partial_allowed
available_from
sort
```

---

## 15. Route Matching

### 15.1 Pickup Mode

The user enters their own destination.

The backend must identify bicycles that:

* are near the user or their route;
* need to travel in a similar direction;
* can be transported fully or partially;
* require an acceptable detour.

The result must show:

* bicycle pickup location;
* required destination;
* user route overlap;
* additional distance;
* estimated additional time;
* reward;
* full or partial compatibility.

### 15.2 Delivery Mode

The user chooses a search radius.

The backend returns available relocation tasks ranked by:

* reward;
* distance to pickup;
* transport distance;
* urgency;
* route compatibility.

### 15.3 Geospatial Implementation

PostgreSQL with PostGIS should be used.

Required operations include:

* radius search;
* nearest point;
* route corridor intersection;
* distance calculation;
* geofence checks;
* pickup and drop-off validation.

Route geometry should be stored as PostGIS geometry or geography objects.

---

## 16. Partial and Relay Delivery

A courier may transport a bicycle only part of the required route when partial delivery is allowed.

### 16.1 Partial Delivery Flow

1. Courier selects Propose Partial Delivery.
2. Courier chooses or confirms a proposed drop-off point.
3. Backend validates that the point advances the bicycle toward the destination.
4. Backend calculates partial reward.
5. Courier accepts the segment.
6. Bicycle is transported.
7. Drop-off is validated.
8. Remaining task becomes available to other couriers.

### 16.2 Relay Rules

* A bicycle can have multiple sequential segments.
* Only one active courier may hold the bicycle at a time.
* Every handover must be recorded.
* Every segment must have start and end evidence.
* Partial points must be awarded after validation.
* The next segment must use the previous segment endpoint as pickup location.

### 16.3 Delivery Segment API

```http
POST /api/v1/delivery-tasks/{task_id}/partial-quote
POST /api/v1/delivery-tasks/{task_id}/accept
POST /api/v1/delivery-tasks/{task_id}/segments
POST /api/v1/delivery-segments/{segment_id}/pickup
POST /api/v1/delivery-segments/{segment_id}/complete
```

---

## 17. Active Delivery Tracking

During an active delivery, the app must display:

* task status;
* navigation map;
* bicycle information;
* pickup or destination details;
* GPS tracker status;
* user location;
* route;
* remaining distance;
* contact and support options.

### 17.1 Collection Requirements

The courier may be required to:

* enter a one-time code;
* scan bicycle QR code;
* confirm GPS proximity;
* upload bicycle condition photos;
* confirm tracker status.

### 17.2 Delivery Completion Requirements

The courier may be required to:

* confirm GPS proximity to the destination;
* scan a destination QR code;
* upload proof photo;
* enter a handover code;
* receive owner or system confirmation.

---

## 18. User Location Tracking

User location may only be collected during:

* active rental pickup or return;
* active bicycle delivery;
* navigation explicitly started by the user;
* emergency or lost bicycle interaction explicitly enabled by the user.

The application must clearly display when tracking is active.

### 18.1 Location Update Method

The client should send periodic location updates.

WebSocket may be used for active status updates, but location persistence should use an authenticated HTTP or streaming endpoint.

```http
POST /api/v1/trips/{trip_id}/locations
```

### 18.2 Privacy Requirements

* Tracking must stop after task completion.
* The user must be able to see when tracking is enabled.
* Location retention must be configurable.
* Raw location data must not be used for unrelated marketing.
* Public users must never see another user’s exact live location.
* Sensitive location endpoints must require authorization checks.

---

## 19. Bonus Points System

Points are earned through:

* completed relocation tasks;
* partial delivery segments;
* referrals;
* promotional campaigns;
* verified community assistance.

Points are spent through:

* partner discounts;
* rental discounts;
* delivery discounts;
* platform rewards.

### 19.1 Ledger Model

Points must be stored as immutable ledger transactions.

Transaction types:

```text
delivery_reward
partial_delivery_reward
referral_reward
promotion_reward
redemption
rental_discount
admin_adjustment
reversal
```

The displayed balance is the sum of confirmed ledger entries.

### 19.2 Points APIs

```http
GET /api/v1/points/balance
GET /api/v1/points/transactions
```

Points must be credited only after the associated action is validated.

---

## 20. Partner Rewards Shop

The Rewards screen must show:

* points balance;
* available partner offers;
* category filters;
* points cost;
* offer terms;
* redemption history.

### 20.1 Redemption Flow

1. User selects an offer.
2. Backend validates balance and availability.
3. Points are reserved or deducted transactionally.
4. A unique discount code is assigned.
5. The code is shown to the user.
6. Redemption is stored in history.

### 20.2 Rewards APIs

```http
GET /api/v1/rewards/offers
GET /api/v1/rewards/offers/{offer_id}
POST /api/v1/rewards/offers/{offer_id}/redeem
GET /api/v1/rewards/redemptions
```

Redemption and points deduction must occur in one database transaction.

---

## 21. Activity Section

The Activity section must contain:

* upcoming rentals;
* active rentals;
* previous rentals;
* active deliveries;
* completed deliveries;
* relay segments;
* cancelled activities;
* disputes.

Filters:

* All
* Rentals
* Deliveries
* Completed
* Cancelled

---

## 22. Notifications

The platform must support push and in-app notifications for:

* email verification;
* identity verification result;
* booking request;
* booking confirmation;
* rental reminder;
* rental start;
* return reminder;
* delivery task accepted;
* pickup deadline;
* delivery completion;
* GPS movement;
* geofence exit;
* tracker offline;
* low tracker battery;
* lost mode movement;
* points credited;
* reward redeemed;
* dispute update.

Notification preferences must be configurable per category.

---

## 23. Ratings and Reviews

After a completed rental, the renter and owner may review each other.

After a completed delivery, the bicycle owner or system may rate the courier.

Review data:

* rating from 1 to 5;
* optional text;
* related rental or delivery;
* author;
* recipient;
* moderation status.

Reviews may only be submitted for completed activities.

---

## 24. Disputes and Support

Users must be able to report:

* bicycle damage;
* missing bicycle;
* incorrect return;
* payment issue;
* failed delivery;
* unsafe bicycle;
* abusive user;
* GPS tracking issue.

A dispute must contain:

* category;
* description;
* related activity;
* photos or attachments;
* timeline;
* status;
* administrator notes.

Dispute statuses:

```text
open
under_review
awaiting_user
resolved
rejected
```

---

## 25. Administrator Panel

### 25.1 Main Modules

* Dashboard
* Users
* Identity Verification
* Bicycles
* GPS Trackers
* Rentals
* Delivery Tasks
* Payments
* Points
* Partners
* Offers
* Redemptions
* Alerts
* Disputes
* Configuration
* Audit Logs

### 25.2 Configurable Values

Administrators must be able to configure:

* points per kilometre;
* urgency multiplier;
* partial delivery rate;
* platform commission;
* maximum search radius;
* geofence tolerance;
* pickup and drop-off tolerance;
* location retention;
* supported GPS providers;
* reward expiration;
* cancellation rules.

---

## 26. Core Database Entities

### User

```text
id
email
password_hash
full_name
phone
profile_photo_url
verification_status
rating
created_at
updated_at
```

### IdentityVerification

```text
id
user_id
document_type
document_front_url
document_back_url
selfie_url
status
reviewed_by
reviewed_at
rejection_reason
```

### Bike

```text
id
owner_id
name
type
brand
model
color
frame_size
serial_number
year
description
estimated_value
status
created_at
updated_at
deleted_at
```

### BikePhoto

```text
id
bike_id
url
type
sort_order
```

### GPSDevice

```text
id
bike_id
provider
provider_device_id
connection_type
encrypted_credentials
battery_level
signal_strength
firmware_version
last_seen_at
status
```

### GPSPosition

```text
id
gps_device_id
location
altitude
accuracy
speed
heading
battery_level
recorded_at
received_at
```

### BikeAlert

```text
id
bike_id
type
severity
metadata
triggered_at
resolved_at
```

### BikeListing

```text
id
bike_id
hourly_price
daily_price
weekly_price
deposit_amount
instant_booking
delivery_available
published
cancellation_policy
```

### AvailabilitySlot

```text
id
bike_id
start_at
end_at
status
```

### Rental

```text
id
bike_id
owner_id
renter_id
start_at
end_at
pickup_location
return_location
rental_price
delivery_fee
service_fee
deposit_amount
status
created_at
```

### PaymentTransaction

```text
id
user_id
rental_id
provider
provider_transaction_id
type
amount
currency
status
created_at
```

### DeliveryTask

```text
id
bike_id
created_by
pickup_location
destination_location
pickup_from
pickup_until
delivery_deadline
estimated_distance
reward_points
reward_amount
priority
partial_allowed
status
```

### DeliverySegment

```text
id
delivery_task_id
courier_id
start_location
end_location
planned_distance
actual_distance
reward_points
status
started_at
completed_at
```

### UserLocation

```text
id
user_id
activity_type
activity_id
location
accuracy
speed
recorded_at
```

### PointsLedger

```text
id
user_id
transaction_type
amount
reference_type
reference_id
status
description
created_at
```

### Partner

```text
id
name
logo_url
description
status
```

### RewardOffer

```text
id
partner_id
title
description
points_cost
valid_from
valid_until
quantity
status
```

### RewardCode

```text
id
offer_id
code
assigned_user_id
assigned_at
used_at
status
```

### RewardRedemption

```text
id
user_id
offer_id
reward_code_id
points_spent
created_at
```

### Review

```text
id
author_id
recipient_id
rental_id
delivery_task_id
rating
text
status
created_at
```

### Dispute

```text
id
created_by
rental_id
delivery_task_id
category
description
status
assigned_admin_id
created_at
resolved_at
```

---

## 27. Backend Architecture

Recommended implementation:

* Python FastAPI backend;
* PostgreSQL;
* PostGIS;
* Redis for caching, temporary reservations and task queues;
* background workers using Celery, Dramatiq or equivalent;
* private S3-compatible object storage;
* WebSockets for live activity updates;
* Firebase Cloud Messaging and Apple Push Notification Service;
* Stripe or equivalent payment provider;
* Docker deployment.

### 27.1 Backend Modules

```text
auth
users
verification
bikes
gps
alerts
listings
search
rentals
payments
deliveries
routing
tracking
points
rewards
notifications
reviews
disputes
admin
audit
```

---

## 28. Frontend Architecture

Recommended implementation:

* Flutter for iOS and Android;
* state management using Riverpod, Bloc or equivalent;
* secure token storage;
* map SDK using Mapbox or Google Maps;
* QR scanner;
* camera and image upload;
* background location permissions;
* push notifications;
* deep links.

The application must separate:

* domain models;
* API clients;
* repositories;
* state management;
* UI screens;
* reusable components.

---

## 29. Security Requirements

* Passwords must be hashed using Argon2 or bcrypt.
* JWT access tokens must be short-lived.
* Refresh tokens must be revocable.
* Sensitive files must use private storage.
* GPS credentials must be encrypted.
* Exact bicycle locations must have role-based access control.
* All admin actions must be logged.
* All payment webhooks must be verified.
* Rate limiting must be applied to authentication and tracking endpoints.
* Device pairing must require ownership verification.
* Uploaded files must be validated and malware-scanned.
* Personally identifiable data must not appear in application logs.

---

## 30. Non-Functional Requirements

### Performance

* Normal API responses should complete within 500 ms where possible.
* Map search should return initial results within 2 seconds.
* Live location updates should appear within approximately 5–15 seconds depending on device capability.
* Search endpoints must support pagination.

### Reliability

* GPS webhook processing must be idempotent.
* Payment webhook processing must be idempotent.
* Points transactions must be immutable.
* Reservation creation must prevent double-booking.
* Delivery acceptance must prevent multiple couriers accepting the same active segment.

### Scalability

The system must support horizontal scaling of:

* API instances;
* background workers;
* notification workers;
* GPS ingestion services.

### Observability

The backend must include:

* structured logs;
* error tracking;
* metrics;
* request tracing;
* GPS ingestion monitoring;
* payment event monitoring;
* notification delivery status.

---

## 31. MVP Scope

The first public MVP should include:

### Included

* registration and login;
* profile;
* manual identity verification;
* bicycle registration;
* one generic GPS integration and one selected provider;
* bicycle map and location history;
* movement and offline alerts;
* rental listing;
* rental search;
* booking and payment;
* pickup and return confirmation;
* delivery task creation;
* full delivery;
* basic route matching;
* GPS validation;
* points ledger;
* partner offers;
* redemption codes;
* basic admin panel;
* push notifications.

### Deferred

* advanced automated identity verification;
* insurance integration;
* multiple GPS hardware providers;
* automatic demand prediction;
* dynamic reward pricing;
* complex relay optimization;
* police API integration;
* automated damage detection;
* subscriptions;
* corporate fleet management;
* loyalty levels and leaderboards.

---

## 32. Delivery Phases

### Phase 1 — Core Accounts and Bike Tracking

* authentication;
* profile;
* bicycle registration;
* GPS pairing;
* map;
* location history;
* security alerts;
* admin user and bicycle management.

### Phase 2 — Peer-to-Peer Rentals

* rental listings;
* search;
* availability;
* bookings;
* payments;
* deposits;
* pickup and return;
* ratings.

### Phase 3 — Delivery and Redistribution

* delivery tasks;
* courier mode;
* route matching;
* active tracking;
* proof of pickup and delivery;
* reward calculation.

### Phase 4 — Rewards and Relay Transport

* points ledger;
* partner offers;
* redemption;
* partial deliveries;
* relay segments;
* advanced matching and ranking.

---

## 33. Definition of Done

A feature is complete when:

* UI implementation matches approved designs;
* API contract is documented;
* validation and error states are implemented;
* authorization is enforced;
* automated tests are added;
* analytics events are added;
* audit logging is added where required;
* loading, empty and offline states are supported;
* accessibility requirements are met;
* QA acceptance criteria pass;
* production monitoring is configured;
* technical documentation is updated.
