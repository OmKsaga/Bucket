import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from app.db.session import Base


def get_utc_now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=get_utc_now, nullable=False)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now, nullable=False)

    # Relationships
    devices = relationship("Device", back_populates="user", cascade="all, delete-orphan")
    sync_sessions = relationship("SyncSessionRecord", back_populates="user", cascade="all, delete-orphan")
    payment_references = relationship("PaymentReference", back_populates="user", cascade="all, delete-orphan")
    backups = relationship("EncryptedBackup", back_populates="user", cascade="all, delete-orphan")
    settings = relationship("AppSetting", back_populates="user", cascade="all, delete-orphan")


class Device(Base):
    __tablename__ = "devices"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    device_token = Column(String(512), nullable=False)
    platform = Column(String(32), default="android", nullable=False)
    registered_at = Column(DateTime, default=get_utc_now, nullable=False)
    last_seen_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now, nullable=False)

    user = relationship("User", back_populates="devices")


class SyncSessionRecord(Base):
    """
    Stores sync session hashes for cross-device idempotency and deduplication.
    CRITICAL PRIVACY INVARIANT:
    Zero balances, bucket totals, or transaction line items are stored here.
    Only the SHA-256 session hash and audit metadata.
    """
    __tablename__ = "sync_sessions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    device_id = Column(String(36), nullable=True)
    session_hash = Column(String(64), nullable=False, index=True)
    sync_count = Column(Integer, default=1, nullable=False)
    created_at = Column(DateTime, default=get_utc_now, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "session_hash", name="uq_user_session_hash"),
    )

    user = relationship("User", back_populates="sync_sessions")


class PaymentReference(Base):
    """
    UPI Payment intent reference record.
    Tracks state of a payment initiated via the app for reconciliation matching.
    """
    __tablename__ = "payment_references"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    provider_ref = Column(String(64), unique=True, index=True, nullable=False)
    payee_vpa = Column(String(128), nullable=False)
    payee_name = Column(String(255), nullable=False)
    amount_paise = Column(Integer, nullable=False)
    currency = Column(String(8), default="INR", nullable=False)
    status = Column(String(32), default="PENDING", nullable=False)  # PENDING, SUCCESS, FAILED
    upi_intent_url = Column(Text, nullable=False)
    created_at = Column(DateTime, default=get_utc_now, nullable=False)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now, nullable=False)

    user = relationship("User", back_populates="payment_references")


class EncryptedBackup(Base):
    """
    Zero-knowledge client-side encrypted backup blob.
    Backend only stores the ciphertext and initialization vector; it cannot decrypt it.
    """
    __tablename__ = "encrypted_backups"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    ciphertext = Column(Text, nullable=False)
    iv = Column(String(128), nullable=False)
    key_version = Column(Integer, default=1, nullable=False)
    created_at = Column(DateTime, default=get_utc_now, nullable=False)

    user = relationship("User", back_populates="backups")


class AppSetting(Base):
    __tablename__ = "app_settings"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    key = Column(String(128), nullable=False)
    value = Column(Text, nullable=False)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "key", name="uq_user_setting_key"),
    )

    user = relationship("User", back_populates="settings")
