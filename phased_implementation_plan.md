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
- [x] `Account` — bank account metadata, last known balance, last sync timestamp
- [x] `Bucket` — name, icon, target amount, current allocation, deadline, category, need/want, priority, protected flag, notes
- [x] `LedgerEntry` — bucket_id, amount_delta, transaction_type, timestamp, note
- [x] `SyncSession` — session_id, previous_balance, current_balance, difference, status, timestamp
- [x] `AppSettings` — theme, biometric lock enabled, auto-allocation rules (future)

#### Database (Drift/SQLite & Repositories)
- [x] Define all Drift table classes matching domain models (`AccountsTable`, `BucketsTable`, `LedgerEntriesTable`, `SyncSessionsTable`, `AppSettingsTable`)
- [x] Define `AppDatabase` schema
- [x] Implement Repository interfaces (`IBucketRepository`, `ILedgerRepository`, `IAccountRepository`, `ISyncSessionRepository`, `ISettingsRepository`)
- [x] Implement in-memory reactive data layer (`InMemoryRepositories`) with Streams and derived ledger calculations

#### Allocation Engine (`lib/domain/engines/`)
- [x] `AllocationEngine`:
  - Compute current bucket balance from ledger (derived, not stored)
  - `allocate(bucket, amount)` — writes `INITIAL_ALLOCATION` or `MANUAL_ADD` ledger entry
  - `deallocate(bucket, amount)` — writes `MANUAL_REMOVE`
  - `reallocate(fromBucket, toBucket, amount)` — writes `REALLOCATION` pair
  - Enforce invariants: total allocations <= spendable balance
- [x] `ExternalSpendEngine` (core reconciliation waterfall deduction logic):
  - Input: `spendAmount`, sorted bucket list (WANT before NEED, priority ASC, protected excluded)
  - Apply deductions lowest-priority first
  - Handle multi-bucket overflow
  - Return list of `BucketImpact` and `LedgerEntry` objects to commit
  - Write `EXTERNAL_SPEND_IMPACT` entries
  - Preserves protected buckets strictly and reports deficit
- [x] `IncomingMoneyEngine`:
  - Input: `incomeDelta`, current unallocated balance
  - Return unallocated amount and write `INCOME_DETECTED` entry

#### Goal Analytics Engine (`lib/domain/engines/`)
- [x] `GoalAnalyticsEngine`:
  - Amount saved, remaining, % complete
  - Days remaining to deadline
  - Required daily / weekly / monthly contribution
  - Projected completion date based on historical ledger contribution rate
  - Overdue and goal completion detection

#### Testing
- [x] Unit tests for `AllocationEngine` — all ledger operations (`allocation_engine_test.dart`)
- [x] Unit tests for `ExternalSpendEngine` (`external_spend_engine_test.dart`):
  - Single bucket spend
  - Multi-bucket overflow
  - Protected bucket skip
  - Zero remaining bucket skip
  - WANT before NEED prioritization
- [x] Unit tests for `GoalAnalyticsEngine` (`goal_analytics_engine_test.dart`)
- [x] Unit tests for `IncomingMoneyEngine` (`incoming_money_engine_test.dart`)
- [x] Unit tests for Repository layer (`in_memory_repository_test.dart`)
- [x] Verification test suite (`backend/tests/test_domain_engines.py`) passing 100%

### Deliverable
> **Fully tested data & engine layer** (`v0.1.0`) [COMPLETED]

---

## Phase 2 — Local Core: UI Layer

**Estimated: 5–7 days**

### Goal
Build the complete offline Flutter UI wired to the Phase 1 data layer. The app should be fully usable as a standalone offline tool by the end of this phase.

### Tasks

#### Core UI Setup
- [x] Design system: color tokens, priority color palettes, spacing constants
- [x] `AppTheme` — light + dark theme with custom cards, badges, and buttons
- [x] `GoRouter` route table — all named routes defined (`AppRouter`)

