"""
Verification test suite for core Bucket domain logic & algorithms:
- Allocation & Invariant validation
- External Spend Waterfall Deduction
- Income Detection & Unallocated Pool
- Goal Analytics & Forecast Calculations
"""
import pytest
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Tuple
from dataclasses import dataclass, field
from enum import Enum


class BucketType(str, Enum):
    NEED = "NEED"
    WANT = "WANT"


class TransactionType(str, Enum):
    INITIAL_ALLOCATION = "INITIAL_ALLOCATION"
    MANUAL_ADD = "MANUAL_ADD"
    MANUAL_REMOVE = "MANUAL_REMOVE"
    REALLOCATION = "REALLOCATION"
    EXTERNAL_SPEND_IMPACT = "EXTERNAL_SPEND_IMPACT"
    INCOME_DETECTED = "INCOME_DETECTED"
    GOAL_COMPLETED = "GOAL_COMPLETED"


@dataclass
class Bucket:
    id: str
    name: str
    target_amount_paise: int
    current_allocation_paise: int
    type: BucketType
    priority: int  # 1 (lowest) to 5 (highest)
    is_protected: bool = False
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class LedgerEntry:
    id: str
    bucket_id: Optional[str]
    transaction_type: TransactionType
    amount_delta_paise: int
    balance_after_paise: int
    timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


# --- Allocation Engine ---
class AllocationEngine:
    @staticmethod
    def allocate(bucket: Bucket, amount_paise: int, unallocated_paise: int) -> Tuple[Bucket, LedgerEntry, int]:
        if amount_paise <= 0:
            raise ValueError("Allocation amount must be strictly greater than 0.")
        if amount_paise > unallocated_paise:
            raise ValueError("Cannot allocate more than current unallocated balance.")

        new_alloc = bucket.current_allocation_paise + amount_paise
        entry_type = (
            TransactionType.INITIAL_ALLOCATION if bucket.current_allocation_paise == 0 else TransactionType.MANUAL_ADD
        )
        updated_bucket = Bucket(
            id=bucket.id,
            name=bucket.name,
            target_amount_paise=bucket.target_amount_paise,
            current_allocation_paise=new_alloc,
            type=bucket.type,
            priority=bucket.priority,
            is_protected=bucket.is_protected,
            created_at=bucket.created_at,
        )
        entry = LedgerEntry(
            id="entry_1",
            bucket_id=bucket.id,
            transaction_type=entry_type,
            amount_delta_paise=amount_paise,
            balance_after_paise=new_alloc,
        )
        return updated_bucket, entry, unallocated_paise - amount_paise

    @staticmethod
    def deallocate(bucket: Bucket, amount_paise: int, unallocated_paise: int) -> Tuple[Bucket, LedgerEntry, int]:
        if amount_paise <= 0:
            raise ValueError("Deallocation amount must be strictly greater than 0.")
        if amount_paise > bucket.current_allocation_paise:
            raise ValueError("Cannot deallocate more than current bucket balance.")

        new_alloc = bucket.current_allocation_paise - amount_paise
        updated_bucket = Bucket(
            id=bucket.id,
            name=bucket.name,
            target_amount_paise=bucket.target_amount_paise,
            current_allocation_paise=new_alloc,
            type=bucket.type,
            priority=bucket.priority,
            is_protected=bucket.is_protected,
            created_at=bucket.created_at,
        )
        entry = LedgerEntry(
            id="entry_2",
            bucket_id=bucket.id,
            transaction_type=TransactionType.MANUAL_REMOVE,
            amount_delta_paise=-amount_paise,
            balance_after_paise=new_alloc,
        )
        return updated_bucket, entry, unallocated_paise + amount_paise

    @staticmethod
    def reallocate(from_bucket: Bucket, to_bucket: Bucket, amount_paise: int) -> Tuple[Bucket, Bucket, LedgerEntry, LedgerEntry]:
        if from_bucket.id == to_bucket.id:
            raise ValueError("Source and target bucket cannot be identical.")
        if amount_paise <= 0:
            raise ValueError("Amount must be greater than 0.")
        if amount_paise > from_bucket.current_allocation_paise:
            raise ValueError("Insufficient balance in source bucket.")

        updated_from = Bucket(
            id=from_bucket.id,
            name=from_bucket.name,
            target_amount_paise=from_bucket.target_amount_paise,
            current_allocation_paise=from_bucket.current_allocation_paise - amount_paise,
            type=from_bucket.type,
            priority=from_bucket.priority,
            is_protected=from_bucket.is_protected,
            created_at=from_bucket.created_at,
        )
        updated_to = Bucket(
            id=to_bucket.id,
            name=to_bucket.name,
            target_amount_paise=to_bucket.target_amount_paise,
            current_allocation_paise=to_bucket.current_allocation_paise + amount_paise,
            type=to_bucket.type,
            priority=to_bucket.priority,
            is_protected=to_bucket.is_protected,
            created_at=to_bucket.created_at,
        )
        entry_from = LedgerEntry(
            id="e_from",
            bucket_id=from_bucket.id,
            transaction_type=TransactionType.REALLOCATION,
            amount_delta_paise=-amount_paise,
            balance_after_paise=updated_from.current_allocation_paise,
        )
        entry_to = LedgerEntry(
            id="e_to",
            bucket_id=to_bucket.id,
            transaction_type=TransactionType.REALLOCATION,
            amount_delta_paise=amount_paise,
            balance_after_paise=updated_to.current_allocation_paise,
        )
        return updated_from, updated_to, entry_from, entry_to


