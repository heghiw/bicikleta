# Implementation Gap Analysis

Assessed against [Technical Specification](./technical-specification.md) on 2026-07-20.

## Executive Summary

The repository is a working proof of concept, not yet the specified MVP. It implements basic JWT login, manual user verification, bicycle CRUD and search, simple rentals, delivery segments, points, rewards, reviews, a WebSocket location stream, a web SPA, and a Flutter client. The core end-to-end product shape is visible, but most production, security, payment, GPS-device, administration, and operational requirements remain.

Status meanings:

- **Implemented**: usable core flow exists.
- **Partial**: a simplified version exists, but material specification requirements are missing.
- **Missing**: no corresponding implementation was found.

## Coverage Matrix

| Specification area | Status | Current implementation | Missing or incompatible behavior |
|---|---|---|---|
| Authentication | Partial | Registration, bcrypt password hashing, login, JWT access token | Email verification, password confirmation, phone/terms fields, reset password, refresh tokens, revocation, logout/all devices, rate limiting; default production secret is unsafe |
| Identity verification | Partial | ID and selfie upload; admin approve endpoint; verified boolean | Required status workflow, rejection/resubmission, document metadata, private object storage, signed URLs, malware/type validation, audit history |
| Profile | Partial | Name, email, rating, points and verification flag | Phone, image, city, language, payment/payout state, complete verification status |
| Dashboard | Missing | Home screen composes some existing API data | `GET /api/v1/dashboard`, active activity, alerts, nearby tasks, prescribed error/offline states |
| Bicycle registration | Partial | Owner CRUD, multi-bike support, photos, type, pricing, coordinates | Model, color, serial uniqueness, year, value/ownership/insurance/battery fields, complete statuses, required photo before publish, soft delete, active-use deletion guard, audit log |
| GPS tracker integration | Missing | User GPS logs exist for active trips | Device/provider model, pairing/testing, callbacks, tracker status, bike position history, encrypted credentials, polling/MQTT/TCP adapters |
| Bicycle security | Missing | None found | Security modes, geofences, movement/offline/battery/tamper/speed/night/crash alerts, lost/stolen mode and police export |
| Explore and rental search | Partial | Radius/type/price search using in-process Haversine calculation | Required GET contract and filters, availability dates, map/search-area/saved items, pagination, ranking, approximate public location protection |
| Rental listings | Partial | Price fields live directly on `Bike` | Dedicated listing and availability models/APIs, publish lifecycle, weekly price, duration rules, instant/manual approval, delivery settings, cancellation policy |
| Rental booking lifecycle | Partial | Book, start, end, cancel and renter review | Quote, dates/availability lock, owner approval/reject, delivery choice, pickup/return evidence, confirm-return, disputes, full status model, double-booking-safe transaction |
| Payments and payouts | Missing | Rental price is calculated locally at completion | Payment provider, authorization/deposit, capture/refund, webhooks, fees/tax/discounts, owner/courier payouts, transaction history and idempotency |
| Delivery tasks | Partial | Owner-created jobs, radius search, accept/complete, simple relay segments and points | Full status workflow, time windows/deadlines/priority/handling, monetary rewards, filters, proof and confirmation, dispute/failure flows |
| Route matching and geospatial | Missing | Haversine radius/distance calculations on SQLite | PostgreSQL/PostGIS, route corridor matching, destination/detour input, geofence/proximity operations, route geometry and ranked compatibility |
| Partial/relay delivery | Partial | Relay completion reopens a task at the new pickup | Partial quote/proposal validation, explicit partial-allowed rule, handover evidence, sequential integrity, reward reservation and concurrency controls |
| Active tracking | Partial | Authenticated WebSocket accepts and persists courier/renter coordinates | Required HTTP/stream persistence endpoint, bicycle tracker feed, route/navigation/remaining distance, tracking indicator and stop/retention controls |
| Points ledger | Partial | Positive/negative transactions and balance calculation | Required transaction taxonomy, confirmation/reference/status fields, immutable enforcement, reversals, transactional/idempotent awarding |
| Partner rewards | Partial | Offer listing/admin CRUD, redemption and point deduction | Separate partner/code models, categories/terms/validity/history contract, unique code assignment, robust inventory locking and expiry |
| Activity | Partial | Separate rental and delivery lists | Unified activity feed, required categories/status filters and disputes |
| Notifications | Missing | None found | Push/in-app delivery, event coverage, preferences, delivery status and workers |
| Ratings and reviews | Partial | Renter can review a bike after a completed rental | Owner-to-renter and delivery reviews, recipient/moderation fields, admin moderation |
| Disputes and support | Missing | None found | Models, attachments/timeline/statuses, APIs and admin handling |
| Administrator panel | Partial | Verification and reward-offer admin endpoints | Admin UI and nearly all specified modules, configuration, alerts, disputes, payments, GPS management and audit logs |
| Backend architecture | Partial | FastAPI, SQLAlchemy, SQLite, Docker, WebSocket | API v1 convention, PostgreSQL/PostGIS, Redis, workers, object storage, migrations, service adapters, structured module coverage |
| Mobile/web UI | Partial | Flutter screens and a web SPA exist | Required five-tab navigation, many product flows/states, maps, QR/camera upload, background location, push/deep links, accessibility validation |
| Security | Partial | bcrypt, authenticated APIs, basic ownership checks | Private uploads (uploads are publicly mounted), encrypted secrets, short-lived plus refresh-token lifecycle, admin audit, webhook verification, rate limits, upload scanning, log redaction |
| Reliability/observability | Missing | Basic Python logging and tests | Idempotency, database concurrency guarantees, structured logs, metrics, tracing, error tracking and event monitoring |

