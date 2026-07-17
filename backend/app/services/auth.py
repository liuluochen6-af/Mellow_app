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
    if user and user.token_expires_at:
        expires = user.token_expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < datetime.now(timezone.utc):
            return None
    return user
