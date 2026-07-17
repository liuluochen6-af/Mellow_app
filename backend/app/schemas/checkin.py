from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime
import uuid


class CheckInCreate(BaseModel):
    place_name: str
    place_id: str | None = None
    address: str
    latitude: float
    longitude: float
    country: str
    province: str
    city: str
    district: str
    category: str
    rating: int
    tags: list[str] = []
    note: str | None = None
    is_public: bool = True
    amount: Decimal | None = None
    amount_type: str | None = None


class CheckInUpdate(BaseModel):
    rating: int | None = None
    tags: list[str] | None = None
    note: str | None = None
    is_public: bool | None = None


class CheckInResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    photo_url: str
    place_name: str
    place_id: str | None
    address: str
    latitude: float
    longitude: float
    country: str
    province: str
    city: str
    district: str
    category: str
    rating: int
    tags: list[str]
    note: str | None
    is_public: bool
    amount: Decimal | None
    amount_type: str | None
    created_at: datetime


class CheckInListResponse(BaseModel):
    items: list[CheckInResponse]
    next_cursor: str | None