## Contract Differences to Resolve

The current prototype and specification use different API contracts. These should be resolved before expanding either client:

- The specification uses `/api/v1/...`; the implementation uses `/api/...`.
- Bicycle search is specified as `GET /api/v1/bikes/search` with query parameters; the implementation uses `POST /api/bikes/search` with JSON.
- Delivery endpoints are specified under `/delivery-tasks`; the implementation uses `/delivery/jobs`.
- Rental completion is specified as return plus confirm-return; the implementation exposes a single `/end` action.
- Points and rewards paths differ from the specification (`/users/me/points`, `/shop/...`).
- The model/status vocabularies are substantially smaller than the specified enums.

## Immediate Technical Issues

1. ~~`requirements.txt` contains the invalid dependency name `httpx2`.~~ Resolved: pinned to `httpx==0.28.1`.
2. Uploaded identity documents, selfies, and bike photos are served by a public `/uploads` mount; identity files must be private.
3. The application falls back to a known JWT secret if configuration is absent.
4. SQLite and `create_all()` are used instead of PostgreSQL/PostGIS with versioned migrations.
5. Bicycle deletion is permanent and does not prevent deletion during an active rental or delivery.
6. Exact bicycle coordinates are returned from general bike/detail/search responses, conflicting with location privacy requirements.
7. Location updates validate activity at connection time but do not enforce retention, explicit tracking state, or continued authorization during the session.
8. Generated artifacts and runtime data (`__pycache__`, `.pyc`, and `bikeapp.db`) are committed to source control.

## Recommended Implementation Order

### P0 — Stabilize the foundation

- Choose and document the v1 API contract, then align backend, web, Flutter, and tests.
- Add PostgreSQL/PostGIS and migrations; remove committed runtime artifacts.
- Implement production configuration validation and private object storage.
- Expand identity verification and authorization policies.
- Add transactional availability locking and protect exact locations.

### P1 — Complete the rental MVP

- Add listing/availability models and publishing rules.
- Implement quotes, owner approval, pickup/return evidence, and full rental statuses.
- Integrate payment authorization, capture, deposits, refunds, payouts, and verified webhooks.
- Add unified activity, notifications, disputes, and complete review flows.

### P2 — Complete tracking and redistribution

- Build the GPS provider abstraction, pairing, ingestion, location history, and security alerts.
- Implement PostGIS search, route matching, delivery windows, validation evidence, and concurrency-safe acceptance.
- Complete partial-delivery quotes, relay rules, and immutable referenced points transactions.

### P3 — Operations and release readiness

- Build the administrator panel and configuration/audit modules.
- Add push notifications, background workers, observability, retention jobs, rate limiting, and webhook idempotency.
- Cover loading, empty, offline, accessibility, analytics, and monitoring requirements.

## UI Mock Review

Source reviewed: repository-root `project.zip`, a React 19/Vite/Tailwind mock primarily implemented in `src/App.tsx`.

### What the mock covers well

