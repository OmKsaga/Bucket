from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.models import SyncSessionRecord, User
from app.schemas.schemas import SyncSessionRecordRequest, SyncSessionRecordResponse

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post(
    "/session",
    response_model=SyncSessionRecordResponse,
    status_code=status.HTTP_200_OK,
)
def record_sync_session(
    req: SyncSessionRecordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Record a reconciliation session hash for cross-device idempotency and deduplication.
    
    PRIVACY INVARIANT:
    This endpoint only accepts and stores the cryptographic hash of the reconciliation
    event. Zero bank balances, zero bucket amounts, and zero payee details are sent or stored.
    """
    existing_record = (
        db.query(SyncSessionRecord)
        .filter(
            SyncSessionRecord.user_id == current_user.id,
            SyncSessionRecord.session_hash == req.session_hash,
        )
        .first()
    )

    if existing_record:
        existing_record.sync_count += 1
        db.commit()
        db.refresh(existing_record)
        return SyncSessionRecordResponse(
            id=existing_record.id,
            session_hash=existing_record.session_hash,
            is_duplicate=True,
            sync_count=existing_record.sync_count,
            created_at=existing_record.created_at,
        )

    new_record = SyncSessionRecord(
        user_id=current_user.id,
        device_id=req.device_id,
        session_hash=req.session_hash,
        sync_count=1,
    )
    db.add(new_record)
    db.commit()
    db.refresh(new_record)

    return SyncSessionRecordResponse(
        id=new_record.id,
        session_hash=new_record.session_hash,
        is_duplicate=False,
        sync_count=1,
        created_at=new_record.created_at,
    )
