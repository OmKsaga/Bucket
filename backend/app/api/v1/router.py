from fastapi import APIRouter
from app.api.v1.endpoints import (
    auth,
    backup,
    health,
    payments,
    settings,
    sync,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(sync.router)
api_router.include_router(payments.router)
api_router.include_router(backup.router)
api_router.include_router(settings.router)
