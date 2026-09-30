from pydantic import BaseModel, EmailStr, ConfigDict
from datetime import datetime
from uuid import UUID
from typing import Optional

# Health Check Schemas
class HealthCheckResponse(BaseModel):
    status: str
    service: str
    version: str
    timestamp: datetime

# User Schemas
class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: UUID
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# Token Schemas
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class TokenPayload(BaseModel):
    sub: Optional[str] = None

# Sync Session Metadata Schemas (No financial data!)
class SyncSessionDedupRequest(BaseModel):
    session_hash: str

class SyncSessionDedupResponse(BaseModel):
    is_duplicate: bool
    session_hash: str
