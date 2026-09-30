# Goal-Based UPI Wallet --- Implementation Plan

## 1. Product Concept

A privacy-first, UPI-enabled money management app where users divide
their available money into **virtual buckets/goals**.

Money allocated to a bucket is considered **committed** and should not
be treated as spendable by the app. Because the MVP does not physically
lock money in the bank, external spending is detected during
synchronization and the allocation is automatically adjusted.

### Core principle

> **The app does not move real money between buckets. It manages virtual
> allocations of the user's real bank balance.**

Example:

``` text
Bank balance: ₹30,000

Rent       ₹10,000  Priority 5  NEED
Laptop      ₹8,000  Priority 4  WANT
Shoes       ₹5,000  Priority 2  WANT
PS5         ₹7,000  Priority 1  WANT

Total allocated = ₹30,000
Spendable/unallocated = ₹0
```

If the user spends ₹6,000 outside the app, the next sync detects:

``` text
Previous balance: ₹30,000
Current balance:  ₹24,000
Difference:       -₹6,000
```

The app deducts the ₹6,000 allocation impact from the **lowest-priority
eligible bucket(s)** and records the event.

No real bank transfer occurs.

------------------------------------------------------------------------

# 2. MVP Goals

The first version should prove three things:

1.  Users understand and use virtual money buckets.
2.  The allocation/reallocation model helps them avoid mentally spending
    committed money.
3.  Automatic reconciliation after external spending is useful.

The MVP should **not** attempt to become a custodial wallet or hold user
funds.

------------------------------------------------------------------------

# 3. Core Features

## A. Main/Home Screen

The home screen acts as the user's normal spending interface.

Display:

-   Current bank/account balance
-   Spendable/unallocated amount
-   Total allocated amount
-   Quick UPI payment
-   Scan QR
-   Recent transactions
-   Warning before payment if the transaction impacts committed
    allocations

Example:

``` text
Total balance       ₹30,000
Allocated           ₹25,000
Spendable            ₹5,000

[ Scan & Pay ]
[ Send Money ]

Recent transactions
- ₹450  Food
- ₹1,200  Shopping
```

------------------------------------------------------------------------

## B. Buckets / Allocations

Users can create buckets with:

-   Name
-   Icon
-   Target amount
-   Current allocation
-   Deadline
-   Category
-   Need / Want
-   Priority
-   Protected/unprotected status
-   Optional notes

Example:

``` text
Laptop
₹8,000 / ₹80,000

████░░░░░░ 10%

Deadline: 30 Dec 2026
Type: WANT
Priority: 4
```

------------------------------------------------------------------------

## C. Locked Allocation Concept

A bucket is logically locked.

The app should communicate:

> Money allocated to this bucket is committed to this goal.

The app should not silently transfer money between buckets.

If the user wants to move allocation:

``` text
[ Reallocate ]

From: Shoes
To: Laptop
Amount: ₹1,000

[ Confirm ]
```

This is an **internal allocation change**, not a bank transfer.

------------------------------------------------------------------------

# 4. Synchronization Model

The Allocations screen should show:

``` text
Last synced: Today, 8:42 PM

[ ↻ Sync Now ]
```

When syncing:

1.  Retrieve the latest supported account balance/transaction
    information.
2.  Compare current balance with the last known balance.
3.  Calculate the difference.
4.  Determine whether the difference represents:
    -   External spending
    -   Incoming money
    -   Refund/reversal
    -   Transfer
    -   Other supported transaction types
5.  Run the appropriate allocation logic.
6.  Update the local ledger.
7.  Notify the user.

------------------------------------------------------------------------

# 5. External Spending Algorithm

### Example

Previous balance:

`₹30,000`

Current balance:

`₹24,000`

Difference:

`-₹6,000`

Buckets:

``` text
Rent       ₹10,000  P5  NEED
Laptop      ₹8,000  P4  WANT
Shoes       ₹5,000  P2  WANT
PS5         ₹7,000  P1  WANT
```

The app applies the reduction starting with the **lowest-priority
eligible bucket**.

Result:

``` text
PS5         ₹7,000 → ₹1,000
Shoes       ₹5,000
Laptop      ₹8,000
Rent       ₹10,000
```

If the reduction is larger than one bucket:

``` text
External spending = ₹10,000

PS5      ₹7,000 → ₹0
Shoes    ₹5,000 → ₹2,000
```

### Important rules

-   Lower priority is affected before higher priority.
-   WANT buckets can be configured to be affected before NEED buckets.
-   Protected buckets are skipped.
-   If one bucket cannot absorb the full amount, continue to the next
    eligible bucket.
