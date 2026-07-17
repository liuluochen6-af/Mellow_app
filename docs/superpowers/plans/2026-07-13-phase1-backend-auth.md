# Phase 1: Backend Infrastructure + User Auth — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Python FastAPI backend with PostgreSQL on Alibaba Cloud, implement user registration/login (phone SMS + Sign in with Apple), and build the iOS app shell with login flow and authenticated tab bar.

**Architecture:** FastAPI REST backend on Alibaba Cloud ECS with PostgreSQL. iOS SwiftUI app communicates over HTTPS. Auth uses simple long-lived tokens (90 days) stored in iOS Keychain. SMS via Alibaba Cloud SMS service.

**Tech Stack:** Python 3.11+, FastAPI, SQLAlchemy 2.0, PostgreSQL 15, Alembic (migrations), pytest; Swift 5.9+, SwiftUI, iOS 17+

## Global Constraints

- iOS deployment target: 17.0
- Python: 3.11+
- All API responses use JSON
- All endpoints require HTTPS (enforced by iOS ATS)
- Auth token: random 64-char hex string, 90-day expiry
- Rate limit on SMS send: max 1 per 60 seconds per phone number
- Rate limit on search: max 10 per minute per user
- No ORM lazy loading — all queries explicit

---

## File Structure

### Backend

```
backend/
├── requirements.txt
├── .env.example
├── alembic.ini
├── alembic/
│   ├── env.py
│   └── versions/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── models/
│   │   ├── __init__.py
│   │   └── user.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   └── auth.py
│   ├── routers/
│   │   ├── __init__.py
│   │   └── auth.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   └── sms.py
│   └── dependencies.py
└── tests/
    ├── __init__.py
    ├── conftest.py
    └── test_auth.py
```

### iOS

```
FoodCheckin/
├── FoodCheckin.xcodeproj/
├── FoodCheckin/
│   ├── FoodCheckinApp.swift
│   ├── ContentView.swift
│   ├── Models/
│   │   └── User.swift
│   ├── Views/
│   │   └── Auth/
│   │       ├── LoginView.swift
│   │       └── PhoneLoginView.swift
│   ├── Services/
│   │   ├── APIClient.swift
│   │   └── AuthService.swift
│   └── Utils/
│       └── KeychainHelper.swift
└── FoodCheckinTests/
    └── FoodCheckinTests.swift
```

---

## Task 1: Backend Project Setup + Database + User Model

**Files:**
- Create: `backend/requirements.txt`
- Create: `backend/.env.example`
- Create: `backend/app/__init__.py`
- Create: `backend/app/main.py`
- Create: `backend/app/config.py`
- Create: `backend/app/database.py`
- Create: `backend/app/models/__init__.py`
- Create: `backend/app/models/user.py`
- Create: `backend/alembic.ini`
- Create: `backend/alembic/env.py`
- Create: `backend/tests/__init__.py`
- Create: `backend/tests/conftest.py`
- Create: `backend/tests/test_auth.py`

**Interfaces:**
- Produces: `get_db()` → yields SQLAlchemy `AsyncSession`
- Produces: `User` model with fields: id, nickname, avatar_url, phone, apple_id, token, token_expires_at, created_at
- Produces: `settings` object with DATABASE_URL, SMS_ACCESS_KEY, SMS_SECRET, SMS_SIGN_NAME, SMS_TEMPLATE_CODE

---

- [ ] **Step 1: Create requirements.txt**

```
backend/requirements.txt
```

```text
fastapi==0.111.0
uvicorn[standard]==0.30.1
sqlalchemy[asyncio]==2.0.30
asyncpg==0.29.0
alembic==1.13.1
pydantic-settings==2.3.1
python-jose==3.3.0
httpx==0.27.0
pytest==8.2.2
pytest-asyncio==0.23.7
```

- [ ] **Step 2: Create .env.example**

```
backend/.env.example
```