#### Home Screen (`lib/features/home/`)
- [x] Display: total bank balance, committed goal allocation, spendable/unallocated balance with deficit warning
- [x] Quick action buttons: **Scan & Pay**, **Send Money** (with pre-payment warning & lowest-priority impact preview)
- [x] Recent transactions audit list from ledger
- [x] Priority goals spotlight carousel

#### Buckets Screen (`lib/features/allocations/`)
- [x] List all buckets sorted by priority (1 to 5)
- [x] Filter chips: All, Needs, Wants, Completed
- [x] Each bucket card: name, icon, allocated / target, progress bar, deadline, NEED/WANT badge, protected badge
- [x] Create Bucket flow (bottom sheet):
  - Name, icon picker, target amount, initial allocation, category, NEED/WANT, priority slider (1-5), protected toggle, deadline picker, notes
- [x] Edit Bucket — pre-filled form with live updates
- [x] Delete Bucket — with confirmation dialog and refund to spendable pool
- [x] Quick inline reallocation CTA on each card

#### Bucket Detail Screen
- [x] All bucket fields and priority badges displayed
- [x] Goal analytics card (from `GoalAnalyticsEngine`): days remaining, required daily/weekly/monthly contributions
- [x] **Add Allocation** dialog with quick chips (+₹500, +₹1,000, +₹2,000, +₹5,000)
- [x] **Remove Allocation** dialog
- [x] **Reallocate** dialog with visual transfer arrow and zero-bank-impact reassurance
- [x] Isolated chronological ledger history for the selected goal

#### Ledger / Transaction History Screen (`lib/features/goals/`)
- [x] Full chronological ledger list
- [x] Filter chips: All, External Spend, Reallocations, Income, Manual Adds
- [x] Each entry: type icon, bucket name, amount delta (+/-), timestamp, balance after snapshot

#### Manual Sync Simulation Screen (`lib/features/home/`)
- [x] Bank balance input & quick presets (-₹6,000 Grocery, -₹10,000 Multi-goal overflow, +₹15,000 Salary)
- [x] Live difference calculation and classification
- [x] Executes `ExternalSpendEngine` waterfall deduction or `IncomingMoneyEngine`
- [x] Animated sync results card showing affected buckets (before → after) and preserved protected goals

#### State Management
- [x] Riverpod `walletProvider` managing account, buckets, audit ledger, and waterfall results
- [x] Reactive UI — all balances and cards update immediately on any mutation

### Deliverable
> **Fully functional offline app** (`v0.2.0`) [COMPLETED]

---

## Phase 3 — Reconciliation Engine

**Estimated: 5–6 days**

### Goal
Replace the manual balance input with real balance synchronization via a UPI/bank provider SDK or API. Implement the complete sync pipeline and its UX.

### Tasks

#### Sync Service (`lib/core/networking/`)
- [x] Abstract `BalanceSyncProvider` interface (`IBalanceSyncProvider` with `fetchCurrentBalanceAndTransactions` and `authenticate`)
- [x] Implement `MockSyncProvider` — returns configurable balance, external spends, incoming salary, refunds, and latency/offline simulation
- [x] Implement `SandboxSyncProvider` (wires to Setu/Account Aggregator/PSP sandbox standard format)

#### Reconciliation Service (`lib/domain/services/`)
- [x] `ReconciliationService.runSync()`:
  1. Fetch current balance from provider
  2. Load last known balance from `AccountRepository`
  3. Compute difference
  4. Classify: external spend / income / refund / neutral / offline failure
  5. Run appropriate engine (`ExternalSpendEngine` / `IncomingMoneyEngine`)
  6. Commit all ledger entries atomically
  7. Update `AccountRepository` with new balance + sync timestamp
  8. Save `SyncSession` record
  9. Return rich `SyncOutcome` for UI
- [x] Idempotency: same `SyncSession` cannot be committed twice (SHA-256 session hash with 10s quantization window)
- [x] Handle offline gracefully — preserve local state and report failure without crashing

#### UPI/Bank Provider Integration
- [x] Selected and modeled **Setu Account Aggregator / UPI Sandbox** architecture
- [x] Integrated `SandboxSyncProvider` for sandbox statements and balance retrieval
- [x] Implemented token caching in `flutter_secure_storage` (Keystore/Keychain)

