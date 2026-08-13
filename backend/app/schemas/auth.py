from pydantic import BaseModel, Field
import uuid
from datetime import datetime


class SendCodeRequest(BaseModel):
    phone: str


class PhoneLoginRequest(BaseModel):
    phone: str
    code: str


class AppleLoginRequest(BaseModel):
    identity_token: str = Field(min_length=20)
    authorization_code: str = Field(min_length=1)
    nonce: str = Field(min_length=16, max_length=128)
    nickname: str = Field(default="", max_length=100)


class UserResponse(BaseModel):
    id: uuid.UUID
    nickname: str
    avatar_url: str
    phone: str | None
    created_at: datetime


class UpdateProfileRequest(BaseModel):
    nickname: str | None = None


class LoginResponse(BaseModel):
    token: str
    user: UserResponse