# --- External Spend Waterfall Engine ---
class ExternalSpendEngine:
    @staticmethod
    def execute_waterfall(spend_paise: int, unallocated_paise: int, buckets: List[Bucket]):
        if spend_paise <= 0:
            raise ValueError("Spend amount must be greater than 0.")

        absorbed_by_unallocated = min(max(0, unallocated_paise), spend_paise)
        remaining_deficit = spend_paise - absorbed_by_unallocated
        new_unallocated = unallocated_paise - absorbed_by_unallocated

        # Filter and sort deduction order
        # Rule: Only unprotected and balance > 0, WANT before NEED, Priority 1 -> 5, CreatedAt ASC
        eligible = [b for b in buckets if not b.is_protected and b.current_allocation_paise > 0]
        eligible.sort(key=lambda b: (
            0 if b.type == BucketType.WANT else 1,
            b.priority,
            b.created_at,
        ))

        impacts = []
        updated_buckets = {b.id: b for b in buckets}

        for b in eligible:
            if remaining_deficit == 0:
                break
            deduct = min(b.current_allocation_paise, remaining_deficit)
            new_alloc = b.current_allocation_paise - deduct
            updated = Bucket(
                id=b.id,
                name=b.name,
                target_amount_paise=b.target_amount_paise,
                current_allocation_paise=new_alloc,
                type=b.type,
                priority=b.priority,
                is_protected=b.is_protected,
                created_at=b.created_at,
            )
            updated_buckets[b.id] = updated
            impacts.append({
                "bucket_id": b.id,
                "name": b.name,
                "deducted_paise": deduct,
                "new_balance_paise": new_alloc,
            })
            remaining_deficit -= deduct

        is_deficit = remaining_deficit > 0
        if is_deficit:
            new_unallocated -= remaining_deficit

        return {
            "absorbed_by_unallocated_paise": absorbed_by_unallocated,
            "new_unallocated_paise": new_unallocated,
            "impacts": impacts,
            "updated_buckets": list(updated_buckets.values()),
            "remaining_deficit_paise": remaining_deficit,
            "is_deficit": is_deficit,
        }


# --- Tests ---
def test_allocation_within_spendable():
    b = Bucket("1", "PS5", 5000000, 1000000, BucketType.WANT, 1)
    updated, entry, new_unalloc = AllocationEngine.allocate(b, 500000, 1000000)
    assert updated.current_allocation_paise == 1500000
    assert new_unalloc == 500000
    assert entry.amount_delta_paise == 500000


def test_allocation_exceeding_spendable_raises():
    b = Bucket("1", "PS5", 5000000, 1000000, BucketType.WANT, 1)
    with pytest.raises(ValueError):
        AllocationEngine.allocate(b, 1500000, 500000)


def test_deallocation_valid():
    b = Bucket("1", "PS5", 5000000, 1000000, BucketType.WANT, 1)
    updated, entry, new_unalloc = AllocationEngine.deallocate(b, 400000, 200000)
    assert updated.current_allocation_paise == 600000
    assert new_unalloc == 600000
    assert entry.amount_delta_paise == -400000


def test_reallocation_between_buckets():
    b1 = Bucket("1", "PS5", 5000000, 1000000, BucketType.WANT, 1)
    b2 = Bucket("2", "Laptop", 8000000, 2000000, BucketType.WANT, 4)
    up_b1, up_b2, e1, e2 = AllocationEngine.reallocate(b1, b2, 300000)
    assert up_b1.current_allocation_paise == 700000
    assert up_b2.current_allocation_paise == 2300000
    assert e1.amount_delta_paise == -300000
    assert e2.amount_delta_paise == 300000


def test_waterfall_absorbed_by_unallocated():
    buckets = [
        Bucket("1", "PS5", 5000000, 700000, BucketType.WANT, 1),
    ]
    res = ExternalSpendEngine.execute_waterfall(200000, 500000, buckets)
    assert res["absorbed_by_unallocated_paise"] == 200000
    assert res["new_unallocated_paise"] == 300000
    assert len(res["impacts"]) == 0
    assert not res["is_deficit"]


