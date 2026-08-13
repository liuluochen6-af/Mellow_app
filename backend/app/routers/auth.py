import time

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
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
    UpdateProfileRequest,
)
from app.services.sms import (
    SMSDeliveryError,
    get_last_send_time,
    normalize_phone,
    send_verification_code,
    verify_code,
)
from app.config import settings
from app.services.auth import get_or_create_user_by_phone, get_or_create_user_by_apple_id
from app.services.apple_auth import AppleAuthError, verify_apple_identity_token
from app.services.image import compress_and_save_image

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/send-code")
async def send_code(req: SendCodeRequest):
    try:
        phone = normalize_phone(req.phone)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    last_send = get_last_send_time(phone)
    if last_send and time.time() - last_send < 60:
        raise HTTPException(status_code=429, detail="请等待60秒后再发送")

    try:
        code, is_dev = await send_verification_code(phone)
    except SMSDeliveryError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    response = {"message": "ok"}
    if is_dev and settings.sms_debug_return_code:
        response["dev_code"] = code
    return response


@router.post("/phone-login", response_model=LoginResponse)
async def phone_login(req: PhoneLoginRequest, db: AsyncSession = Depends(get_db)):
    try:
        phone = normalize_phone(req.phone)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if not verify_code(phone, req.code):
        raise HTTPException(status_code=400, detail="验证码错误或已过期")

    user = await get_or_create_user_by_phone(db, phone)
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
    try:
        apple_id = await verify_apple_identity_token(req.identity_token, req.nonce)
    except AppleAuthError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc

    user = await get_or_create_user_by_apple_id(db, apple_id, req.nickname)
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


@router.put("/profile", response_model=UserResponse)
async def update_profile(
    nickname: str = Form(None),
    avatar: UploadFile | None = File(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if nickname is not None and nickname.strip():
        current_user.nickname = nickname.strip()

    if avatar:
        file_bytes = await avatar.read()
        if file_bytes:
            avatar_path = compress_and_save_image(file_bytes, avatar.filename or "avatar.jpg")
            current_user.avatar_url = avatar_path

    await db.commit()
    await db.refresh(current_user)

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