```text
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/foodcheckin
SMS_ACCESS_KEY_ID=your_aliyun_access_key
SMS_ACCESS_KEY_SECRET=your_aliyun_secret
SMS_SIGN_NAME=your_sms_sign
SMS_TEMPLATE_CODE=your_template_code
SECRET_KEY=your_random_secret_key_at_least_32_chars
```

- [ ] **Step 3: Create app/config.py**

```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    sms_access_key_id: str = ""
    sms_access_key_secret: str = ""
    sms_sign_name: str = ""
    sms_template_code: str = ""
    secret_key: str = "dev-secret-key-change-in-production"

    class Config:
        env_file = ".env"


settings = Settings()
```

- [ ] **Step 4: Create app/database.py**

```python
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine, AsyncSession
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

engine = create_async_engine(settings.database_url)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with async_session() as session:
        yield session
```

- [ ] **Step 5: Create app/models/user.py**

```python
import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nickname: Mapped[str] = mapped_column(String(50), default="")
    avatar_url: Mapped[str] = mapped_column(String(500), default="")
    phone: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True)
    apple_id: Mapped[str | None] = mapped_column(String(200), unique=True, nullable=True)
    token: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    token_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 6: Create app/models/__init__.py**

```python
from app.models.user import User

__all__ = ["User"]
```

- [ ] **Step 7: Create app/main.py**

```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI(title="FoodCheckIn API")

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


@app.get("/health")
async def health():
    return {"status": "ok"}
```

- [ ] **Step 8: Create app/__init__.py**

```python
```

(Empty file)

- [ ] **Step 9: Set up Alembic for migrations**

Create `backend/alembic.ini`:
```ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql+asyncpg://postgres:password@localhost:5432/foodcheckin

[loggers]
keys = root

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console

[handler_console]
class = StreamHandler
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
```

Create `backend/alembic/env.py`:
```python
import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine

from app.config import settings
from app.database import Base
from app.models import User  # noqa: F401

