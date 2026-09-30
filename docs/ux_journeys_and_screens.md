# Product & UX Specification: 5 Core User Journeys

**Project:** Bucket — Goal-Based Virtual UPI Wallet  
**Tagline:** *Spend freely. Protect what you've saved.*  
**Phase:** 0 (Product Foundation & UX)

---

## 1. Product Concept & Positioning

Bucket is a **privacy-first, local-first money management companion** linked with UPI.
- **The Core Rule:** The app *never moves real money between virtual buckets*. It holds zero customer funds. Real bank funds stay in the user's primary bank account.
- **Committed vs. Spendable:** Funds allocated to buckets are mentally and logically **committed**. Unallocated funds are **spendable**.
- **External Spending Detection:** When the user spends money outside the app (e.g. at a grocery store, online via another app, or debit card), the next sync detects the reduced bank balance and deducts the impact from the **lowest-priority eligible bucket(s)**.

---

## 2. The 5 Core User Journeys

### Journey 1: Creating a Virtual Goal Bucket

```
[Home Screen] 
      │ 
      ▼ tap "+ New Bucket" / "Add Goal"
[Create Bucket Sheet / Screen]
      │ 
      ├─ Step 1: Identity (Name: "PS5", Category: "Gaming", Icon: 🎮)
      ├─ Step 2: Financial Target (Target: ₹50,000, Initial Allocation: ₹10,000)
      ├─ Step 3: Timeline (Target Date / Deadline: 31 Dec 2026)
      ├─ Step 4: Classification (Type: NEED or WANT, Priority: 1 [Lowest] to 5 [Highest])
      └─ Step 5: Protection Mode (Toggle: Protected [Locked against auto-deduction] vs Normal)
      │
      ▼ tap "Create Bucket"
[Validation & Ledger Commit]
      │
      ├─ Check: Does Initial Allocation <= Current Spendable Balance?
      │   ├─ YES: Write INITIAL_ALLOCATION to Local Ledger
      │   └─ NO: Show warning "Exceeds spendable balance of ₹X. Reduce initial amount."
      ▼
[Bucket Detail Screen / Home] (Updated balances & visual progress bar)
```

#### Key Screen Elements:
- **Icon Selector:** Grid of emojis and curated financial/lifestyle vector icons.
- **Priority Slider:** 1 to 5 scale with intuitive labels:
  - 1: *First to sacrifice* (e.g., Impulse gadget, weekend trip)
  - 2: *Low priority* (e.g., Casual shopping)
  - 3: *Medium priority* (e.g., Annual subscription, new phone)
  - 4: *High priority* (e.g., Bike servicing, laptop upgrade)
  - 5: *Essential / Last to sacrifice* (e.g., House rent, Emergency fund, Medical emergency)
- **Need / Want Selector:** Segmented control. Defaults: NEED defaults to Priority 4-5; WANT defaults to Priority 1-3.
- **Protected Switch:** Explanatory caption: *"If enabled, money in this bucket will never be auto-deducted when external spending is detected."*

---

### Journey 2: Balance Sync & Reconciliation

```
[Allocations / Home Screen]
      │
      ▼ tap "↻ Sync Now" (or triggered periodically in background)
[Syncing Overlay / Animated State]
      │
      ├─ 1. Query Balance from Bank / PSP Sandbox API
      ├─ 2. Fetch Last Known Balance from Local Account Store
      ├─ 3. Calculate Delta = (Current Balance - Last Known Balance)
      │
      ├─ CASE A: Delta == 0 (No change)
      │     └─ Display: "All balances up to date. Last synced: Just now"
      │
      ├─ CASE B: Delta < 0 (External Spending Detected: e.g. -₹6,000)
      │     │
      │     ├─ 1. Query active buckets sorted by:
      │     │     a) Is Protected == FALSE
      │     │     b) Type: WANT before NEED
      │     │     c) Priority: ASCENDING (1 -> 5)
      │     │
      │     ├─ 2. Run Waterfall Deduction Algorithm:
      │     │     - Bucket A (P1, WANT, bal ₹2,000): deduct ₹2,000 -> bal ₹0
      │     │     - Bucket B (P2, WANT, bal ₹5,000): deduct ₹4,000 -> bal ₹1,000
      │     │     - Remaining delta satisfied (₹0)
      │     │
      │     ├─ 3. Write EXTERNAL_SPEND_IMPACT entries to Ledger in SQLite transaction
      │     ├─ 4. Record SyncSession audit record (timestamp, delta, affected buckets)
      │     └─ 5. Trigger System Notification + In-App Summary Card
      │
      └─ CASE C: Delta > 0 (Incoming Money Detected: e.g. +₹15,000)
            │
            ├─ 1. Increase Spendable Balance by ₹15,000
            ├─ 2. Write INCOME_DETECTED entry to Ledger
            ├─ 3. Prompt User: "₹15,000 new funds detected. Allocate to goals or keep spendable?"
            └─ 4. User can tap [Allocate Now] -> Quick Multi-Bucket Allocator
```

#### Key Screen Elements:
- **Sync Result Modal / Card:**
  - Header: `External spending detected: -₹6,000`
  - Visual breakdown:
    - 🎮 PS5: `₹2,000 → ₹0` (Fully depleted)
    - 👟 Shoes: `₹5,000 → ₹1,000` (₹4,000 absorbed)
  - Action: `[Review Impact]` or `[Adjust Priorities]`