- It exactly matches the required five-tab navigation: Home, Explore, My Bikes, Activity, and Profile.
- Home includes location, profile/notification controls, points, quick actions, a bicycle alert, an active rental, nearby bicycles, and delivery tasks.
- Explore provides Rental and Delivery modes, a map/list-style bottom sheet, search, filters, markers, distance, price/reward, urgency, rating, and GPS badges.
- My Bikes shows multiple bicycles, rental status, GPS state, battery, last location, a tracker map, security controls, lost-mode affordances, rental settings, and an add-bike action.
- Activity represents rental, delivery, reward, completed, active, and cancelled records with filters.
- Profile includes verification, earnings, statistics, payment, identity, notification, privacy, support, and logout affordances.
- The color system consistently distinguishes rental, delivery, rewards, warnings, and destructive actions.

### Missing screens and journeys

- Registration, login, email verification, password reset, and identity upload/status flows.
- Full bicycle add/edit wizard, photo/proof uploads, tracker-provider selection, pairing, activation, and test-location confirmation.
- Rental detail, calendar, quote/checkout, payment/deposit, owner approval, pickup evidence, active navigation, return evidence, return approval, review, cancellation, and dispute flows.
- Delivery task detail, route matching input/results, acceptance confirmation, pickup proof, active navigation, full/partial completion, relay handover, and failure/dispute flows.
- Rewards offer list/detail, category filters, redemption confirmation/code, and redemption history.
- Notifications list/preferences, support/dispute creation, payment/payout management, and all administrator screens.
- Loading, skeleton, empty, permission-denied, GPS-unavailable, verification-pending, network-error, offline, and destructive-action confirmation states.
- Explicit live-tracking indicator, location-consent controls, approximate-versus-exact location treatment, and location-retention information.

### Prototype limitations to resolve before integration

1. `index.html`, `src/main.tsx`, and `tsconfig.json` are zero-byte files, so the archive is not a runnable Vite application as delivered.
2. All displayed data is hard-coded; there is no API client, authentication state, routing, persistence, form submission, or backend integration.
3. Only tab switching, Explore mode/sheet switching, activity filters, bicycle selection, and a GPS subview have behavior. Most buttons and settings rows are visual only.
4. The mock is fixed inside a 390 × 844 desktop phone frame and needs responsive mobile layouts, safe areas, keyboard handling, and native interaction patterns for Flutter.
5. Accessibility semantics are largely absent: icon buttons lack accessible names, controls lack form labels, focus/keyboard states are unspecified, and color contrast/touch targets need validation.
6. Several strings in `App.tsx` contain mojibake (for example corrupted euro symbols, arrows, emoji, and German characters) and must be normalized to UTF-8.
7. Images and fonts depend on remote Unsplash/Google resources and need an asset, caching, privacy, and offline strategy.
8. The mock includes gamification concepts such as Gold/Platinum membership, streaks, and a leaderboard direction that the specification explicitly defers or does not define. Treat these as optional, not MVP requirements.

### Recommended integration approach

Use the mock as the approved visual reference, not as application architecture. Reproduce its design system and five-tab structure in the existing Flutter client, then implement each journey against the stabilized `/api/v1` contract. Build shared tokens/components first, add explicit UI state variants, and keep mock-only gamification out of the MVP unless it is separately approved.

## Production Progress

Started 2026-07-20:

- Added the mock-aligned five-tab Flutter shell.
- Added live-data Home dashboard, My Bikes, and unified Activity screens.
- Added build-time `API_BASE_URL` configuration and moved the mobile client to `/api/v1`.
- Migrated access-token persistence to Android Keystore/iOS Keychain-backed secure storage.
- Added backward-compatible backend routing for both `/api/v1` and legacy `/api` clients.
- Added Flutter platform-generation and Android/iOS release instructions.
- Added repository ignores for secrets, runtime databases, uploads, Python caches, and Flutter build output.
- Added a four-step Flutter bicycle registration journey with required photo upload and rental pricing.
- Added generic tracker registration/status APIs and a Flutter pairing screen; devices remain pending until a real provider adapter validates them.
- Restricted public uploads to bicycle photos and placed identity document/selfie access behind owner/admin authorization.
- Added upload type and 10 MB size validation for verification files and bicycle photos.
- Added password confirmation and Terms/Privacy acceptance to mobile registration.
