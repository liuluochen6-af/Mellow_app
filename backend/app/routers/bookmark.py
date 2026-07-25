import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, desc, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.checkin import CheckIn
from app.models.social import Bookmark

router = APIRouter(prefix="/api/bookmarks", tags=["bookmarks"])


@router.post("/{checkin_id}")
async def add_bookmark(
    checkin_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        cid = uuid.UUID(checkin_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="无效的ID格式")

    result = await db.execute(select(CheckIn).where(CheckIn.id == cid))
    checkin = result.scalar_one_or_none()
    if not checkin:
        raise HTTPException(status_code=404, detail="打卡记录不存在")

    existing = await db.execute(
        select(Bookmark).where(
            and_(Bookmark.user_id == current_user.id, Bookmark.checkin_id == cid)
        )
    )
    if existing.scalar_one_or_none():
        return {"message": "已收藏"}

    bookmark = Bookmark(user_id=current_user.id, checkin_id=cid)
    db.add(bookmark)
    await db.commit()
    return {"message": "收藏成功"}


@router.delete("/{checkin_id}")
async def remove_bookmark(
    checkin_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        cid = uuid.UUID(checkin_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="无效的ID格式")

    result = await db.execute(
        select(Bookmark).where(
            and_(Bookmark.user_id == current_user.id, Bookmark.checkin_id == cid)
        )
    )
    bookmark = result.scalar_one_or_none()
    if not bookmark:
        raise HTTPException(status_code=404, detail="未收藏")

    await db.delete(bookmark)
    await db.commit()
    return {"message": "已取消收藏"}


@router.get("")
async def list_bookmarks(
    cursor: str | None = None,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from datetime import datetime as dt

    query = (
        select(Bookmark)
        .where(Bookmark.user_id == current_user.id)
        .order_by(desc(Bookmark.created_at))
    )

    if cursor:
        cursor_time = dt.fromisoformat(cursor)
        query = query.where(Bookmark.created_at < cursor_time)

    query = query.limit(limit)
    result = await db.execute(query)
    bookmarks = result.scalars().all()

    checkin_ids = [b.checkin_id for b in bookmarks]
    if not checkin_ids:
        return {"items": [], "next_cursor": None}

    checkins_result = await db.execute(
        select(CheckIn).where(CheckIn.id.in_(checkin_ids))
    )
    checkins_map = {c.id: c for c in checkins_result.scalars().all()}

    items = []
    for b in bookmarks:
        checkin = checkins_map.get(b.checkin_id)
        if checkin:
            items.append({
                "id": str(checkin.id),
                "user_id": str(checkin.user_id),
                "photo_url": checkin.photo_path,
                "place_name": checkin.place_name,
                "place_id": checkin.place_id,
                "address": checkin.address,
                "latitude": float(checkin.latitude),
                "longitude": float(checkin.longitude),
                "country": checkin.country,
                "province": checkin.province,
                "city": checkin.city,
                "district": checkin.district,
                "category": checkin.category,
                "rating": checkin.rating,
                "tags": checkin.tags or [],
                "note": checkin.note,
                "is_public": checkin.is_public,
                "amount": float(checkin.amount) if checkin.amount is not None else None,
                "amount_type": checkin.amount_type,
                "created_at": checkin.created_at.isoformat(),
                "bookmarked_at": b.created_at.isoformat(),
            })

    next_cursor = None
    if len(bookmarks) == limit:
        next_cursor = bookmarks[-1].created_at.isoformat()

    return {"items": items, "next_cursor": next_cursor}


@router.get("/check/{checkin_id}")
async def check_bookmark(
    checkin_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        cid = uuid.UUID(checkin_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="无效的ID格式")

    result = await db.execute(
        select(Bookmark).where(
            and_(Bookmark.user_id == current_user.id, Bookmark.checkin_id == cid)
        )
    )
    return {"bookmarked": result.scalar_one_or_none() is not None}
