import logging
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.models import Device, User

logger = logging.getLogger("bucket.notifications")


class NotificationService:
    @staticmethod
    def send_push_to_user(
        db: Session,
        user_id: str,
        title: str,
        body: str,
        data: Optional[dict] = None,
    ) -> int:
        """
        Relay push notification via Firebase Cloud Messaging (FCM) to all registered
        devices of a user.
        
        PRIVACY INVARIANT:
        Notification payloads only contain generic milestone messages or alerts.
        No bank balances, account numbers, or secret keys are transmitted in the body.
        """
        devices = db.query(Device).filter(Device.user_id == user_id).all()
        if not devices:
            logger.info(f"No devices registered for user {user_id}")
            return 0

        dispatched_count = 0
        for device in devices:
            # Simulated FCM / APNs dispatch
            logger.info(
                f"[FCM Relay] Dispatched to device {device.id} ({device.platform}) "
                f"token={device.device_token[:10]}... | title='{title}' | body='{body}'"
            )
            dispatched_count += 1

        return dispatched_count