config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline():
    context.configure(url=settings.database_url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online():
    connectable = create_async_engine(settings.database_url)
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
```

- [ ] **Step 10: Create test fixtures**

Create `backend/tests/__init__.py` (empty).

Create `backend/tests/conftest.py`:
```python
import asyncio
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.database import Base, get_db
from app.main import app

TEST_DATABASE_URL = "postgresql+asyncpg://postgres:password@localhost:5432/foodcheckin_test"

engine_test = create_async_engine(TEST_DATABASE_URL)
async_session_test = async_sessionmaker(engine_test, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(autouse=True)
async def setup_db():
    async with engine_test.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine_test.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


async def override_get_db():
    async with async_session_test() as session:
        yield session


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
```

- [ ] **Step 11: Write health check test**

Create `backend/tests/test_auth.py`:
```python
import pytest


@pytest.mark.asyncio
async def test_health(client):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

- [ ] **Step 12: Run test to verify setup works**

```bash
cd backend
pip install -r requirements.txt
createdb foodcheckin_test  # PostgreSQL must be running
pytest tests/test_auth.py::test_health -v
```

Expected: PASS

- [ ] **Step 13: Generate initial migration**

```bash
cd backend
alembic revision --autogenerate -m "create users table"
alembic upgrade head
```

- [ ] **Step 14: Commit**

```bash
git init
git add .
git commit -m "feat: backend project setup with FastAPI, PostgreSQL, User model"
```

---

## Task 2: SMS Verification + Phone Login/Register

**Files:**
- Create: `backend/app/services/sms.py`
- Create: `backend/app/services/auth.py`
- Create: `backend/app/schemas/__init__.py`
- Create: `backend/app/schemas/auth.py`
- Create: `backend/app/routers/__init__.py`
- Create: `backend/app/routers/auth.py`
- Modify: `backend/app/main.py` (add router)
- Modify: `backend/tests/test_auth.py` (add tests)

**Interfaces:**
- Consumes: `get_db()` from Task 1, `User` model from Task 1, `settings` from Task 1
- Produces: `POST /api/auth/send-code` — sends SMS code, returns `{"message": "ok"}`
- Produces: `POST /api/auth/phone-login` — verifies code, returns `{"token": "...", "user": {...}}`
- Produces: `generate_token()` → 64-char hex string
- Produces: SMS code stored in memory dict (dev) with 5-min expiry

---

- [ ] **Step 1: Create app/services/sms.py**

```python
import hashlib
import hmac
import time
import urllib.parse
import base64
from datetime import datetime, timezone
import uuid

import httpx

from app.config import settings

# In-memory verification code store (production: use Redis)
_code_store: dict[str, tuple[str, float]] = {}  # phone -> (code, expire_timestamp)


def _generate_code() -> str:
    return str(uuid.uuid4().int)[:6]


async def send_verification_code(phone: str) -> str:
    code = _generate_code()
    _code_store[phone] = (code, time.time() + 300)  # 5 min expiry

    if not settings.sms_access_key_id:
        # Dev mode: skip actual SMS, print code
        print(f"[DEV] SMS code for {phone}: {code}")
        return code

    # Alibaba Cloud SMS API call
    params = {
        "PhoneNumbers": phone,
        "SignName": settings.sms_sign_name,
        "TemplateCode": settings.sms_template_code,
        "TemplateParam": f'{{"code":"{code}"}}',
        "Action": "SendSms",
        "Version": "2017-05-25",
        "Format": "JSON",
        "SignatureMethod": "HMAC-SHA1",
        "SignatureVersion": "1.0",
        "SignatureNonce": str(uuid.uuid4()),
        "Timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "AccessKeyId": settings.sms_access_key_id,
    }

    sorted_params = sorted(params.items())
    query_string = urllib.parse.urlencode(sorted_params, quote_via=urllib.parse.quote)
    string_to_sign = f"GET&%2F&{urllib.parse.quote(query_string, safe='')}"

    sign_key = f"{settings.sms_access_key_secret}&"
    signature = base64.b64encode(
        hmac.new(sign_key.encode(), string_to_sign.encode(), hashlib.sha1).digest()
    ).decode()
    params["Signature"] = signature

    async with httpx.AsyncClient() as client:
        await client.get("https://dysmsapi.aliyuncs.com/", params=params)

    return code


def verify_code(phone: str, code: str) -> bool:
    stored = _code_store.get(phone)
    if not stored:
        return False
    stored_code, expire_time = stored
    if time.time() > expire_time:
        del _code_store[phone]
        return False
    if stored_code != code:
        return False
    del _code_store[phone]
    return True


def get_last_send_time(phone: str) -> float | None:
    stored = _code_store.get(phone)
    if stored:
        _, expire_time = stored
        return expire_time - 300  # sent_time = expire - 5min
    return None
```

- [ ] **Step 2: Create app/services/auth.py**

```python
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


def generate_token() -> str:
    return secrets.token_hex(32)


def token_expiry() -> datetime:
    return datetime.now(timezone.utc) + timedelta(days=90)


async def get_or_create_user_by_phone(db: AsyncSession, phone: str) -> User:
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()

    if user:
        user.token = generate_token()
        user.token_expires_at = token_expiry()
    else:
        user = User(
            phone=phone,
            nickname=f"用户{phone[-4:]}",
            token=generate_token(),
            token_expires_at=token_expiry(),
        )
        db.add(user)

    await db.commit()
    await db.refresh(user)
    return user


async def get_or_create_user_by_apple_id(db: AsyncSession, apple_id: str, nickname: str = "") -> User:
    result = await db.execute(select(User).where(User.apple_id == apple_id))
    user = result.scalar_one_or_none()

    if user:
        user.token = generate_token()
        user.token_expires_at = token_expiry()
    else:
        user = User(
            apple_id=apple_id,
            nickname=nickname or "Apple 用户",
            token=generate_token(),
            token_expires_at=token_expiry(),
        )
        db.add(user)

    await db.commit()
    await db.refresh(user)
    return user


async def get_user_by_token(db: AsyncSession, token: str) -> User | None:
    result = await db.execute(select(User).where(User.token == token))
    user = result.scalar_one_or_none()
    if user and user.token_expires_at < datetime.now(timezone.utc):
        return None
    return user
```

- [ ] **Step 3: Create app/schemas/auth.py**

Create `backend/app/schemas/__init__.py` (empty).

```python
from pydantic import BaseModel
import uuid
from datetime import datetime


class SendCodeRequest(BaseModel):
    phone: str


class PhoneLoginRequest(BaseModel):
    phone: str
    code: str


class AppleLoginRequest(BaseModel):
    apple_id: str
    nickname: str = ""


class UserResponse(BaseModel):
    id: uuid.UUID
    nickname: str
    avatar_url: str
    phone: str | None
    created_at: datetime


class LoginResponse(BaseModel):
    token: str
    user: UserResponse
```

- [ ] **Step 4: Create app/routers/auth.py**

Create `backend/app/routers/__init__.py` (empty).

```python
import time

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.auth import (
    SendCodeRequest,
    PhoneLoginRequest,
    AppleLoginRequest,
    LoginResponse,
    UserResponse,
)
from app.services.sms import send_verification_code, verify_code, get_last_send_time
from app.services.auth import get_or_create_user_by_phone, get_or_create_user_by_apple_id

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/send-code")
async def send_code(req: SendCodeRequest):
    last_send = get_last_send_time(req.phone)
    if last_send and time.time() - last_send < 60:
        raise HTTPException(status_code=429, detail="请等待60秒后再发送")

    await send_verification_code(req.phone)
    return {"message": "ok"}


@router.post("/phone-login", response_model=LoginResponse)
async def phone_login(req: PhoneLoginRequest, db: AsyncSession = Depends(get_db)):
    if not verify_code(req.phone, req.code):
        raise HTTPException(status_code=400, detail="验证码错误或已过期")

    user = await get_or_create_user_by_phone(db, req.phone)
    return LoginResponse(
        token=user.token,
        user=UserResponse(
            id=user.id,
            nickname=user.nickname,
            avatar_url=user.avatar_url,
            phone=user.phone,
            created_at=user.created_at,
        ),
    )


@router.post("/apple-login", response_model=LoginResponse)
async def apple_login(req: AppleLoginRequest, db: AsyncSession = Depends(get_db)):
    user = await get_or_create_user_by_apple_id(db, req.apple_id, req.nickname)
    return LoginResponse(
        token=user.token,
        user=UserResponse(
            id=user.id,
            nickname=user.nickname,
            avatar_url=user.avatar_url,
            phone=user.phone,
            created_at=user.created_at,
        ),
    )
```

- [ ] **Step 5: Register router in main.py**

Modify `backend/app/main.py`:
```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import os

from app.routers.auth import router as auth_router

app = FastAPI(title="FoodCheckIn API")

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(auth_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
```

- [ ] **Step 6: Write auth endpoint tests**

Append to `backend/tests/test_auth.py`:
```python
import pytest
from app.services.sms import _code_store


@pytest.mark.asyncio
async def test_send_code(client):
    response = await client.post("/api/auth/send-code", json={"phone": "13800138000"})
    assert response.status_code == 200
    assert response.json() == {"message": "ok"}
    assert "13800138000" in _code_store


@pytest.mark.asyncio
async def test_send_code_rate_limit(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138001"})
    response = await client.post("/api/auth/send-code", json={"phone": "13800138001"})
    assert response.status_code == 429


@pytest.mark.asyncio
async def test_phone_login_success(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138002"})
    code = _code_store["13800138002"][0]

    response = await client.post("/api/auth/phone-login", json={"phone": "13800138002", "code": code})
    assert response.status_code == 200
    data = response.json()
    assert "token" in data
    assert data["user"]["phone"] == "13800138002"
    assert data["user"]["nickname"] == "用户8002"


@pytest.mark.asyncio
async def test_phone_login_wrong_code(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138003"})
    response = await client.post("/api/auth/phone-login", json={"phone": "13800138003", "code": "000000"})
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_apple_login(client):
    response = await client.post("/api/auth/apple-login", json={"apple_id": "apple_test_123", "nickname": "Test"})
    assert response.status_code == 200
    data = response.json()
    assert "token" in data
    assert data["user"]["nickname"] == "Test"


@pytest.mark.asyncio
async def test_apple_login_existing_user(client):
    await client.post("/api/auth/apple-login", json={"apple_id": "apple_repeat", "nickname": "First"})
    response = await client.post("/api/auth/apple-login", json={"apple_id": "apple_repeat", "nickname": "Second"})
    assert response.status_code == 200
    assert response.json()["user"]["nickname"] == "First"
```

- [ ] **Step 7: Run tests**

```bash
cd backend
pytest tests/test_auth.py -v
```

Expected: All 7 tests PASS

- [ ] **Step 8: Commit**

```bash
git add .
git commit -m "feat: add phone SMS and Apple login auth endpoints with tests"
```

---

## Task 3: Auth Middleware + Profile Endpoint

**Files:**
- Create: `backend/app/dependencies.py`
- Modify: `backend/app/routers/auth.py` (add /me and /delete-account)
- Modify: `backend/tests/test_auth.py` (add tests)

**Interfaces:**
- Consumes: `get_user_by_token()` from Task 2, `get_db()` from Task 1
- Produces: `get_current_user` dependency → returns authenticated `User` or raises 401
- Produces: `GET /api/auth/me` → returns current user profile
- Produces: `DELETE /api/auth/delete-account` → hard deletes user and all data

---

- [ ] **Step 1: Create app/dependencies.py**

```python
from fastapi import Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.services.auth import get_user_by_token


async def get_current_user(
    authorization: str = Header(...),
    db: AsyncSession = Depends(get_db),
) -> User:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="无效的认证格式")

    token = authorization[7:]
    user = await get_user_by_token(db, token)
    if not user:
        raise HTTPException(status_code=401, detail="Token无效或已过期")
    return user
```

- [ ] **Step 2: Add /me and /delete-account endpoints**

Append to `backend/app/routers/auth.py`:
```python
from app.dependencies import get_current_user
from app.models.user import User


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=current_user.id,
        nickname=current_user.nickname,
        avatar_url=current_user.avatar_url,
        phone=current_user.phone,
        created_at=current_user.created_at,
    )


@router.delete("/delete-account")
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.delete(current_user)
    await db.commit()
    return {"message": "账号已删除"}
```

- [ ] **Step 3: Write tests for auth middleware**

Append to `backend/tests/test_auth.py`:
```python
@pytest.mark.asyncio
async def test_get_me_success(client):
    # Login first
    await client.post("/api/auth/send-code", json={"phone": "13800138010"})
    code = _code_store["13800138010"][0]
    login_resp = await client.post("/api/auth/phone-login", json={"phone": "13800138010", "code": code})
    token = login_resp.json()["token"]

    # Get profile
    response = await client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["phone"] == "13800138010"


@pytest.mark.asyncio
async def test_get_me_no_token(client):
    response = await client.get("/api/auth/me")
    assert response.status_code == 422  # missing header


@pytest.mark.asyncio
async def test_get_me_invalid_token(client):
    response = await client.get("/api/auth/me", headers={"Authorization": "Bearer invalid_token"})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_delete_account(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138011"})
    code = _code_store["13800138011"][0]
    login_resp = await client.post("/api/auth/phone-login", json={"phone": "13800138011", "code": code})
    token = login_resp.json()["token"]

    # Delete
    response = await client.delete("/api/auth/delete-account", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200

    # Verify deleted
    response = await client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401
```

- [ ] **Step 4: Run all tests**

```bash
cd backend
pytest tests/test_auth.py -v
```

Expected: All 11 tests PASS

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add auth middleware, /me endpoint, and account deletion"
```

---

## Task 4: iOS Project Creation + Network Layer

**Files:**
- Create: Xcode project `FoodCheckin` (SwiftUI, iOS 17)
- Create: `FoodCheckin/Services/APIClient.swift`
- Create: `FoodCheckin/Utils/KeychainHelper.swift`
- Create: `FoodCheckin/Models/User.swift`

**Interfaces:**
- Produces: `APIClient` class with methods: `post(_:body:)`, `get(_:)`, `delete(_:)`, all returning `Data`
- Produces: `KeychainHelper` with `save(token:)`, `getToken()`, `deleteToken()`
- Produces: `UserProfile` struct matching server's `UserResponse`

---

- [ ] **Step 1: Create Xcode project**

Open Xcode → File → New → Project → iOS → App
- Product Name: `FoodCheckin`
- Organization Identifier: your bundle id prefix (e.g. `com.yourname`)
- Interface: SwiftUI
- Language: Swift
- Storage: None (we'll add SwiftData later)
- Minimum Deployments: iOS 17.0

Save in `/Users/lris/Projects/food/`

- [ ] **Step 2: Create Utils/KeychainHelper.swift**

```swift
import Foundation
import Security

enum KeychainHelper {
    private static let tokenKey = "com.foodcheckin.auth-token"

    static func save(token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 3: Create Models/User.swift**

```swift
import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let nickname: String
    let avatarUrl: String
    let phone: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, nickname, phone
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct LoginResponse: Codable {
    let token: String
    let user: UserProfile
}
```

- [ ] **Step 4: Create Services/APIClient.swift**

```swift
import Foundation

enum APIError: Error {
    case invalidURL
    case unauthorized
    case serverError(Int, String)
    case networkError(Error)
}

class APIClient {
    static let shared = APIClient()

    // Change this to your server URL
    private let baseURL = "https://your-domain.com"

    private init() {}

    func post(_ path: String, body: Encodable) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainHelper.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    func get(_ path: String) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = KeychainHelper.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    func delete(_ path: String) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = KeychainHelper.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 {
            KeychainHelper.deleteToken()
            throw APIError.unauthorized
        }
        if http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(http.statusCode, message)
        }
    }
}
```

- [ ] **Step 5: Verify project builds**

In Xcode: Product → Build (Cmd+B)

Expected: Build Succeeded

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "feat: iOS project setup with APIClient and KeychainHelper"
```

---

## Task 5: iOS Auth Service + Login UI

**Files:**
- Create: `FoodCheckin/Services/AuthService.swift`
- Create: `FoodCheckin/Views/Auth/LoginView.swift`
- Create: `FoodCheckin/Views/Auth/PhoneLoginView.swift`
- Modify: `FoodCheckin/FoodCheckinApp.swift`

**Interfaces:**
- Consumes: `APIClient` from Task 4, `KeychainHelper` from Task 4, `LoginResponse` from Task 4
- Produces: `AuthService` ObservableObject with `isLoggedIn`, `sendCode()`, `phoneLogin()`, `appleLogin()`, `logout()`
- Produces: `LoginView` — entry screen with Apple login button and phone login option
- Produces: `PhoneLoginView` — phone number input + code verification

---

- [ ] **Step 1: Create Services/AuthService.swift**

```swift
import Foundation
import AuthenticationServices

struct SendCodeBody: Encodable {
    let phone: String
}

struct PhoneLoginBody: Encodable {
    let phone: String
    let code: String
}

struct AppleLoginBody: Encodable {
    let apple_id: String
    let nickname: String
}

@MainActor
class AuthService: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: UserProfile?
    @Published var errorMessage: String?

    init() {
        isLoggedIn = KeychainHelper.getToken() != nil
    }

    func sendCode(phone: String) async -> Bool {
        do {
            let body = SendCodeBody(phone: phone)
            _ = try await APIClient.shared.post("/api/auth/send-code", body: body)
            return true
        } catch let APIError.serverError(_, message) {
            errorMessage = message
            return false
        } catch {
            errorMessage = "网络错误，请重试"
            return false
        }
    }

    func phoneLogin(phone: String, code: String) async {
        do {
            let body = PhoneLoginBody(phone: phone, code: code)
            let data = try await APIClient.shared.post("/api/auth/phone-login", body: body)
            let decoder = JSONDecoder()
            let response = try decoder.decode(LoginResponse.self, from: data)
            KeychainHelper.save(token: response.token)
            currentUser = response.user
            isLoggedIn = true
        } catch let APIError.serverError(_, message) {
            errorMessage = message
        } catch {
            errorMessage = "登录失败，请重试"
        }
    }

    func appleLogin(appleID: String, nickname: String) async {
        do {
            let body = AppleLoginBody(apple_id: appleID, nickname: nickname)
            let data = try await APIClient.shared.post("/api/auth/apple-login", body: body)
            let decoder = JSONDecoder()
            let response = try decoder.decode(LoginResponse.self, from: data)
            KeychainHelper.save(token: response.token)
            currentUser = response.user
            isLoggedIn = true
        } catch {
            errorMessage = "Apple 登录失败"
        }
    }

    func logout() {
        KeychainHelper.deleteToken()
        currentUser = nil
        isLoggedIn = false
    }

    func deleteAccount() async {
        do {
            _ = try await APIClient.shared.delete("/api/auth/delete-account")
            logout()
        } catch {
            errorMessage = "删除失败"
        }
    }
}
```

- [ ] **Step 2: Create Views/Auth/LoginView.swift**

```swift
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showPhoneLogin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))

                    Text("吃喝玩乐打卡")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

                    Text("记录你的探索足迹")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        handleAppleLogin(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(25)

                    Button {
                        showPhoneLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("手机号登录")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 0.76, green: 0.6, blue: 0.42))
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
            .navigationDestination(isPresented: $showPhoneLogin) {
                PhoneLoginView()
            }
        }
    }

    private func handleAppleLogin(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let userID = credential.user
            let fullName = credential.fullName
            let nickname = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task {
                await authService.appleLogin(appleID: userID, nickname: nickname)
            }
        case .failure:
            authService.errorMessage = "Apple 登录取消"
        }
    }
}
```

- [ ] **Step 3: Create Views/Auth/PhoneLoginView.swift**

```swift
import SwiftUI

