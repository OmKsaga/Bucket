# 🪣 Bucket — Goal-Based Virtual UPI Wallet

> **Give every rupee a purpose.**  
> *Spend freely. Protect what you've saved.*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.16+-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![SQLite / Drift](https://img.shields.io/badge/Storage-Drift%20%2F%20SQLite-003B57?logo=sqlite)](https://drift.simonbinder.eu)
[![Architecture](https://img.shields.io/badge/Architecture-Local--First-8B5CF6)]()

---

## 📖 Overview

**Bucket** is a privacy-first, local-first personal finance application linked with UPI where users divide their bank balance into **virtual goal buckets**.

Money allocated to a bucket is **committed** and logically deducted from the user's spendable pool. Because Bucket is non-custodial and does not hold user funds, external spending (via card, UPI, ATM) is automatically detected during synchronization, and the accounting impact is absorbed from the **lowest-priority eligible bucket(s)**.

### Core Principle
> **The app does not move real money between buckets. It manages virtual allocations of the user's real bank balance.**

```text
Real Bank Balance: ₹30,000

Virtual Allocations:
  ├── Rent           ₹10,000  [Priority 5 | NEED]   (Protected)
  ├── Laptop          ₹8,000  [Priority 4 | WANT]
  ├── Shoes           ₹5,000  [Priority 2 | WANT]
  └── PS5             ₹7,000  [Priority 1 | WANT]   <-- Drained first if external spend occurs

Total Allocated:   ₹30,000
Spendable Pool:         ₹0
```

---

## 🏛️ System Architecture

```text
                  +-------------------------------------------------+
                  |                 USER'S DEVICE                   |
                  |                                                 |
                  |  [ Flutter UI (Riverpod + GoRouter) ]           |
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

### Privacy Guarantee
- **Financial data stays on-device by default.** Bucket balances, target goals, personal ledger entries, and transaction breakdowns are **never** transmitted to the cloud backend.
- The server stores only authentication records, device push tokens, and cryptographic session hashes for deduplication.

---

## 📂 Project Structure

```text
Bucket/
├── app/                             # Flutter mobile application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/           # App-wide constants & priority labels
│   │   │   ├── theme/               # Dark & light design system tokens
│   │   │   └── security/            # Biometrics & secure storage helpers
│   │   ├── domain/
│   │   │   ├── models/              # Pure domain entities (Bucket, LedgerEntry, Account)
│   │   │   ├── engines/             # Pure calculation engines (Allocation, Waterfall, Analytics)
│   │   │   └── services/            # Reconciliation & Payment warning services
│   │   ├── features/
│   │   │   ├── allocations/         # Bucket creation, editing, priority management
│   │   │   ├── analytics/           # Goal progress charts, savings rates
│   │   │   ├── auth/                # Sign in & device pairing
│   │   │   ├── home/                # Balance overview & quick actions
│   │   │   ├── payments/            # Scan QR, send money, impact preview
│   │   │   └── settings/            # Biometric lock & sync preferences
│   │   └── main.dart                # App entrypoint
│   ├── test/                        # Flutter unit and widget tests
│   └── pubspec.yaml                 # Dependencies (Drift, Riverpod, GoRouter, etc.)
│
├── backend/                         # FastAPI backend services
│   ├── app/
│   │   ├── api/v1/                  # Endpoints (Health, Auth, Sync, Payments)
│   │   ├── core/                    # App configuration & JWT security
│   │   ├── models/                  # SQLAlchemy PostgreSQL models
│   │   ├── schemas/                 # Pydantic validation schemas
│   │   └── main.py                  # FastAPI application entrypoint
│   ├── tests/                       # Pytest test suite
│   ├── Dockerfile                   # Production container definition
│   ├── docker-compose.yml           # Local dev with PostgreSQL
│   └── requirements.txt             # Python dependencies
│
├── docs/                            # Architectural & UX Specifications
│   ├── ux_journeys_and_screens.md   # 5 core user journeys & wireframes
│   ├── bucket_rules_and_edge_cases.md # Priority waterfall algorithm & edge case matrix
│   └── architecture_and_data_contracts.md # Drift schema, API contracts & security specs
│
├── goal_based_upi_wallet_implementation_plan.md # Original product document
├── phased_implementation_plan.md    # Balanced 6-phase roadmap
└── README.md
```

---

## 🗺️ Implementation Roadmap

| Phase | Milestone | Scope | Status |
|:---:|:---|:---|:---:|
| **0** | **Foundation & UX** | UX journeys, architecture, schema contracts, project scaffold | **Completed** ✅ |
| **1** | **Local Core: Data Layer** | Drift/SQLite DB, DAOs, AllocationEngine, Waterfall deduction, Unit tests | **Completed** ✅ |
| **2** | **Local Core: UI Layer** | Complete offline Flutter UI (Home, Buckets, Ledger, Manual sync sim) | **Completed** ✅ |
| **3** | **Reconciliation Engine** | Bank/PSP sandbox sync, live waterfall reconciliation, Payment warning | Next ⏳ |
| **4** | **Payments & Backend** | FastAPI backend, JWT auth, UPI payment initiation, Docker/AWS | Upcoming ⏳ |
| **5** | **Analytics & Security** | Goal analytics, push notifications, biometric lock, beta release | Upcoming ⏳ |

---

## 🚀 Getting Started

### Prerequisites
- [Git](https://git-scm.com/)
- [Python 3.11+](https://www.python.org/)
- [Flutter 3.16+ & Dart](https://flutter.dev/) (for mobile app)
- [Docker & Docker Compose](https://www.docker.com/) (optional, for backend dev)

### Backend Setup (FastAPI)
```bash
cd backend

# Create virtual environment
python -m venv venv
# On Windows:
.\venv\Scripts\activate
# On Linux/macOS:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run server with hot reload
uvicorn app.main:app --reload --port 8000
```
API Documentation will be live at: `http://localhost:8000/docs`

Or run with Docker:
```bash
docker-compose up --build
```

### Mobile App Setup (Flutter)
```bash
cd app

# Fetch dependencies
flutter pub get

# Run on emulator / connected device
flutter run
```

---

## 🌿 Git Branching Strategy

```text
main                    <-- Stable releases (tagged: v0.0.1, v0.1.0, etc.)
  └── dev               <-- Integration branch
        ├── phase/0     <-- Phase 0: Project Foundation & UX (Scaffold)
        ├── phase/1     <-- Phase 1: Local Core Data Layer
        ├── phase/2     <-- Phase 2: Local Core UI Layer
        ├── phase/3     <-- Phase 3: Reconciliation Engine
        ├── phase/4     <-- Phase 4: Payments & Backend
        └── phase/5     <-- Phase 5: Analytics, Security & Beta
```

Push protocol per phase:
1. Feature work developed on `phase/N` branch.
2. Pull Request merged from `phase/N` into `dev`.
3. `dev` validated and merged into `main`.
4. Release tagged with semantic version (`v0.N.0`).

---

## 🛡️ Security & Disclaimers

1. **Non-Custodial:** Bucket **never** holds customer funds, issues payment instruments, or operates as a PPI wallet.
2. **Zero PIN Storage:** Bucket **never** stores UPI PINs, net banking credentials, or card CVVs.
3. **Local-First Privacy:** All personal financial accounting is performed on-device.
