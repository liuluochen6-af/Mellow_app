import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import String, DateTime, Integer, Boolean, Numeric, Text, func, Uuid, JSON
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CheckIn(Base):
    __tablename__ = "checkins"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, index=True)
    photo_path: Mapped[str] = mapped_column(String(500))
    place_name: Mapped[str] = mapped_column(String(200))
    place_id: Mapped[str | None] = mapped_column(String(200), nullable=True)
    address: Mapped[str] = mapped_column(String(500))
    latitude: Mapped[float] = mapped_column(Numeric(10, 7))
    longitude: Mapped[float] = mapped_column(Numeric(10, 7))
    country: Mapped[str] = mapped_column(String(100))
    province: Mapped[str] = mapped_column(String(100))
    city: Mapped[str] = mapped_column(String(100))
    district: Mapped[str] = mapped_column(String(100))
    category: Mapped[str] = mapped_column(String(20))
    rating: Mapped[int] = mapped_column(Integer)
    tags: Mapped[list] = mapped_column(JSON, default=list)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    amount: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    amount_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