def test_waterfall_drains_lowest_priority_want_first():
    # PS5 (WANT, P1, ₹7,000) vs Shoes (WANT, P2, ₹5,000) vs Rent (NEED, P5, Protected, ₹10,000)
    b1 = Bucket("ps5", "PS5", 5000000, 700000, BucketType.WANT, 1)
    b2 = Bucket("shoes", "Shoes", 1000000, 500000, BucketType.WANT, 2)
    b3 = Bucket("rent", "Rent", 1000000, 1000000, BucketType.NEED, 5, is_protected=True)

    # Spend ₹6,000. Unallocated has ₹2,000.
    # Deficit to absorb = ₹4,000. Lowest eligible is PS5 (₹7,000).
    res = ExternalSpendEngine.execute_waterfall(600000, 200000, [b1, b2, b3])
    assert res["absorbed_by_unallocated_paise"] == 200000
    assert res["new_unallocated_paise"] == 0
    assert len(res["impacts"]) == 1
    assert res["impacts"][0]["bucket_id"] == "ps5"
    assert res["impacts"][0]["deducted_paise"] == 400000
    assert res["impacts"][0]["new_balance_paise"] == 300000


def test_waterfall_multi_bucket_overflow():
    b1 = Bucket("ps5", "PS5", 5000000, 700000, BucketType.WANT, 1)
    b2 = Bucket("shoes", "Shoes", 1000000, 500000, BucketType.WANT, 2)

    # Spend ₹10,000. Unallocated = ₹0.
    # Drains PS5 (₹7,000 -> 0), then Shoes (₹5,000 -> ₹2,000).
    res = ExternalSpendEngine.execute_waterfall(1000000, 0, [b1, b2])
    assert len(res["impacts"]) == 2
    assert res["impacts"][0]["bucket_id"] == "ps5"
    assert res["impacts"][0]["deducted_paise"] == 700000
    assert res["impacts"][0]["new_balance_paise"] == 0

    assert res["impacts"][1]["bucket_id"] == "shoes"
    assert res["impacts"][1]["deducted_paise"] == 300000
    assert res["impacts"][1]["new_balance_paise"] == 200000


def test_waterfall_wants_drained_before_needs():
    # b_need is Priority 3 NEED (₹3,000)
    # b_want is Priority 4 WANT (₹8,000)
    b_need = Bucket("bike", "Bike Service", 400000, 300000, BucketType.NEED, 3)
    b_want = Bucket("laptop", "Laptop", 8000000, 800000, BucketType.WANT, 4)

    # Spend ₹5,000. Unallocated = ₹0.
    res = ExternalSpendEngine.execute_waterfall(500000, 0, [b_need, b_want])
    assert len(res["impacts"]) == 1
    # Even though b_want priority 4 > b_need priority 3, b_want is a WANT, so it drains first!
    assert res["impacts"][0]["bucket_id"] == "laptop"
    assert res["impacts"][0]["deducted_paise"] == 500000


def test_waterfall_protected_bucket_strictly_preserved():
    b_protected = Bucket("rent", "Rent", 1000000, 1000000, BucketType.NEED, 5, is_protected=True)
    res = ExternalSpendEngine.execute_waterfall(500000, 0, [b_protected])
    assert len(res["impacts"]) == 0
    assert res["is_deficit"]
    assert res["remaining_deficit_paise"] == 500000
    assert res["new_unallocated_paise"] == -500000


# --- Incoming Money & Goal Analytics Tests ---
class IncomingMoneyEngine:
    @staticmethod
    def process_incoming(incoming_paise: int, current_unallocated_paise: int) -> Tuple[int, LedgerEntry]:
        if incoming_paise <= 0:
            raise ValueError("Incoming amount must be greater than 0.")
        new_unalloc = current_unallocated_paise + incoming_paise
        entry = LedgerEntry(
            id="inc_1",
            bucket_id=None,
            transaction_type=TransactionType.INCOME_DETECTED,
            amount_delta_paise=incoming_paise,
            balance_after_paise=new_unalloc,
        )
        return new_unalloc, entry


class GoalAnalyticsEngine:
    @staticmethod
    def analyze(target_paise: int, current_paise: int, days_remaining: Optional[int]):
        remaining = max(0, target_paise - current_paise)
        pct = min(100.0, (current_paise / target_paise * 100.0)) if target_paise > 0 else 100.0
        daily_req = None
        if days_remaining is not None and days_remaining > 0 and remaining > 0:
            daily_req = -(-remaining // days_remaining)  # Ceiling division
        return {
            "remaining_paise": remaining,
            "percentage_complete": round(pct, 1),
            "is_reached": current_paise >= target_paise,
            "daily_required_paise": daily_req,
        }


def test_incoming_money_credits_unallocated():
    new_unalloc, entry = IncomingMoneyEngine.process_incoming(2500000, 500000)
    assert new_unalloc == 3000000
    assert entry.amount_delta_paise == 2500000
    assert entry.transaction_type == TransactionType.INCOME_DETECTED
    assert entry.bucket_id is None


def test_goal_analytics_computations():
    # Target ₹80,000, current ₹32,000 (40%), 40 days left
    res = GoalAnalyticsEngine.analyze(8000000, 3200000, 40)
    assert res["remaining_paise"] == 4800000
    assert res["percentage_complete"] == 40.0
    assert not res["is_reached"]
    # Daily required: 48,000 / 40 = ₹1,200/day = 120,000 paise/day
    assert res["daily_required_paise"] == 120000