-   Never allow total allocations to exceed the latest known balance.
-   Every automatic adjustment creates a ledger entry.
-   The user is notified but the app does not ask for confirmation
    before applying the accounting adjustment.

------------------------------------------------------------------------

# 6. Reallocation

Automatic reconciliation and manual reallocation are different
operations.

### Automatic reconciliation

Triggered by external spending.

``` text
Bank balance decreases
        ↓
Difference detected
        ↓
Lowest-priority bucket affected
        ↓
Ledger entry created
        ↓
User notified
```

### Manual reallocation

Triggered by the user.

``` text
Laptop → Shoes
₹2,000
```

The app changes the virtual allocation only.

No actual money is transferred.

------------------------------------------------------------------------

# 7. Transaction / Allocation Ledger

Do not store only mutable bucket balances.

Maintain an append-only local ledger.

Possible transaction types:

``` text
INITIAL_ALLOCATION
MANUAL_ADD
MANUAL_REMOVE
REALLOCATION
EXTERNAL_SPEND_IMPACT
INCOME_DETECTED
REFUND_DETECTED
REVERSAL
GOAL_COMPLETED
```

Example:

``` text
30 Sep
External spending detected
-₹6,000 → PS5

28 Sep
Manual allocation
+₹2,000 → Laptop

25 Sep
Reallocation
₹1,000 Shoes → Goa
```

Current bucket balance should be derived from ledger entries wherever
practical.

This makes the system auditable and easier to debug.

------------------------------------------------------------------------

# 8. Incoming Money

When synchronization detects an increase:

``` text
Previous balance: ₹20,000
Current balance:  ₹25,000
Difference:       +₹5,000
```

Do **not** automatically distribute the money unless the user has
configured an automatic allocation rule.

Show:

``` text
₹5,000 new money detected.

Available to allocate: ₹5,000

[ Allocate ]
[ Keep Unallocated ]
```

Future versions can support rules such as:

``` text
Whenever salary arrives:
20% → Emergency Fund
15% → Laptop
10% → Vacation
```

------------------------------------------------------------------------

# 9. Goal Analytics

For each goal calculate locally:

-   Amount saved
-   Amount remaining
-   Percentage complete
-   Days remaining
-   Required daily contribution
-   Required weekly contribution
-   Required monthly contribution
-   Current contribution rate
-   Projected completion date

Example:

``` text
Laptop

Target: ₹80,000
Current: ₹32,000
Remaining: ₹48,000
Days remaining: 120

Required:
₹400/day
₹2,800/week
₹12,000/month
```

All of these calculations can happen on-device.

------------------------------------------------------------------------

# 10. Tech Stack

## Mobile

### Flutter + Dart

Why:

-   Android and iOS from one codebase
-   Good support for secure local storage
-   Strong UI capabilities
-   Easy integration with native Android/iOS functionality
-   Suitable for a student/startup MVP

------------------------------------------------------------------------

## Local Database

### SQLite

Recommended through:

-   Drift

Use SQLite as the primary local financial data store.

Store:

-   Users/profile metadata
-   Accounts
-   Buckets
-   Goals
-   Transactions
-   Allocation ledger
-   Sync state
-   Settings
-   Notification state

------------------------------------------------------------------------

## Secure Local Storage

Use platform secure storage:

-   Android Keystore
-   iOS Keychain

Store:

-   Authentication/session secrets
-   Encryption keys
-   Sensitive configuration

Do not store UPI PINs.

### Image Storage

Bucket inspiration images should be stored locally by default. Retain only the minimum metadata required to render and manage them, such as:

- Bucket ID
- Local image ID
- Local file path/reference
- Thumbnail reference
- Display order
- Creation timestamp

Images should not be uploaded to the backend unless the user explicitly enables an optional encrypted backup/sync feature.

------------------------------------------------------------------------

## Backend

### FastAPI + Python

The backend should remain intentionally thin.

Responsibilities:

-   Authentication
-   User/account metadata
-   Optional encrypted backup
-   Device registration
-   Payment/UPI integration services
-   App configuration
-   Non-sensitive telemetry
-   Notification infrastructure

Avoid sending detailed financial data to the backend unless required.

------------------------------------------------------------------------

## Cloud

### AWS

Suggested services:

``` text
AWS API Gateway
        ↓
AWS ECS/Fargate or Lambda
        ↓
FastAPI
        ↓
PostgreSQL
```

Supporting services:

-   Amazon Cognito or another authentication provider
-   AWS Secrets Manager
-   CloudWatch
-   S3 for non-sensitive application assets/backups where required

