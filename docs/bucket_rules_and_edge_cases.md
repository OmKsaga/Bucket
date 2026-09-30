# Bucket Rules, Priority Logic & Edge Cases Matrix

**Project:** Bucket — Goal-Based Virtual UPI Wallet  
**Document:** Algorithmic & Business Rules Specification  
**Phase:** 0 (Product Foundation & UX)

---

## 1. Bucket Classification & Priority Model

Every virtual bucket has four key accounting attributes:
1. **Target Amount (`target_amount`)**: Total target monetary value (e.g. ₹50,000).
2. **Category Type (`type`)**: `NEED` or `WANT`.
3. **Priority Level (`priority`)**: Integer from `1` (Lowest) to `5` (Highest).
4. **Protection Flag (`is_protected`)**: Boolean (`true` / `false`).

### 1.1 Priority Scale Semantics

| Priority | Label | Typical Use Case | Sacrifice Order during External Spend |
|---|---|---|---|
| **1** | Lowest / Disposable | Impulse buys, entertainment, gadgets | **1st** (Drained first) |
| **2** | Low | Casual dining out, clothing, leisure travel | **2nd** |
| **3** | Medium | Annual software subscriptions, festival gifts | **3rd** |
| **4** | High | Vehicle insurance/maintenance, laptop for work | **4th** |
| **5** | Critical / Essential | Rent, emergency fund, utility bills | **5th** (Drained last) |

### 1.2 Eligibility & Sorting Algorithm for External Spend Deduction

When external spending reduces the user's bank balance, the deduction algorithm sorts buckets using the following multi-key comparator:

```python
def get_deduction_order(buckets: list[Bucket]) -> list[Bucket]:
    """
    Sort order for waterfall deduction:
    1. Filter out buckets where is_protected == True
    2. Filter out buckets where current_allocation <= 0
    3. Sort by:
       - Type: WANT (0) before NEED (1)
       - Priority: ASCENDING (1 -> 5)
       - Created At: OLDEST FIRST (tie-breaker)
    """
    eligible = [b for b in buckets if not b.is_protected and b.current_balance > 0]
    return sorted(eligible, key=lambda b: (
        0 if b.type == BucketType.WANT else 1,
        b.priority,
        b.created_at
    ))
```

---

## 2. Waterfall Deduction Algorithm (Formal Definition)

### Input:
- `unallocated_balance`: Current spendable funds ($B_{unallocated} = B_{total} - \sum B_{allocated}$).
- `spend_delta`: Absolute magnitude of external spend ($D > 0$).
- `buckets`: Active buckets in account.

### Step 1: Absorb from Unallocated Funds First
$$\text{absorbed\_by\_unallocated} = \min(B_{unallocated}, D)$$
$$\text{remaining\_deficit} = D - \text{absorbed\_by\_unallocated}$$
$$B'_{unallocated} = B_{unallocated} - \text{absorbed\_by\_unallocated}$$

If $\text{remaining\_deficit} == 0$, no buckets are touched. Only write `LedgerEntry(EXTERNAL_SPEND_IMPACT, bucket_id=null, amount=-D)`.

### Step 2: Waterfall Across Eligible Buckets
For each bucket $b$ in `get_deduction_order(buckets)`:
- If $\text{remaining\_deficit} == 0$, terminate loop.
- $\text{deduct\_amount} = \min(b.\text{current\_allocation}, \text{remaining\_deficit})$
- $b.\text{current\_allocation} \leftarrow b.\text{current\_allocation} - \text{deduct\_amount}$
- $\text{remaining\_deficit} \leftarrow \text{remaining\_deficit} - \text{deduct\_amount}$
- Emit `LedgerEntry(EXTERNAL_SPEND_IMPACT, bucket_id=b.id, amount=-deduct_amount)`

### Step 3: Handle Residual Deficit
If $\text{remaining\_deficit} > 0$ after checking all eligible buckets:
- All unallocated and all unprotected buckets are exhausted.
- Check protected buckets: **NEVER touch protected buckets automatically**.
- Mark account state as `ALLOCATION_DEFICIT(remaining_deficit)`.
- Alert user with critical priority banner:
  *"Your external spending exceeded your unprotected allocations by ₹X. Protected buckets were preserved, but your virtual allocations exceed your real bank balance."*

---

## 3. Comprehensive Edge Cases Matrix