#### Sync UX (polish Phase 2 screens)
- [x] Live sync status with 4-step progress animation ("Contacting bank... → Comparing balance... → Checking transactions... → Running waterfall deduction...")
- [x] Sync outcome card displaying affected goals (before → after), deducted amounts, and session hash
- [x] Error states and offline notification handling

#### Payment Warning System
- [x] `PaymentWarningService.evaluate(amount)`:
  - Compares against unallocated spendable balance
  - If amount <= spendable — green safe confirmation
  - If amount > spendable — warning with impact preview predicting which lowest-priority goals will be deducted
  - Critical deficit warning if payment exceeds spendable balance + all unprotected goals
- [x] Integrated into **Scan & Pay** and **Send Money** flows (`PaymentSheet`)

#### Testing
- [x] Integration test: full sync cycle with `MockSyncProvider` (`reconciliation_service_test.dart`)
- [x] Test idempotency: double-sync produces no duplicate ledger entries
- [x] Test all transaction classifications (no change, external spend, income, refund, offline)
- [x] Test offline mode — app remains functional without balance corruption
- [x] Unit tests for `PaymentWarningService` (`payment_warning_service_test.dart`)
- [x] Python verification suite (`test_reconciliation_pipeline.py`) passing 100%

### Deliverable
> **Live balance sync** with reconciliation pipeline (`v0.3.0`) [COMPLETED]

---

## Phase 4 — Payments & Backend

**Estimated: 6–8 days**

### Goal
Build the FastAPI backend (auth, device registration, optional backup) and complete the UPI payment initiation flow in the app.

### Tasks

#### FastAPI Backend (`backend/`)
- [x] Project setup: `FastAPI`, `SQLAlchemy`, `Pydantic v2`, `bcrypt`, JWT (RFC 7519 HMAC-SHA256)
- [x] Database schema:
  - `users` — id, email, hashed_password, is_active, created_at, updated_at
  - `devices` — id, user_id, device_token, platform, registered_at, last_seen_at
  - `sync_sessions` — id, user_id, device_id, session_hash, sync_count, created_at (metadata only, no financial data)
  - `payment_references` — id, user_id, provider_ref, payee_vpa, payee_name, amount_paise, status, upi_intent_url
  - `encrypted_backups` — id, user_id, ciphertext, iv, key_version, created_at (zero-knowledge client encryption)
  - `app_settings` — id, user_id, key, value, updated_at
- [x] Auth endpoints:
  - `POST /auth/register` — create user + issue JWT
  - `POST /auth/login` — verify + issue JWT
  - `POST /auth/refresh` — rotate JWT
  - `POST /auth/device` — register device push token
- [x] User endpoints:
  - `GET /users/me` — profile with device count
  - `DELETE /users/me` — account deletion
- [x] Sync metadata endpoint:
  - `POST /sync/session` — record session hash (cross-device dedup, zero financial data)
- [x] Payment reference endpoints:
  - `POST /payments/initiate` — initiate UPI payment via NPCI intent URI
  - `GET /payments/{ref}/status` — poll payment status
  - `POST /payments/{ref}/settle` — test harness / settlement update

#### AWS Deployment (basic)
- [x] Dockerfile for FastAPI
- [x] `docker-compose.yml` for local dev (FastAPI + PostgreSQL)
- [x] ECS task definition (`aws/ecs-task-definition.json`)
- [x] AWS Secrets Manager configuration for DB credentials + JWT secret
- [x] Cloud deployment instructions (`aws/deploy-instructions.md`)

#### Flutter — Auth Integration
- [x] Auth screens: **Sign Up**, **Sign In** (`features/auth/presentation/auth_screen.dart`)
- [x] JWT storage in `flutter_secure_storage` with memory fallback
- [x] `AuthService` & `ApiClient` — register, login, refresh, logout
- [x] Attach JWT Bearer token to all backend API calls with auto-refresh on 401