struct PhoneLoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var phone = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var countdown = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Text("手机号登录")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

            VStack(spacing: 16) {
                TextField("手机号", text: $phone)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)

                if codeSent {
                    HStack {
                        TextField("验证码", text: $code)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)

                        Button(countdown > 0 ? "\(countdown)s" : "重发") {
                            sendCode()
                        }
                        .disabled(countdown > 0)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(countdown > 0 ? Color.gray.opacity(0.3) : Color(red: 0.76, green: 0.6, blue: 0.42))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)

            if let error = authService.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button {
                if codeSent {
                    login()
                } else {
                    sendCode()
                }
            } label: {
                Text(codeSent ? "登录" : "获取验证码")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(phone.count >= 11 ? Color(red: 0.76, green: 0.6, blue: 0.42) : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
            .disabled(phone.count < 11)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 40)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93))
        .onDisappear { timer?.invalidate() }
    }

    private func sendCode() {
        Task {
            let success = await authService.sendCode(phone: phone)
            if success {
                codeSent = true
                startCountdown()
            }
        }
    }

    private func login() {
        Task {
            await authService.phoneLogin(phone: phone, code: code)
        }
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}
```

- [ ] **Step 4: Update FoodCheckinApp.swift**

```swift
import SwiftUI

@main
struct FoodCheckinApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            if authService.isLoggedIn {
                ContentView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}
