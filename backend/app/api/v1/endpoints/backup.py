from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.models import EncryptedBackup, User
from app.schemas.schemas import BackupCreateRequest, BackupResponse

router = APIRouter(prefix="/backup", tags=["backup"])


@router.post("/", response_model=BackupResponse, status_code=status.HTTP_201_CREATED)
def store_encrypted_backup(
    req: BackupCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Store an end-to-end encrypted backup blob.
    
    SECURITY INVARIANT:
    Zero-knowledge architecture. The backend only stores opaque ciphertext.
    Decryption keys are derived on the client device and never leave the device.
    """
    backup = EncryptedBackup(
        user_id=current_user.id,
        ciphertext=req.ciphertext,
        iv=req.iv,
        key_version=req.key_version,
    )
    db.add(backup)
    db.commit()
    db.refresh(backup)

    return BackupResponse(
        id=backup.id,
        ciphertext=backup.ciphertext,
        iv=backup.iv,
        key_version=backup.key_version,
        created_at=backup.created_at,
    )


@router.get("/latest", response_model=BackupResponse)
def get_latest_backup(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve the most recent encrypted backup blob for account restoration."""
    backup = (
        db.query(EncryptedBackup)
        .filter(EncryptedBackup.user_id == current_user.id)
        .order_by(EncryptedBackup.created_at.desc())
        .first()
    )
    if not backup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No backups found for this account",
        )

    return BackupResponse(
        id=backup.id,
        ciphertext=backup.ciphertext,
        iv=backup.iv,
        key_version=backup.key_version,
        created_at=backup.created_at,
    )