| # | Edge Case Scenario | Condition | System Behavior & Invariant Maintenance | User UX & Notification |
|---|---|---|---|---|
| **E1** | **Zero-Balance Bucket** | `bucket.current_allocation == 0` | Skipped automatically during deduction sorting. Not eligible for withdrawal or reallocation. | Grayed out in reallocation source picker. Displays "₹0 / Target" state. |
| **E2** | **External Spend Exceeds All Unprotected Buckets** | $D > B_{unallocated} + \sum_{unprotected} b_i$ | 1. Drains unallocated to 0.<br>2. Drains all unprotected buckets to 0.<br>3. Leaves protected buckets intact.<br>4. Records overall bank balance deficit in ledger. | High-priority amber/red alert: *"Deficit detected. Real bank balance is lower than total protected allocations."* |
| **E3** | **Bank Balance Becomes Negative / Overdraft** | Bank API reports $B_{total} < 0$ | Flag account status as `OVERDRAFT`. Set $B_{unallocated} = 0$. Record `OVERDRAFT_DETECTED` ledger entry. | Warning card on Home Screen: *"Bank account is in negative balance (-₹X). Virtual allocations frozen until balance is restored."* |
| **E4** | **Incoming Money / Salary Detection** | Delta $D > 0$ | $B_{unallocated} \leftarrow B_{unallocated} + D$.<br>Write `INCOME_DETECTED` ledger entry.<br>No automatic bucket distribution (unless explicit user rule configured). | Toast/Notification: *"₹X received into your account. Tap to allocate to your goals."* |
| **E5** | **Merchant Refund / UPI Reversal** | Delta $D > 0$ with reversal tag or matching previous spend | Treated as incoming funds to unallocated pool by default.<br>App offers 1-tap "Restore to [Last Impacted Bucket]" button in sync sheet. | Prompt: *"₹X refund detected. Would you like to restore this to PS5 bucket?"* |
| **E6** | **Duplicate Sync Execution (Race / Network Retry)** | Multiple sync requests sent in quick succession | **Idempotency check:** Each sync evaluates $(B_{current}, \text{timestamp})$. If hash matches last committed session within 60s, return cached result without writing duplicate ledger entries. | Immediate seamless response; spinner closes with "Already up to date." |
| **E7** | **Offline Mode with Cached Data** | Device loses internet connection | Full read access to local SQLite/Drift database. Manual allocations and reallocations continue to work locally.<br>Sync action shows: "Offline: Unable to reach bank provider." | Gray badge: *"Offline mode — Showing local ledger as of [Timestamp]"* |
| **E8** | **All Buckets are Marked Protected** | All $b_i.\text{is\_protected} == \text{True}$ | If spend exceeds unallocated balance, no buckets are deducted. Deficit is recorded against unallocated balance directly (negative spendable pool). | Alert explains that all buckets were protected, resulting in an unallocated deficit. |
| **E9** | **Reallocation Exceeds Source Balance** | User attempts to reallocate ₹5,000 from bucket having ₹3,000 | Validation fails before ledger write. Enforce: $\text{amount} \le b_{source}.\text{balance}$. | UI slider caps at current balance; error message: *"Cannot reallocate more than current bucket balance."* |
| **E10** | **Fractional / Paise Precision** | Transactions with fractional paise (e.g. ₹450.75) | Store all monetary values internally as **integers in Paise** (₹1.00 = 100 paise) to eliminate floating-point rounding errors. Format to 2 decimal places in UI. | User sees clean ₹X.XX currency formatting everywhere without rounding drift. |

---

## 4. Ledger Transaction Types Contract

Every mutation of balance or allocation must write an atomic, append-only row to the `ledger_entries` table:

```sql
CREATE TYPE transaction_type AS ENUM (
    'INITIAL_ALLOCATION',     -- When bucket is first funded on creation
    'MANUAL_ADD',            -- User adds spendable funds to a bucket
    'MANUAL_REMOVE',         -- User withdraws bucket funds back to spendable
    'REALLOCATION',          -- Virtual transfer between two buckets (paired entries: +/-)
    'EXTERNAL_SPEND_IMPACT', -- Automatic deduction triggered by external bank spend
    'INCOME_DETECTED',       -- Real bank balance increased
    'REFUND_DETECTED',       -- Reversal or refund credited
    'REVERSAL',              -- Internal correction entry
    'GOAL_COMPLETED'         -- Goal reached and marked completed/archived
);
```