---

### Journey 3: Pre-Payment Warning (Scan & Pay / Send Money)

```
[Home Screen]
      │
      ▼ tap "Scan QR" (Camera Scanner) or "Send Money" (Enter VPA/Phone)
[Payment Initiation Screen]
      │
      ├─ Recipient details (Merchant / Contact name, UPI ID)
      ├─ Amount Input: e.g. ₹4,500
      │
      ▼ Real-time Impact Assessment Engine runs as user types amount:
      │
      ├─ Spendable Balance: ₹3,000
      ├─ Transaction Amount: ₹4,500
      ├─ Deficit = ₹4,500 - ₹3,000 = ₹1,500
      │
      ├─ SCENARIO A: Amount <= Spendable (e.g. ₹2,000 <= ₹3,000)
      │     └─ Display Green Pill: "✓ Safe to spend — completely within unallocated balance."
      │        Button: [ Pay ₹2,000 ]
      │
      └─ SCENARIO B: Amount > Spendable (e.g. ₹4,500 > ₹3,000)
            └─ Display Amber Warning Card:
               "⚠️ Exceeds spendable balance by ₹1,500."
               "Expected impact: ₹1,500 will be deducted from lowest-priority bucket: 🎮 PS5."
               Button: [ Proceed & Pay ₹4,500 ] (secondary: [ Cancel ])
```

#### Key Screen Elements:
- **Live Impact Indicator:** Updates dynamically on every keystroke.
- **Impact Preview Tray:** Shows exact bucket cards that will absorb the reduction if payment goes through.
- **Informative, Non-blocking:** By default, warns and asks for confirmation rather than hard blocking, respecting user autonomy.

---

### Journey 4: Manual Virtual Reallocation

```
[Bucket Detail Screen] (e.g. "Laptop", currently allocated ₹8,000)
      │
      ▼ tap "Reallocate Funds"
[Reallocation Bottom Sheet]
      │
      ├─ Source Bucket: Laptop (Available: ₹8,000)
      ├─ Target Bucket Selector: [ Dropdown / Carousel of other active buckets ]
      │     e.g., Selected: "Emergency Fund" (Current: ₹12,000)
      ├─ Amount Slider / Input: ₹2,500
      │
      ▼ tap "Confirm Reallocation"
[Atomic Ledger Execution]
      │
      ├─ Begin DB Transaction:
      │     1. Write LedgerEntry(REALLOCATION, bucket_id=Laptop, delta=-₹2,500)
      │     2. Write LedgerEntry(REALLOCATION, bucket_id=EmergencyFund, delta=+₹2,500)
      │     3. Commit Transaction
      ▼
[Success Feedback]
      - Laptop: ₹5,500
      - Emergency Fund: ₹14,500
      - Unallocated / Total bank balance: Unchanged
```

#### Key Screen Elements:
- **Transfer Visualizer:** Interactive arrow showing transfer of allocation from Source -> Target.
- **Zero Real-Bank-Impact Note:** Explicit subtext reminding user that this is an internal accounting adjustment.

---

### Journey 5: Goal Achievement & Completion

```
[Sync or Manual Allocation leads to Current Allocation >= Target Amount]
      │
      ▼
[Goal Milestone Event Triggered]
      │
      ├─ Lottie Confetti Animation + Haptic Feedback
      ├─ Milestone Badge: "Goal Achieved: 💻 MacBook Air (₹80,000 / ₹80,000)"
      │
      ▼ tap "View Goal Celebration"
[Goal Completion Options Screen]
      │
      ├─ OPTION 1: "Mark as Ready to Spend"
      │     - Temporarily locks bucket with high priority (P5, Protected) so funds are safeguarded until the real purchase is made.
      │
      ├─ OPTION 2: "Complete & Close Bucket"
      │     - Archives bucket to 'Completed Goals' hall-of-fame.
      │     - Marks ledger entry GOAL_COMPLETED.
      │
      └─ OPTION 3: "Increase Target / Keep Saving"
            - Allows user to turn it into an ongoing fund or adjust target.
```

---

## 3. Screen Hierarchy & Navigation Architecture

```
Root Bottom Navigation:
├── [Home]
│   ├── Balance Overview Card (Total Bank, Allocated, Spendable)
│   ├── Quick Action Bar (Scan QR, Send Money, Sync Now)
│   ├── Top Priority Goals Carousel
│   └── Recent Spending & Allocation Activity Feed
│
├── [Buckets]
│   ├── Segment Tabs: [All Goals] | [Needs] | [Wants] | [Completed]
│   ├── Sorted Bucket Cards Grid/List
│   └── FAB: "+ New Bucket"
│
├── [Ledger / Activity]
│   ├── Filter Chips: [All] [External Spend] [Reallocated] [Income]
│   └── Chronological Audit Feed with expandable entry details
│
└── [Settings]
    ├── Security: Biometric Lock (FaceID / Fingerprint / Passcode)
    ├── Sync Preferences & Linked Provider Sandbox
    ├── Backup & Export (Encrypted Local / Cloud)
    └── App Info & Privacy Policy
```
