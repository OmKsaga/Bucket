import os
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Bucket Backend API"
    VERSION: str = "0.4.0"
    API_V1_STR: str = "/api/v1"

    # Security
    SECRET_KEY: str = "dev_secret_key_change_in_production_f9103e5c9a0b"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Database: supports SQLite (local/test) and PostgreSQL (production/docker)
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "sqlite:///./bucket_dev.db",
    )

    # Environment & CORS
    ENVIRONMENT: str = "development"
    CORS_ORIGINS: List[str] = ["*"]

    # Rate Limiting
    RATE_LIMIT_REQUESTS_PER_MINUTE: int = 120

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
