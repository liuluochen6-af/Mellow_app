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
