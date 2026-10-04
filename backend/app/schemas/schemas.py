from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, ConfigDict, Field


# Health Check Schemas
class HealthCheckResponse(BaseModel):
    status: str
    service: str
    version: str
    timestamp: datetime


# Auth Schemas
class UserRegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, description="Minimum 8 characters")


class UserLoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class DeviceRegisterRequest(BaseModel):
    device_token: str
    platform: str = Field(default="android", description="android, ios, or web")


class DeviceResponse(BaseModel):
    id: str
    device_token: str
    platform: str
    registered_at: datetime
    last_seen_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserResponse(BaseModel):
    id: str
    email: EmailStr
    is_active: bool
    device_count: int = 0
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# Sync Metadata Schemas (Strictly Privacy-Preserving)
class SyncSessionRecordRequest(BaseModel):
    session_hash: str = Field(..., min_length=32, max_length=64, description="SHA-256 session hash")
    device_id: Optional[str] = None


class SyncSessionRecordResponse(BaseModel):
    id: str
    session_hash: str
    is_duplicate: bool
    sync_count: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# Payment Reference Schemas
class PaymentInitiateRequest(BaseModel):
    payee_vpa: str = Field(..., description="Payee VPA (e.g., merchant@upi)")
    payee_name: str = Field(..., description="Payee display name")
    amount_paise: int = Field(..., gt=0, description="Amount in integer paise (e.g. 50000 = Rs 500)")
    note: Optional[str] = Field(default="Bucket UPI Payment", description="Payment note")
    custom_ref: Optional[str] = None


class PaymentInitiateResponse(BaseModel):
    provider_ref: str
    payee_vpa: str
    payee_name: str
    amount_paise: int
    currency: str = "INR"
    status: str
    upi_intent_url: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PaymentStatusResponse(BaseModel):
    provider_ref: str
    status: str
    payee_vpa: str
    payee_name: str
    amount_paise: int
    currency: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# Encrypted Backup Schemas
class BackupCreateRequest(BaseModel):
    ciphertext: str = Field(..., description="Base64 encoded encrypted payload")
    iv: str = Field(..., description="Base64 encoded IV")
    key_version: int = 1


class BackupResponse(BaseModel):
    id: str
    ciphertext: str
    iv: str
    key_version: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# App Setting Schemas
class AppSettingRequest(BaseModel):
    key: str
    value: str


class AppSettingResponse(BaseModel):
    key: str
    value: str
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