```

- [ ] **Step 5: Update ContentView.swift with Tab Bar skeleton**

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showNewCheckIn = false

    var body: some View {
        TabView {
            Text("日历")
                .tabItem {
                    Image(systemName: "calendar")
                    Text("日历")
                }

            Text("地图")
                .tabItem {
                    Image(systemName: "map")
                    Text("地图")
                }

            Text("")
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("")
                }

            Text("动态")
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("动态")
                }

            VStack {
                Text("我的")
                Button("退出登录") {
                    authService.logout()
                }
            }
            .tabItem {
                Image(systemName: "person")
                Text("我的")
            }
        }
        .tint(Color(red: 0.76, green: 0.6, blue: 0.42))
    }
}
```

- [ ] **Step 6: Build and run**

In Xcode: Product → Run (Cmd+R) on simulator

Expected: App launches showing login screen with Apple sign-in button and phone login option. Tapping phone login shows the phone number input view.

- [ ] **Step 7: Commit**

```bash
git add .
git commit -m "feat: iOS login flow with Apple Sign-In and phone verification"
```

---

## Task 6: Server Deployment Setup

**Files:**
- Create: `backend/deploy.sh`
- Create: `backend/foodcheckin.service` (systemd unit)
- Create: `backend/nginx.conf` (reverse proxy config)

