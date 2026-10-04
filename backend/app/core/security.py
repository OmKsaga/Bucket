import base64
import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional
import bcrypt

from app.core.config import settings


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against the bcrypt hash."""
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8"),
        )
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    """Generate bcrypt hash for a password with salt."""
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def _b64url_encode(data: bytes) -> str:
    """Base64url encode without padding."""
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")


def _b64url_decode(data: str) -> bytes:
    """Base64url decode with automatic padding calculation."""
    padding = 4 - (len(data) % 4)
    if padding != 4:
        data += "=" * padding
    return base64.urlsafe_b64decode(data)


def create_jwt_token(
    payload: Dict[str, Any],
    secret_key: str = settings.SECRET_KEY,
    algorithm: str = "HS256",
) -> str:
    """Create an RFC 7519 compliant HS256 JWT without external dependencies."""
    header = {"alg": algorithm, "typ": "JWT"}
    header_json = json.dumps(header, separators=(",", ":")).encode("utf-8")
    payload_json = json.dumps(payload, separators=(",", ":")).encode("utf-8")

    header_b64 = _b64url_encode(header_json)
    payload_b64 = _b64url_encode(payload_json)

    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
    signature = hmac.new(
        secret_key.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()
    signature_b64 = _b64url_encode(signature)

    return f"{header_b64}.{payload_b64}.{signature_b64}"


def decode_jwt_token(
    token: str,
    secret_key: str = settings.SECRET_KEY,
) -> Dict[str, Any]:
    """Decode and verify an RFC 7519 compliant HS256 JWT."""
    parts = token.strip().split(".")
    if len(parts) != 3:
        raise ValueError("Invalid JWT format: token must have 3 segments")

    header_b64, payload_b64, signature_b64 = parts
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")

    # Verify signature
    expected_sig = hmac.new(
        secret_key.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()
    actual_sig = _b64url_decode(signature_b64)

    if not hmac.compare_digest(expected_sig, actual_sig):
        raise ValueError("JWT signature verification failed")

    # Parse payload
    payload_raw = _b64url_decode(payload_b64)
    payload = json.loads(payload_raw.decode("utf-8"))

    # Verify expiration claim
    if "exp" in payload:
        now_ts = int(time.time())
        if now_ts > payload["exp"]:
            raise ValueError("JWT has expired")

    return payload


def create_access_token(
    subject: str,
    expires_delta: Optional[timedelta] = None,
    extra_claims: Optional[Dict[str, Any]] = None,
) -> str:
    """Create short-lived access token."""
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode: Dict[str, Any] = {
        "sub": str(subject),
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }
    if extra_claims:
        to_encode.update(extra_claims)

    return create_jwt_token(to_encode)


def create_refresh_token(
    subject: str,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create long-lived refresh token (default 30 days)."""
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(days=30)

    to_encode: Dict[str, Any] = {
        "sub": str(subject),
        "type": "refresh",
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }
    return create_jwt_token(to_encode)
