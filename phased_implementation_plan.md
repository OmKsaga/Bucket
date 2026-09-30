# Bucket — Phased Implementation Plan

> **Repo:** [github.com/OmKsaga/Bucket](https://github.com/OmKsaga/Bucket)
> Each phase ends with a **GitHub push** and a working, demonstrable build.

---

## Overview

| Phase | Name | Est. Days | Key Deliverable |
|-------|------|-----------|-----------------|
| 0 | Project Foundation & UX | 3–4 | Figma prototype + project scaffold |
| 1 | Local Core — Data Layer | 5–7 | Database, models, allocation engine |
| 2 | Local Core — UI Layer | 5–7 | Full offline UI (home, buckets, ledger) |
| 3 | Reconciliation Engine | 5–6 | Balance sync, external spend detection |
| 4 | Payments & Backend | 6–8 | Mock UPI, FastAPI backend, auth |
| 5 | Analytics, Notifications & Security | 5–6 | Goal analytics, push notifs, biometric lock |

**Total estimated effort: ~29–38 days**

Each phase is sized to represent roughly the same amount of meaningful, shippable work.

---

## Phase 0 — Project Foundation & UX

**Estimated: 3–4 days**

### Goal
Establish all foundational decisions before writing production code. End with a Figma prototype and a live, empty repo scaffold.

### Tasks

#### Product & Design
- [x] Finalize product name ("Bucket")
- [x] Define 5 core user journeys (create bucket, manual sync, pay with warning, reallocation, goal complete)
- [x] Design UX specifications and screen wireframes for all journeys (`docs/ux_journeys_and_screens.md`)
- [x] Finalize bucket rules: priority model, NEED/WANT logic, protected bucket behavior (`docs/bucket_rules_and_edge_cases.md`)
- [x] Define sync/reconciliation UX behavior
- [x] Define edge cases: zero-balance bucket, overspend, refund, duplicate sync

#### Project Scaffold
- [x] Initialize Flutter project with feature-based folder structure
- [x] Initialize FastAPI backend project with folder structure, Docker, and health check test
- [x] Create `README.md` with product description and setup instructions
- [x] Create `.gitignore` for Flutter + Python
- [x] Set up `pubspec.yaml` with initial dependencies:
  - `drift`, `drift_flutter` — SQLite ORM
  - `flutter_secure_storage` — secure key storage
  - `riverpod` — state management
  - `go_router` — navigation
  - `intl` — currency formatting

#### GitHub
- [x] Push scaffold to `main` branch
- [x] Create branch strategy: `main` (stable) → `dev` → `phase/N` branches
- [x] Tag release `v0.0.1`

### Deliverable
> **UX & Architecture Specs** + pushed repo scaffold (`v0.0.1`) [COMPLETED]

---

## Phase 1 — Local Core: Data Layer

**Estimated: 5–7 days**

### Goal
Build the complete local data layer: database schema, domain models, and the allocation/ledger engine. No UI yet — this phase is pure business logic, fully tested.

### Tasks

#### Domain Models (`lib/domain/models/`)
- [ ] `Account` — bank account metadata, last known balance, last sync timestamp
- [ ] `Bucket` — name, icon, target amount, current allocation, deadline, category, need/want, priority, protected flag, notes
- [ ] `LedgerEntry` — bucket_id, amount_delta, transaction_type, timestamp, note
- [ ] `SyncSession` — session_id, previous_balance, current_balance, difference, status, timestamp
- [ ] `AppSettings` — theme, biometric lock enabled, auto-allocation rules (future)

#### Database (Drift/SQLite)
- [ ] Define all Drift table classes matching domain models
- [ ] Write and run migrations
- [ ] Implement DAOs (Data Access Objects) for each table:
  - `BucketDao` — CRUD + priority-ordered queries
  - `LedgerDao` — append-only inserts, query by bucket/date
  - `AccountDao` — get/update balance
  - `SyncSessionDao` — insert sessions, query history

#### Allocation Engine (`lib/domain/engines/`)
- [ ] `AllocationEngine`:
  - Compute current bucket balance from ledger (derived, not stored)
  - `allocate(bucketId, amount)` — writes `INITIAL_ALLOCATION` or `MANUAL_ADD` ledger entry
  - `deallocate(bucketId, amount)` — writes `MANUAL_REMOVE`
  - `reallocate(fromBucketId, toBucketId, amount)` — writes `REALLOCATION` pair
  - Enforce: total allocations <= account balance
- [ ] `ExternalSpendEngine` (core reconciliation logic, used in Phase 3 with real data):
  - Input: `spendAmount`, sorted bucket list (priority ASC, protected excluded)
  - Apply deductions lowest-priority first
  - Handle multi-bucket overflow
  - Return list of `LedgerEntry` objects to commit
  - Write `EXTERNAL_SPEND_IMPACT` entries
- [ ] `IncomingMoneyEngine`:
  - Input: `incomeDelta`
  - Do not auto-allocate; return unallocated amount
  - Write `INCOME_DETECTED` entry

#### Goal Analytics Engine (`lib/domain/engines/`)
- [ ] `GoalAnalyticsEngine`:
  - Amount saved, remaining, % complete
  - Days remaining to deadline
  - Required daily / weekly / monthly contribution
  - Projected completion date based on current contribution rate

#### Testing
- [ ] Unit tests for `AllocationEngine` — all ledger operations
- [ ] Unit tests for `ExternalSpendEngine`:
  - Single bucket spend
  - Multi-bucket overflow
  - Protected bucket skip
  - Zero remaining bucket skip
- [ ] Unit tests for `GoalAnalyticsEngine`
- [ ] Unit tests for `IncomingMoneyEngine`

### Deliverable
> **Fully tested data & engine layer** — `flutter test` passes green

---

## Phase 2 — Local Core: UI Layer

**Estimated: 5–7 days**

### Goal
Build the complete offline Flutter UI wired to the Phase 1 data layer. The app should be fully usable as a standalone offline tool by the end of this phase.

### Tasks

#### Core UI Setup
- [ ] Design system: color tokens, typography (Google Fonts — `Outfit` or `Inter`), spacing constants
- [ ] `AppTheme` — light + dark theme
- [ ] `GoRouter` route table — all named routes defined

#### Home Screen (`lib/features/home/`)
- [ ] Display: total balance, allocated amount, spendable/unallocated amount
- [ ] Quick action buttons: **Scan & Pay**, **Send Money** (both mock for now)
- [ ] Recent transactions list (from ledger, last 10 entries)
- [ ] Balance card with animated number transitions

#### Buckets Screen (`lib/features/allocations/`)
- [ ] List all buckets sorted by priority
- [ ] Each bucket card: name, icon, allocated / target, % progress bar, deadline, NEED/WANT badge, protected badge
- [ ] Create Bucket flow (bottom sheet / full screen):
  - Name, icon picker, target amount, deadline date picker, category, NEED/WANT, priority slider, protected toggle, notes
- [ ] Edit Bucket — same form, pre-filled
- [ ] Delete Bucket — with confirmation + ledger impact warning
- [ ] Sync status bar: "Last synced: —" + **Sync Now** button (stubbed for now)

#### Bucket Detail Screen
- [ ] All bucket fields displayed
- [ ] Goal analytics card (from `GoalAnalyticsEngine`)
- [ ] **Add Allocation** — add funds to this bucket
- [ ] **Remove Allocation** — withdraw from this bucket
- [ ] **Reallocate** — move funds to another bucket (picker + amount)
- [ ] Ledger history for this bucket

#### Ledger / Transaction History Screen (`lib/features/goals/`)
- [ ] Full chronological ledger list
- [ ] Filter by: bucket, transaction type, date range
- [ ] Each entry: type icon, bucket name, amount delta, timestamp, note

#### Manual Sync Simulation Screen
- [ ] Input: "Enter current balance" (simulates what sync will do in Phase 3)
- [ ] Shows diff, runs `ExternalSpendEngine` or `IncomingMoneyEngine`
- [ ] Shows sync result UI matching the spec:
  - "External spending detected: ₹X — allocated to: [Bucket]"
  - "₹X new money detected — [ Allocate ] [ Keep Unallocated ]"

#### State Management
- [ ] Riverpod (or Bloc) providers for: account state, bucket list, ledger stream, sync state
- [ ] Reactive UI — bucket list updates instantly on allocation change

### Deliverable
> **Fully functional offline app** — all screens, navigable, data persists

---

## Phase 3 — Reconciliation Engine

**Estimated: 5–6 days**

### Goal
Replace the manual balance input with real balance synchronization via a UPI/bank provider SDK or API. Implement the complete sync pipeline and its UX.

### Tasks

#### Sync Service (`lib/core/networking/`)
- [ ] Abstract `BalanceSyncProvider` interface:
  - `fetchCurrentBalance()` returns `Future<BalanceSyncResult>`
  - `fetchRecentTransactions(since: DateTime)` returns `Future<List<ExternalTransaction>>`
- [ ] Implement `MockSyncProvider` — returns configurable balance + transaction list for testing
- [ ] Implement `RealSyncProvider` (wire to actual PSP SDK)

#### Reconciliation Service (`lib/domain/services/`)
- [ ] `ReconciliationService.runSync()`:
  1. Fetch current balance from provider
  2. Load last known balance from `AccountDao`
  3. Compute difference
  4. Classify: external spend / income / refund / neutral
  5. Run appropriate engine (`ExternalSpendEngine` / `IncomingMoneyEngine`)
  6. Commit all ledger entries atomically
  7. Update `AccountDao` with new balance + sync timestamp
  8. Save `SyncSession` record
  9. Return `SyncResult` for UI
- [ ] Idempotency: same `SyncSession` cannot be committed twice (check session hash)
- [ ] Handle offline gracefully — show last known state

#### UPI/Bank Provider Integration
- [ ] Research and select provider: **Setu**, **Razorpay UPI**, **PhonePe SDK**, or **Juspay**
- [ ] Integrate provider sandbox SDK
- [ ] Implement `RealSyncProvider` using provider's transaction history API
- [ ] Handle auth flow (provider-specific — likely OAuth or token)
- [ ] Store provider auth token in `flutter_secure_storage`

#### Sync UX (polish Phase 2 screens)
- [ ] Live sync status: "Checking account... → Comparing balance... → Updating allocations..."
- [ ] Sync result card:
  - External spend: which buckets were impacted, by how much
  - Income: "₹X received — Allocate now?" prompt
  - No change: "All up to date"
- [ ] Sync history list (all `SyncSession` records)
- [ ] Error states: network error, provider error, auth expired

#### Payment Warning System
- [ ] `PaymentWarningService.evaluate(amount)`:
  - Compare against unallocated balance
  - If amount <= spendable — green confirmation
  - If amount > spendable — warning with impact preview (which bucket will be hit)
- [ ] Integrate into **Scan & Pay** and **Send Money** flows

#### Testing
- [ ] Integration test: full sync cycle with `MockSyncProvider`
- [ ] Test idempotency: double-sync produces no duplicate ledger entries
- [ ] Test all transaction classifications
- [ ] Test offline mode — app remains functional

### Deliverable
> **Live balance sync** with reconciliation — real or sandbox provider connected

---

## Phase 4 — Payments & Backend

**Estimated: 6–8 days**

### Goal
Build the FastAPI backend (auth, device registration, optional backup) and complete the UPI payment initiation flow in the app.

### Tasks

#### FastAPI Backend (`backend/`)
- [ ] Project setup: `FastAPI`, `SQLAlchemy`, `Alembic`, `Pydantic v2`, `python-jose` (JWT), `passlib`
- [ ] PostgreSQL schema (Alembic migrations):
  - `users` — id, email, created_at, device_count
  - `devices` — id, user_id, device_token, platform, registered_at
  - `sync_sessions` — id, user_id, device_id, session_hash, created_at (metadata only, no financial data)
  - `payment_references` — id, user_id, provider_ref, amount, status, created_at
  - `encrypted_backups` — id, user_id, ciphertext, iv, created_at (optional feature)
  - `app_settings` — id, user_id, key, value
- [ ] Auth endpoints:
  - `POST /auth/register` — create user + issue JWT
  - `POST /auth/login` — verify + issue JWT
  - `POST /auth/refresh` — rotate JWT
  - `POST /auth/device` — register device push token
- [ ] User endpoints:
  - `GET /users/me` — profile
  - `DELETE /users/me` — account deletion
- [ ] Sync metadata endpoint:
  - `POST /sync/session` — record session hash (for cross-device dedup, no financial data)
- [ ] Payment reference endpoints:
  - `POST /payments/initiate` — initiate UPI payment via provider
  - `GET /payments/{ref}/status` — poll payment status

#### AWS Deployment (basic)
- [ ] Dockerfile for FastAPI
- [ ] `docker-compose.yml` for local dev (FastAPI + PostgreSQL)
- [ ] ECS task definition or Lambda config (basic, not production-hardened yet)
- [ ] AWS Secrets Manager for DB credentials + JWT secret
- [ ] API Gateway routing

#### Flutter — Auth Integration
- [ ] Auth screens: **Sign Up**, **Log In**, **Forgot Password** (basic)
- [ ] JWT storage in `flutter_secure_storage`
- [ ] `AuthService` — register, login, refresh, logout
- [ ] Attach JWT to all backend API calls

#### Flutter — UPI Payment Flow
- [ ] **Scan QR** screen — use device camera + QR decoder package
- [ ] **Send Money** screen — enter UPI ID / phone / amount
- [ ] Pre-payment: run `PaymentWarningService.evaluate(amount)` — show warning/confirmation
- [ ] Post-payment: record `payment_reference_id` locally; trigger background sync after 30s
- [ ] Payment history screen (from ledger + provider references)

#### Security Baseline
- [ ] TLS enforced on all backend routes
- [ ] JWT expiry + refresh rotation
- [ ] API rate limiting (FastAPI middleware)
- [ ] Input validation (Pydantic) on all endpoints
- [ ] No financial amounts logged server-side

### Deliverable
> **End-to-end payment flow** + live backend + auth

---

## Phase 5 — Analytics, Notifications & Security Polish

**Estimated: 5–6 days**

### Goal
Complete the user-facing experience: rich goal analytics, push notifications, biometric lock, and a security/stability pass before beta.

### Tasks

#### Goal Analytics Screen (`lib/features/analytics/`)
- [ ] Per-bucket analytics card:
  - Progress ring / bar
  - Amount saved, remaining, % complete
  - Days left to deadline
  - Required daily / weekly / monthly contribution
  - Projected completion date
  - Historical contribution chart (last 30 days)
- [ ] App-wide analytics:
  - Total allocated vs unallocated
  - Savings rate (allocated gains per month)
  - External spend frequency / average
  - NEED vs WANT allocation split

#### Push Notifications
- [ ] Integrate **Firebase Cloud Messaging (FCM)**
- [ ] Register device token with backend (`POST /auth/device`)
- [ ] Server-side notification triggers (FastAPI background tasks):
  - Sync complete — external spend detected
  - Goal milestone: 25%, 50%, 75%, 100% complete
  - Goal deadline approaching (7 days, 1 day)
  - Incoming money detected (prompt to allocate)
- [ ] On-device local notifications:
  - Reminder to sync if last sync > 24h
  - Payment warning follow-up after transaction

#### Biometric Lock
- [ ] Integrate `local_auth` package
- [ ] Lock app on background (configurable timeout: 30s / 1min / 5min / never)
- [ ] Biometric unlock screen
- [ ] Fallback: PIN / device passcode
- [ ] Setting to enable/disable in **Settings** screen

#### Settings Screen (`lib/features/settings/`)
- [ ] Biometric lock toggle + timeout
- [ ] Theme: light / dark / system
- [ ] Sync frequency preference
- [ ] Account management (logout, delete account)
- [ ] About / version / privacy policy

#### Security & Stability Pass
- [ ] Review all local SQLite fields — encrypt sensitive columns where appropriate
- [ ] Audit logs: no balance/amount values in `debugPrint` or Crashlytics
- [ ] Review `flutter_secure_storage` usage — confirm all secrets are stored correctly
- [ ] API security review: rate limits, JWT validation, no leaked stack traces
- [ ] Crash handling: integrate **Firebase Crashlytics**
- [ ] Test on 3+ Android devices, 1+ iOS device
- [ ] Fix all high-severity bugs

#### Beta Prep
- [ ] Build release APK / TestFlight build
- [ ] Write beta onboarding guide (what to test, how to give feedback)
- [ ] Recruit 20–50 beta users
- [ ] Set up feedback channel (GitHub Discussions / Discord / Google Form)

### Deliverable
> **Beta-ready build** — pushed to TestFlight / Google Play Internal Testing

---

## GitHub Branching & Push Strategy

```
main                    <- stable, one commit per phase
  +-- dev               <- integration branch
        +-- phase/0     <- Phase 0 work
        +-- phase/1     <- Phase 1 work
        +-- phase/2     <- Phase 2 work
        +-- phase/3     <- Phase 3 work
        +-- phase/4     <- Phase 4 work
        +-- phase/5     <- Phase 5 work
```

**Push protocol per phase:**
1. All work done on `phase/N` branch
2. Merge `phase/N` → `dev` → review
3. Merge `dev` → `main` with a version tag: `v0.N.0`
4. Write a GitHub Release note summarising what was shipped

---

## Work Balance Summary

| Phase | Primary Concerns | Approx. Task Count |
|-------|-----------------|-------------------|
| 0 | Design, decisions, scaffold | ~12 tasks |
| 1 | Models, DB, engines, unit tests | ~18 tasks |
| 2 | All Flutter UI screens, state mgmt | ~20 tasks |
| 3 | Sync pipeline, PSP integration, UX | ~18 tasks |
| 4 | Backend, auth, payments, AWS | ~20 tasks |
| 5 | Analytics, notifications, security, beta | ~16 tasks |

Each phase is designed to take **a roughly equal developer-week** of focused work.
Phases 1–2 and 3–4 can be parallelised if there is more than one developer.

---

## Key Constraints to Keep in Mind

**No financial data to the backend.**
Bucket balances, ledger entries, and allocation history live on-device only.
The backend only sees metadata (user ID, session hashes, payment references).

**UPI production requires regulatory approval.**
All Phase 3–4 UPI work uses a sandbox.
Do not attempt production UPI without appropriate NPCI/PSP arrangements.

**The allocation engine must be idempotent.**
Running the same sync twice must never double-deduct.
Session hashing enforces this at the service layer.