**Interfaces:**
- Consumes: All backend code from Tasks 1-3
- Produces: Deployment script and configs for Alibaba Cloud ECS

---

- [ ] **Step 1: Create systemd service file**

```
backend/foodcheckin.service
```

```ini
[Unit]
Description=FoodCheckIn API
After=network.target postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/foodcheckin/backend
EnvironmentFile=/opt/foodcheckin/backend/.env
ExecStart=/opt/foodcheckin/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 2: Create nginx config**

```
backend/nginx.conf
```

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    client_max_body_size 10M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /uploads/ {
        alias /opt/foodcheckin/backend/uploads/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

- [ ] **Step 3: Create deploy script**

```
backend/deploy.sh
```

```bash
#!/bin/bash
set -e

echo "=== FoodCheckIn Backend Deploy ==="

# 1. Install system dependencies (run once)
# sudo apt update && sudo apt install -y python3.11 python3.11-venv postgresql nginx certbot python3-certbot-nginx

# 2. Create project directory
sudo mkdir -p /opt/foodcheckin
sudo chown $USER:$USER /opt/foodcheckin

# 3. Copy code
rsync -av --exclude='__pycache__' --exclude='.env' --exclude='venv' . /opt/foodcheckin/backend/

# 4. Setup Python venv
cd /opt/foodcheckin
python3.11 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt

