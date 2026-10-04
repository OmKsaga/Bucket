from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.models import User
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["notifications"])


class NotificationTriggerRequest(BaseModel):
    title: str = Field(..., max_length=120)
    body: str = Field(..., max_length=250)


class NotificationTriggerResponse(BaseModel):
    success: bool
    devices_targeted: int
    message: str


@router.post("/trigger", response_model=NotificationTriggerResponse)
def trigger_notification(
    req: NotificationTriggerRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Test endpoint for triggering a simulated push notification to all devices
    registered under the authenticated user.
    """
    count = NotificationService.send_push_to_user(
        db=db,
        user_id=current_user.id,
        title=req.title,
        body=req.body,
    )

    return NotificationTriggerResponse(
        success=True,
        devices_targeted=count,
        message=f"Dispatched notification to {count} registered devices.",
    )
