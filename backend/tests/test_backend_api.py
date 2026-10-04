import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Setup test database
TEST_DB_FILE = "./test_api.db"
if os.path.exists(TEST_DB_FILE):
    os.remove(TEST_DB_FILE)

os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB_FILE}"

from app.main import app
from app.db.session import Base, get_db

engine = create_engine(
    f"sqlite:///{TEST_DB_FILE}",
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


def test_auth_registration_and_login():
    # 1. Register new user
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={"email": "alice@example.com", "password": "SuperSecretPassword123!"},
    )
    assert reg_resp.status_code == 201
    reg_data = reg_resp.json()
    assert "access_token" in reg_data
    assert "refresh_token" in reg_data
    assert reg_data["token_type"] == "bearer"

    # 2. Duplicate registration fails
    dup_resp = client.post(
        "/api/v1/auth/register",
        json={"email": "alice@example.com", "password": "AnotherPassword456!"},
    )
    assert dup_resp.status_code == 400

    # 3. Login with correct password
    login_resp = client.post(
        "/api/v1/auth/login",
        json={"email": "alice@example.com", "password": "SuperSecretPassword123!"},
    )
    assert login_resp.status_code == 200
    login_data = login_resp.json()
    assert "access_token" in login_data

    # 4. Login with wrong password fails
    fail_resp = client.post(
        "/api/v1/auth/login",
        json={"email": "alice@example.com", "password": "WrongPassword!"},
    )
    assert fail_resp.status_code == 401


def test_token_refresh():
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={"email": "bob@example.com", "password": "SuperSecretPassword123!"},
    )
    refresh_token = reg_resp.json()["refresh_token"]

    ref_resp = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert ref_resp.status_code == 200
    ref_data = ref_resp.json()
    assert "access_token" in ref_data
    assert "refresh_token" in ref_data


def test_device_registration_and_user_profile():
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={"email": "charlie@example.com", "password": "SuperSecretPassword123!"},
    )
    token = reg_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Register device
    dev_resp = client.post(
        "/api/v1/auth/device",
        json={"device_token": "fcm_token_sample_12345", "platform": "android"},
        headers=headers,
    )
    assert dev_resp.status_code == 200
    assert dev_resp.json()["device_token"] == "fcm_token_sample_12345"

    # Profile shows device_count == 1
    prof_resp = client.get("/api/v1/users/me", headers=headers)
    assert prof_resp.status_code == 200
    assert prof_resp.json()["email"] == "charlie@example.com"
    assert prof_resp.json()["device_count"] == 1


def test_sync_session_deduplication():
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={"email": "david@example.com", "password": "SuperSecretPassword123!"},
    )
    token = reg_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    session_hash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    # 1st sync commit
    sync1 = client.post(
        "/api/v1/sync/session",
        json={"session_hash": session_hash, "device_id": "pixel-8-pro"},
        headers=headers,
    )
    assert sync1.status_code == 200
    assert sync1.json()["is_duplicate"] is False
    assert sync1.json()["sync_count"] == 1

    # 2nd sync commit with identical hash -> detected as duplicate
    sync2 = client.post(
        "/api/v1/sync/session",
        json={"session_hash": session_hash, "device_id": "pixel-8-pro"},
        headers=headers,
    )
    assert sync2.status_code == 200
    assert sync2.json()["is_duplicate"] is True
    assert sync2.json()["sync_count"] == 2


def test_payment_initiation_and_status():
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={"email": "eva@example.com", "password": "SuperSecretPassword123!"},
    )
    token = reg_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Initiate UPI payment of Rs. 450.50 (45050 paise)
    pay_resp = client.post(
        "/api/v1/payments/initiate",
        json={
            "payee_vpa": "merchant@icici",
            "payee_name": "Organic Grocery Store",
            "amount_paise": 45050,
            "note": "Weekly vegetables",
        },
        headers=headers,
    )
    assert pay_resp.status_code == 201
    pay_data = pay_resp.json()
    provider_ref = pay_data["provider_ref"]
    assert pay_data["status"] == "PENDING"
    assert pay_data["amount_paise"] == 45050
    assert "upi://pay?" in pay_data["upi_intent_url"]
    assert "pa=merchant%40icici" in pay_data["upi_intent_url"]
    assert "am=450.50" in pay_data["upi_intent_url"]

    # Poll status
    status_resp = client.get(f"/api/v1/payments/{provider_ref}/status", headers=headers)
    assert status_resp.status_code == 200
    assert status_resp.json()["status"] == "PENDING"

    # Settle payment
    settle_resp = client.post(
        f"/api/v1/payments/{provider_ref}/settle?status_update=SUCCESS",
        headers=headers,
    )
    assert settle_resp.status_code == 200
    assert settle_resp.json()["status"] == "SUCCESS"


def test_client_encrypted_backup():
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={"email": "frank@example.com", "password": "SuperSecretPassword123!"},
    )
    token = reg_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Upload backup
    backup_resp = client.post(
        "/api/v1/backup/",
        json={
            "ciphertext": "U2FsdGVkX19+opaque_client_encrypted_data==",
            "iv": "dGVzdF9pdl8xMjM0NQ==",
            "key_version": 1,
        },
        headers=headers,
    )
    assert backup_resp.status_code == 201
    assert "id" in backup_resp.json()

    # Retrieve latest backup
    get_resp = client.get("/api/v1/backup/latest", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["ciphertext"] == "U2FsdGVkX19+opaque_client_encrypted_data=="
    assert get_resp.json()["key_version"] == 1


def test_user_settings():
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={"email": "grace@example.com", "password": "SuperSecretPassword123!"},
    )
    token = reg_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Set theme setting
    set_resp = client.put(
        "/api/v1/settings/",
        json={"key": "theme_mode", "value": "dark"},
        headers=headers,
    )
    assert set_resp.status_code == 200
    assert set_resp.json()["key"] == "theme_mode"
    assert set_resp.json()["value"] == "dark"

    # List settings
    list_resp = client.get("/api/v1/settings/", headers=headers)
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1
    assert list_resp.json()[0]["key"] == "theme_mode"