#### Flutter — UPI Payment Flow
- [x] **Scan QR** screen (`features/payments/presentation/qr_scanner_screen.dart`) — animated laser viewfinder, NPCI UPI parser, simulation presets, gallery/manual VPA input
- [x] **Send Money** flow — integrated with `PaymentSheet`
- [x] Pre-payment: run `PaymentWarningService.evaluate(amount)` — show warning/confirmation
- [x] Post-payment: record `payment_reference_id` locally; trigger background sync after 30s
- [x] Integrated `UpiPaymentService` into payment action button

#### Security Baseline
- [x] TLS enforced on all backend routes (HSTS & security headers middleware)
- [x] JWT expiry + refresh rotation
- [x] API rate limiting (FastAPI sliding window middleware)
- [x] Input validation (Pydantic) on all endpoints
- [x] No financial amounts logged server-side (privacy invariant preserved)

### Deliverable
> **End-to-end payment flow** + live backend + auth (`v0.4.0`) [COMPLETED]

---

## Phase 5 — Analytics, Notifications & Security Polish

**Estimated: 5–6 days**

### Goal
Complete the user-facing experience: rich goal analytics, push notifications, biometric lock, and a security/stability pass before beta.

### Tasks

#### Goal Analytics Screen (`lib/features/analytics/`)
- [x] Per-bucket analytics card:
  - Progress ring / bar with completion %
  - Amount saved, remaining, % complete
  - Days left to deadline
  - Required daily / weekly / monthly contribution run rates
  - Projected completion date
  - Per-goal forecast cards (`features/analytics/presentation/analytics_screen.dart`)
- [x] App-wide analytics:
  - Total allocated vs unallocated spendable balance
  - Portfolio goal funding progress
  - NEED vs WANT allocation ratio split
  - Waterfall protection activity metrics (spends absorbed & average debit)

#### Push Notifications
- [x] Integrate **Firebase Cloud Messaging (FCM)** architecture
- [x] Register device token with backend (`POST /auth/device`)
- [x] Server-side notification relay service (`backend/app/services/notification_service.py`)
- [x] Client notification service (`core/notifications/notification_service.dart`) with typed history:
  - Sync complete & external spend detected
  - Goal milestone: 25%, 50%, 75%, 100% complete
  - Goal deadline approaching (7 days, 1 day)
  - Waterfall goal protection triggered alert
  - Sync reminder when last sync > 24h

#### Biometric Lock
- [x] Integrate `local_auth` package (`core/security/biometric_service.dart`)
- [x] Lock app on background with configurable timeout: Immediately / 1min / 5min / 15min / Never
- [x] Biometric unlock screen overlay (`features/auth/presentation/biometric_lock_screen.dart`)
- [x] Fallback to PIN / device passcode
- [x] Setting to enable/disable in **Settings** screen

#### Settings Screen (`lib/features/settings/`)
- [x] Biometric lock toggle + timeout selector
- [x] Bank sync frequency preference
- [x] Zero-knowledge client-encrypted cloud backup trigger (`apiClient.storeBackup`)
- [x] Account management (current email, registered devices count, logout)
- [x] Privacy Guarantee & Zero Financial Data Invariant banner
- [x] About / version (`v0.5.0-beta`)

#### Security & Stability Pass
- [x] Zero balance/amount values in server logs (privacy invariant verified)
- [x] `flutter_secure_storage` Keystore/Keychain for tokens and lock preferences
- [x] API security review: sliding-window rate limits, HSTS, secure headers
- [x] Pydantic input validation and exception containment
- [x] Unit test suites for NotificationService, UpiPaymentService, and GoalAnalyticsEngine

#### Beta Prep
- [x] Release build configuration (`v0.5.0-beta`)
- [x] Beta onboarding & testing guide created (`docs/beta_testing_and_onboarding_guide.md`)
- [x] Setup 5 core testing scenarios for beta testers
- [x] Feedback reporting guidelines (GitHub Issues)

### Deliverable
> **Beta-ready build** (`v0.5.0`) [COMPLETED]

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