For the MVP, avoid unnecessary AWS complexity.

------------------------------------------------------------------------

## Database

### PostgreSQL

Used for server-side metadata rather than acting as the primary source
of financial calculations.

Possible tables:

``` text
users
devices
accounts
sync_sessions
payment_references
encrypted_backups
app_settings
```

The detailed bucket/ledger data can remain local by default.

------------------------------------------------------------------------

# 11. Local-First Architecture

The preferred architecture is:

``` text
                 DEVICE
┌──────────────────────────────────┐
│                                  │
│ Flutter UI                       │
│       ↓                          │
│ Local Application Services       │
│       ↓                          │
│ Reconciliation Engine            │
│       ↓                          │
│ Allocation Engine                │
│       ↓                          │
│ Goal/Analytics Engine            │
│       ↓                          │
│ SQLite / Drift                   │
│                                  │
└────────────────┬─────────────────┘
                 │
       Minimal required data
                 │
                 ▼
              Backend
                 │
       ┌─────────┴─────────┐
       │                   │
 Authentication       UPI/Bank Provider
```

### Privacy principle

> **Financial data stays on-device by default.**

Cloud synchronization should be:

-   Optional where practical
-   Encrypted
-   Explicitly consented to
-   Minimal
-   Never used to perform unnecessary analytics

------------------------------------------------------------------------

# 12. UPI Integration

The MVP should use an established UPI/payment provider/PSP rather than
attempting to operate the payment infrastructure independently.

The integration should support, subject to provider capabilities:

-   UPI payment initiation
-   QR scanning
-   Payment status
-   Transaction reference
-   Payment history
-   Appropriate reconciliation information

The app should never store:

-   UPI PIN
-   Bank password
-   Card CVV
-   Other payment authentication secrets

Important: a production UPI application requires appropriate
PSP/NPCI/regulatory arrangements. The first development version can use
a sandbox/mock payment layer.

------------------------------------------------------------------------

# 13. Payment Warning System

When the user initiates a payment through the app:

``` text
Payment: ₹5,000

Current spendable balance: ₹3,000

⚠️ This payment exceeds your currently
unallocated amount by ₹2,000.

The allocation engine expects this amount
to impact your lowest-priority bucket.

Continue?
```

For a smaller transaction:

``` text
Payment: ₹1,000

Spendable: ₹3,000

✓ This payment is within your spendable amount.

[ Pay ₹1,000 ]
```

The warning should inform, not prevent, unless the user later enables a
stricter protection mode.

------------------------------------------------------------------------

# 14. Sync UX

The Allocations screen should clearly expose synchronization state.

``` text
ALLOCATIONS

Balance: ₹24,000

Last synced:
30 Sep 2026, 8:42 PM

[ ↻ Sync Now ]
```

During sync:

``` text
Checking account...
Comparing balance...
Checking transactions...
Updating allocations...
```

After sync:

``` text
Sync complete

External spending detected: ₹6,000

₹6,000 impact allocated to:
🎮 PS5

[ View Details ]
```

------------------------------------------------------------------------

# 15. Security

Minimum requirements:

-   TLS for all network communication
-   Secure authentication
-   Device-level biometric lock
-   Secure local key storage
-   Encrypted sensitive local database fields where appropriate
-   No UPI PIN storage
-   API rate limiting
-   Secure secrets management
-   Audit trail for allocation changes
-   Transaction idempotency
-   Input validation
-   App integrity considerations
-   Backup/recovery strategy
-   Minimal logging of financial information

Do not log:

``` text
Account numbers
UPI identifiers unnecessarily
Transaction descriptions unnecessarily
Financial balances in plaintext logs
Authentication secrets
```

------------------------------------------------------------------------

# 16. Suggested Project Structure

``` text
app/
├── lib/
│   ├── core/
│   │   ├── security/
│   │   ├── database/
│   │   ├── networking/
│   │   └── constants/
│   │
│   ├── features/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── payments/
│   │   ├── allocations/
│   │   ├── goals/
│   │   ├── analytics/
│   │   └── settings/
│   │
│   ├── domain/
│   │   ├── models/
│   │   ├── services/
│   │   └── engines/
│   │
│   └── main.dart
│
backend/
├── app/
│   ├── api/
│   ├── auth/
│   ├── payments/
│   ├── users/
│   └── main.py
│
└── tests/
```

------------------------------------------------------------------------

# 17. Development Phases

## Phase 0 --- Product & UX

**2--4 days**

