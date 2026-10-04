import time
import urllib.parse
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.models import PaymentReference, User
from app.schemas.schemas import (
    PaymentInitiateRequest,
    PaymentInitiateResponse,
    PaymentStatusResponse,
)

router = APIRouter(prefix="/payments", tags=["payments"])


def generate_provider_reference() -> str:
    """Generate a unique UPI transaction reference (tr)."""
    ts = int(time.time())
    rand_suffix = uuid.uuid4().hex[:8].upper()
    return f"BCK{ts}{rand_suffix}"


def build_upi_intent_url(
    payee_vpa: str,
    payee_name: str,
    amount_paise: int,
    note: str,
    provider_ref: str,
) -> str:
    """
    Construct an NPCI-compliant UPI Intent URI.
    Format: upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...&tr=...
    """
    amount_rs = f"{amount_paise / 100:.2f}"
    params = {
        "pa": payee_vpa.strip(),
        "pn": payee_name.strip(),
        "am": amount_rs,
        "cu": "INR",
        "tn": note.strip() or "Bucket UPI Payment",
        "tr": provider_ref,
    }
    encoded_query = urllib.parse.urlencode(params)
    return f"upi://pay?{encoded_query}"


@router.post(
    "/initiate",
    response_model=PaymentInitiateResponse,
    status_code=status.HTTP_201_CREATED,
)
def initiate_payment(
    req: PaymentInitiateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Initiate a UPI payment reference and generate the standard NPCI intent URI.
    The client app launches this URI via Android Intent or iOS URL Scheme to trigger
    user-installed UPI apps (GPay, PhonePe, Paytm, BHIM).
    """
    provider_ref = req.custom_ref or generate_provider_reference()

    # Check for duplicate custom_ref
    existing = (
        db.query(PaymentReference)
        .filter(PaymentReference.provider_ref == provider_ref)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Payment reference {provider_ref} already exists",
        )

    upi_intent_url = build_upi_intent_url(
        payee_vpa=req.payee_vpa,
        payee_name=req.payee_name,
        amount_paise=req.amount_paise,
        note=req.note or "Bucket Payment",
        provider_ref=provider_ref,
    )

    record = PaymentReference(
        user_id=current_user.id,
        provider_ref=provider_ref,
        payee_vpa=req.payee_vpa,
        payee_name=req.payee_name,
        amount_paise=req.amount_paise,
        currency="INR",
        status="PENDING",
        upi_intent_url=upi_intent_url,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    return PaymentInitiateResponse(
        provider_ref=record.provider_ref,
        payee_vpa=record.payee_vpa,
        payee_name=record.payee_name,
        amount_paise=record.amount_paise,
        currency=record.currency,
        status=record.status,
        upi_intent_url=record.upi_intent_url,
        created_at=record.created_at,
    )


@router.get("/{provider_ref}/status", response_model=PaymentStatusResponse)
def get_payment_status(
    provider_ref: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Poll status of an initiated payment."""
    record = (
        db.query(PaymentReference)
        .filter(
            PaymentReference.provider_ref == provider_ref,
            PaymentReference.user_id == current_user.id,
        )
        .first()
    )
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment reference {provider_ref} not found",
        )

    return PaymentStatusResponse(
        provider_ref=record.provider_ref,
        status=record.status,
        payee_vpa=record.payee_vpa,
        payee_name=record.payee_name,
        amount_paise=record.amount_paise,
        currency=record.currency,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )


@router.post("/{provider_ref}/settle", response_model=PaymentStatusResponse)
def settle_payment_status(
    provider_ref: str,
    status_update: str = "SUCCESS",
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update status of a payment (used by webhooks / test harness)."""
    record = (
        db.query(PaymentReference)
        .filter(
            PaymentReference.provider_ref == provider_ref,
            PaymentReference.user_id == current_user.id,
        )
        .first()
    )
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment reference {provider_ref} not found",
        )

    if status_update not in ["SUCCESS", "FAILED", "PENDING"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid status. Must be SUCCESS, FAILED, or PENDING",
        )

    record.status = status_update
    record.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(record)

    return PaymentStatusResponse(
        provider_ref=record.provider_ref,
        status=record.status,
        payee_vpa=record.payee_vpa,
        payee_name=record.payee_name,
        amount_paise=record.amount_paise,
        currency=record.currency,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )
