from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.models import AppSetting, User
from app.schemas.schemas import AppSettingRequest, AppSettingResponse

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("/", response_model=List[AppSettingResponse])
def get_user_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve all synchronized non-sensitive app settings for current user."""
    settings_list = (
        db.query(AppSetting)
        .filter(AppSetting.user_id == current_user.id)
        .all()
    )
    return settings_list


@router.put("/", response_model=AppSettingResponse)
def set_user_setting(
    req: AppSettingRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create or update a non-sensitive configuration preference."""
    setting = (
        db.query(AppSetting)
        .filter(
            AppSetting.user_id == current_user.id,
            AppSetting.key == req.key,
        )
        .first()
    )

    if setting:
        setting.value = req.value
    else:
        setting = AppSetting(
            user_id=current_user.id,
            key=req.key,
            value=req.value,
        )
        db.add(setting)

    db.commit()
    db.refresh(setting)
    return setting