-   Finalize product name
-   Define user journeys
-   Design Figma screens
-   Finalize bucket rules
-   Finalize priority model
-   Define sync/reconciliation behavior

Deliverable:

**Clickable Figma prototype**

------------------------------------------------------------------------

## Phase 1 --- Local MVP

**7--10 days**

Build:

-   Flutter project
-   Authentication mock
-   SQLite/Drift
-   Home screen
-   Bucket creation
-   Bucket details
-   Goal calculations
-   Allocation ledger
-   Manual allocation/reallocation
-   Transaction history

Deliverable:

**Fully functional offline prototype**

------------------------------------------------------------------------

## Phase 2 --- Reconciliation Engine

**4--6 days**

Implement:

-   Previous/current balance
-   Difference calculation
-   External spending detection
-   Lowest-priority allocation algorithm
-   Protected buckets
-   Multiple-bucket deduction
-   Incoming money handling
-   Refund/reversal handling
-   Sync history

Deliverable:

**Complete allocation engine with tests**

------------------------------------------------------------------------

## Phase 3 --- Payments

**5--10+ days depending on provider**

Start with:

-   Mock UPI
-   Payment states
-   Transaction references
-   Payment history

Then move to:

-   Appropriate UPI/payment provider
-   Sandbox
-   Production integration

Deliverable:

**Real payment flow**

------------------------------------------------------------------------

## Phase 4 --- Analytics & Notifications

**3--5 days**

Add:

-   Goal progress
-   Saving rate
-   Required daily/monthly contributions
-   Goal projections
-   External spending alerts
-   Goal impact notifications

------------------------------------------------------------------------

## Phase 5 --- Security & Beta

**5--7 days**

-   Biometric lock
-   Secure storage
-   Encryption review
-   API security
-   Logging review
-   Crash handling
-   Test on multiple devices
-   20--50 user beta

------------------------------------------------------------------------

# 18. MVP Timeline

A realistic first version:

``` text
Week 1
UX + architecture + database

Week 2
Flutter UI + local database

Week 3
Ledger + allocation engine

Week 4
Sync simulation + analytics + notifications

Week 5
UPI/payment provider research + sandbox

Week 6
Security + testing + beta
```

A **fully production-grade financial product** will take considerably
longer because of payment-provider, security, compliance, and regulatory
requirements.

------------------------------------------------------------------------

# 19. Testing Strategy

The allocation engine is the most important component to test.

Test cases:

### External spending

``` text
Balance: ₹20,000 → ₹15,000
Reduction: ₹5,000
```

Verify lowest-priority bucket deduction.

### Multiple buckets

Reduction exceeds lowest bucket.

Verify overflow moves to the next eligible bucket.

### Protected bucket

Verify protected buckets are never automatically reduced.

### Incoming money

``` text
₹20,000 → ₹25,000
```

Verify ₹5,000 remains unallocated unless an auto-rule exists.

### Refund

Verify a ₹2,000 refund increases available allocation appropriately.

### Duplicate sync

Running the same sync twice must not create duplicate deductions.

### Offline mode

The app should remain usable for local features when offline.

### Conflicting updates

Handle cases where the local state is older than the latest sync.

------------------------------------------------------------------------

# 20. Future Features

After MVP validation:

-   Automatic allocation rules
-   Recurring savings
-   Salary detection
-   UPI AutoPay where supported
-   Bank transaction categorization
-   Spending forecasts
-   Shared/family goals
-   Goal streaks
-   AI financial assistant
-   Smart goal recommendations
-   Round-up savings
-   Actual restricted/regulated wallet architecture through a financial
    partner

------------------------------------------------------------------------

# 21. Product Positioning

The app should not initially be positioned as another generic budgeting
app.

Core positioning:

> **Give every rupee a purpose.**

or:

> **Spend freely. Protect what you've saved.**

The differentiator is the combination of:

**UPI spending + virtual committed buckets + automatic reconciliation +
privacy-first local processing.**

------------------------------------------------------------------------

# 22. Important MVP Boundary

For the first version:

**DO:**

-   Track actual balance
-   Track virtual allocations
-   Detect balance changes
-   Reallocate accounting impact
-   Warn before payments
-   Maintain a local ledger
-   Keep financial computation on-device

**DO NOT initially:**

-   Hold customer funds
-   Become a wallet/PPI issuer
-   Store UPI PINs
-   Attempt to directly control arbitrary external UPI spending
-   Send complete financial histories to the cloud
-   Build a custom payment network

The MVP should prove the **behavioral/product model** first. The
regulated financial infrastructure can be added through an appropriate
partner once the product is validated.
