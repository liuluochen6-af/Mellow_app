import time

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
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
