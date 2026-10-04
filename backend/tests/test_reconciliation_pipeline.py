"""
Verification test suite for Reconciliation pipeline, session hashing, and idempotency logic.
"""
import hashlib
from datetime import datetime, timezone
from typing import Dict, List, Optional
from dataclasses import dataclass, field


def compute_session_hash(account_id: str, balance_paise: int, timestamp: datetime) -> str:
    # 10-second window quantization
    window = int(timestamp.timestamp() // 10) * 10
    payload = f"{account_id}:{balance_paise}:{window}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


class MockSyncSessionStore:
    def __init__(self):
        self.processed_hashes = set()

    def record_session(self, session_hash: str) -> None:
        self.processed_hashes.add(session_hash)

    def is_processed(self, session_hash: str) -> bool:
        return session_hash in self.processed_hashes


def test_session_hashing_deterministic():
    t = datetime(2026, 10, 1, 12, 0, 0, tzinfo=timezone.utc)
    h1 = compute_session_hash("acc_1", 3000000, t)
    h2 = compute_session_hash("acc_1", 3000000, t)
    assert h1 == h2
    assert len(h1) == 64  # SHA-256 hex string


def test_session_hashing_window_quantization():
    t1 = datetime(2026, 10, 1, 12, 0, 1, tzinfo=timezone.utc)
    t2 = datetime(2026, 10, 1, 12, 0, 8, tzinfo=timezone.utc)  # Within 10-second bucket
    h1 = compute_session_hash("acc_1", 3000000, t1)
    h2 = compute_session_hash("acc_1", 3000000, t2)
    assert h1 == h2  # Quantized to same bucket!


def test_session_hashing_distinct_balances():
    t = datetime(2026, 10, 1, 12, 0, 0, tzinfo=timezone.utc)
    h1 = compute_session_hash("acc_1", 3000000, t)
    h2 = compute_session_hash("acc_1", 2400000, t)
    assert h1 != h2


def test_idempotency_store():
    store = MockSyncSessionStore()
    h = compute_session_hash("acc_1", 3000000, datetime.now(timezone.utc))

    assert not store.is_processed(h)
    store.record_session(h)
    assert store.is_processed(h)


def test_reconciliation_difference_classification():
    def classify_delta(prev_bal: int, curr_bal: int, is_refund: bool = False) -> str:
        diff = curr_bal - prev_bal
        if diff == 0:
            return "NO_CHANGE"
        elif diff < 0:
            return "EXTERNAL_SPEND"
        elif is_refund:
            return "REFUND"
        else:
            return "INCOMING_FUNDS"

    assert classify_delta(30000, 30000) == "NO_CHANGE"
    assert classify_delta(30000, 24000) == "EXTERNAL_SPEND"
    assert classify_delta(20000, 25000) == "INCOMING_FUNDS"
    assert classify_delta(20000, 22000, is_refund=True) == "REFUND"
