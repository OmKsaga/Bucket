# Architecture & Data Contracts Specification

**Project:** Bucket — Goal-Based Virtual UPI Wallet  
**Document:** System Architecture, Database Schemas & API Contracts  
**Phase:** 0 (Product Foundation & UX)

---

## 1. System Architecture

Bucket is designed as a **Local-First, Privacy-Preserving System**:
- All personal financial ledgers, bucket allocations, and calculations live **100% on the user's mobile device**.
- The backend has **zero access** to the user's bucket names, targets, balance breakdowns, or transaction descriptions.
- The backend serves strictly as a lightweight coordination layer: authentication, push notification dispatching, device registration, and PSP payment reference initiation.

```
                           +-------------------------------------------------+
                           |                 USER'S DEVICE                   |
                           |                                                 |
                           |  [ Flutter UI (Riverpod / BLoC + GoRouter) ]    |
                           |                      |                          |
                           |       [ Domain Engines & Services ]             |
                           |       - AllocationEngine                        |
                           |       - ExternalSpendEngine (Waterfall)         |
                           |       - GoalAnalyticsEngine                     |
                           |       - PaymentWarningService                   |
                           |       - ReconciliationService                   |
                           |                      |                          |
                           |        [ Local Storage Layer ]                  |
                           |       - SQLite / Drift (Encrypted via SQLCipher)|
                           |       - FlutterSecureStorage (Keystore/Keychain)|
                           +-------------------------------------------------+
                                      |                           |
                            Minimal Metadata Only          Direct Sandbox Call
                          (JWT, Device Token, Hash)        (Payment Initiation)
                                      |                           |
                                      v                           v
                      +-------------------------------+   +-------------------+
                      |       FastAPI Backend         |   | Bank / UPI PSP    |
                      |  - Auth & Device Registry     |   | Sandbox Gateway   |
                      |  - Encrypted Backup Blob (Opt)|   | (Razorpay / Setu) |
                      |  - Push Notification Relay    |   +-------------------+
                      |  - PostgreSQL Metadata DB     |
                      +-------------------------------+
```

---

## 2. Local Database Schema (Drift / SQLite)

All monetary amounts are represented as **64-bit Integers in Paise** ($1 \text{ INR} = 100 \text{ Paise}$) to prevent floating-point calculation inaccuracies.

### 2.1 Table: `accounts`
Tracks the primary linked bank balance and sync state.
```sql
CREATE TABLE accounts (
    id TEXT PRIMARY KEY,                       -- UUID v4
    account_number_mask TEXT NOT NULL,         -- e.g. "XX4589" (Never full number)
    bank_name TEXT NOT NULL,                   -- e.g. "HDFC Bank"
    total_balance_paise INTEGER NOT NULL,      -- Current known balance in paise
    last_synced_at TEXT NOT NULL,              -- ISO 8601 string
    created_at TEXT NOT NULL
);
```