# 5. Setup database (run once)
# sudo -u postgres createdb foodcheckin
# sudo -u postgres createdb foodcheckin_test

# 6. Run migrations
cd backend
alembic upgrade head

# 7. Install systemd service
sudo cp foodcheckin.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable foodcheckin
sudo systemctl restart foodcheckin

# 8. Setup nginx (run once, replace your-domain.com)
# sudo cp nginx.conf /etc/nginx/sites-available/foodcheckin
# sudo ln -sf /etc/nginx/sites-available/foodcheckin /etc/nginx/sites-enabled/
# sudo certbot --nginx -d your-domain.com
# sudo systemctl restart nginx

echo "=== Deploy complete ==="
echo "Check status: sudo systemctl status foodcheckin"
echo "Check logs: sudo journalctl -u foodcheckin -f"
```

- [ ] **Step 4: Make deploy script executable and commit**

```bash
chmod +x backend/deploy.sh
git add .
git commit -m "feat: add deployment configs (systemd, nginx, deploy script)"
```

---

## Summary: What This Plan Delivers

After completing all 6 tasks, you will have:

1. **Working backend** on your Alibaba Cloud server with:
   - FastAPI running behind nginx with HTTPS
   - PostgreSQL database with User table
   - Phone SMS login (send code + verify)
   - Sign in with Apple login
   - Token-based auth middleware
   - `/me` profile endpoint
   - Account deletion endpoint
   - Automated tests

2. **Working iOS app** with:
   - Login screen (Apple + phone)
   - Phone verification code flow with countdown
   - Token stored securely in Keychain
   - Auth state management (logged in → tab bar, logged out → login)
   - 5-tab skeleton (Calendar, Map, +, Feed, Profile)
   - Network layer ready for all future API calls

## Next Plans

After this plan is complete, proceed to:
- **Phase 2:** Check-in Core (photo upload, location search, rating, tags, spending)
- **Phase 3:** Calendar/Date Wall (month + year views)
- **Phase 4:** Map Module (GeoJSON fill + pins)
- **Phase 5:** Social Features (friends, feed, comments, @)
- **Phase 6:** Statistics + Polish + App Store submission
