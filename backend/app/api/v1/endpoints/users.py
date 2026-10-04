from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.models import User
from app.schemas.schemas import UserResponse

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
def get_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve profile of currently authenticated user."""
    device_count = len(current_user.devices)
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        is_active=current_user.is_active,
        device_count=device_count,
        created_at=current_user.created_at,
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_user_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Permanently delete user account and all associated metadata."""
    db.delete(current_user)
    db.commit()
    return None