### 2.2 Table: `buckets`
Represents virtual goal allocations.
```sql
CREATE TABLE buckets (
    id TEXT PRIMARY KEY,                       -- UUID v4
    name TEXT NOT NULL,                        -- e.g. "MacBook M4"
    icon TEXT NOT NULL,                        -- Emoji or icon key (e.g. "laptop")
    target_amount_paise INTEGER NOT NULL,      -- Target goal in paise
    deadline TEXT,                             -- ISO 8601 Date string (optional)
    category TEXT NOT NULL,                    -- e.g. "Electronics", "Emergency"
    type TEXT NOT NULL,                        -- 'NEED' | 'WANT'
    priority INTEGER NOT NULL,                 -- 1 (Lowest) to 5 (Highest)
    is_protected INTEGER NOT NULL DEFAULT 0,  -- 0 = False, 1 = True (Boolean)
    is_completed INTEGER NOT NULL DEFAULT 0,  -- 0 = False, 1 = True (Boolean)
    notes TEXT,                                -- Optional user notes
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

### 2.3 Table: `ledger_entries`
Append-only immutable record of all virtual and real financial mutations.
```sql
CREATE TABLE ledger_entries (
    id TEXT PRIMARY KEY,                       -- UUID v4
    bucket_id TEXT,                            -- Foreign Key to buckets(id), NULL for unallocated transactions
    transaction_type TEXT NOT NULL,            -- Enum: 'INITIAL_ALLOCATION', 'MANUAL_ADD', 'MANUAL_REMOVE', 
                                               --       'REALLOCATION', 'EXTERNAL_SPEND_IMPACT', 
                                               --       'INCOME_DETECTED', 'REFUND_DETECTED', 'REVERSAL', 'GOAL_COMPLETED'
    amount_delta_paise INTEGER NOT NULL,       -- Positive (credit) or negative (debit) in paise
    balance_after_paise INTEGER NOT NULL,      -- Snapshot of bucket/account balance after operation
    reference_id TEXT,                         -- Linked payment reference or sync session ID
    note TEXT,                                 -- Description e.g. "Auto-deducted: -₹2,000 for external spending"
    timestamp TEXT NOT NULL,                   -- ISO 8601 timestamp
    FOREIGN KEY(bucket_id) REFERENCES buckets(id) ON DELETE RESTRICT
);
CREATE INDEX idx_ledger_bucket_time ON ledger_entries(bucket_id, timestamp);
```

### 2.4 Table: `sync_sessions`
Audit trail of synchronization events and reconciliation outcomes.
```sql
CREATE TABLE sync_sessions (
    id TEXT PRIMARY KEY,                       -- UUID v4
    session_hash TEXT NOT NULL UNIQUE,         -- SHA-256(timestamp + balance) for idempotency
    previous_balance_paise INTEGER NOT NULL,
    current_balance_paise INTEGER NOT NULL,
    difference_paise INTEGER NOT NULL,
    classification TEXT NOT NULL,              -- 'NO_CHANGE', 'EXTERNAL_SPEND', 'INCOMING_FUNDS', 'REFUND'
    impact_summary_json TEXT,                  -- JSON string summarizing affected buckets
    status TEXT NOT NULL,                      -- 'COMPLETED', 'FAILED', 'PENDING'
    created_at TEXT NOT NULL
);
```

### 2.5 Table: `app_settings`
Key-value configuration store.
```sql
CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

---

## 3. Backend Database Schema (FastAPI + PostgreSQL)

The server stores **only non-sensitive metadata**.

```sql
-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Registered mobile devices for push notifications
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_token VARCHAR(512) NOT NULL,       -- FCM registration token
    platform VARCHAR(32) NOT NULL,            -- 'android' | 'ios'
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sync session hashes for cross-device deduplication (NO financial numbers)
CREATE TABLE sync_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES devices(id),
    session_hash VARCHAR(64) NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- PSP Payment references
CREATE TABLE payment_references (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    provider_ref VARCHAR(128) NOT NULL UNIQUE, -- Provider transaction ID
    status VARCHAR(32) NOT NULL,               -- 'INITIATED', 'SUCCESS', 'FAILED'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 4. API Endpoints Specification

### 4.1 Authentication Service (`/api/v1/auth`)
- `POST /auth/register`: Create user account with email and password.
- `POST /auth/login`: Exchange credentials for JWT bearer token (`access_token`, `refresh_token`).
- `POST /auth/refresh`: Refresh expired access token.
- `POST /auth/device`: Register or update FCM device push token.

### 4.2 Sync Coordination (`/api/v1/sync`)
- `POST /sync/dedup-check`: Accepts `{"session_hash": "..."}`. Returns `{"is_duplicate": false}` if not yet processed.

### 4.3 Payments Integration (`/api/v1/payments`)
- `POST /payments/initiate`: Initiates UPI intent/QR transaction with provider sandbox. Returns `{"provider_ref": "...", "intent_url": "..."}`.
- `GET /payments/{provider_ref}/status`: Returns payment execution status (`SUCCESS`, `PENDING`, `FAILED`).
