import uuid
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, or_, and_, desc, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.checkin import CheckIn
from app.models.social import Friendship, Comment, Notification, Bookmark

router = APIRouter(prefix="/api/social", tags=["social"])


# ========== FRIENDS ==========

@router.get("/friends")
async def list_friends(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Friendship).where(
        or_(
            and_(Friendship.user_id == current_user.id, Friendship.status == "accepted"),
            and_(Friendship.friend_id == current_user.id, Friendship.status == "accepted"),
        )
    )
    result = await db.execute(query)
    friendships = result.scalars().all()

    friend_ids = []
    for f in friendships:
        friend_ids.append(f.friend_id if f.user_id == current_user.id else f.user_id)

    if not friend_ids:
        return {"friends": []}

    users_result = await db.execute(select(User).where(User.id.in_(friend_ids)))
    users = users_result.scalars().all()

    return {"friends": [
        {"id": str(u.id), "nickname": u.nickname, "avatar_url": u.avatar_url}
        for u in users
    ]}


@router.get("/friend-requests")
async def list_friend_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Friendship).where(
        Friendship.friend_id == current_user.id,
        Friendship.status == "pending",
    ).order_by(desc(Friendship.created_at))
    result = await db.execute(query)
    requests = result.scalars().all()

    if not requests:
        return {"requests": []}

    sender_ids = [r.user_id for r in requests]
    users_result = await db.execute(select(User).where(User.id.in_(sender_ids)))
    users = {u.id: u for u in users_result.scalars().all()}

    return {"requests": [
        {
            "id": str(r.id),
            "user_id": str(r.user_id),
            "nickname": users[r.user_id].nickname if r.user_id in users else "未知用户",
            "avatar_url": users[r.user_id].avatar_url if r.user_id in users else None,
            "created_at": r.created_at.isoformat(),
        }
        for r in requests
    ]}


@router.post("/search-user")
async def search_user(
    query: str = Query(..., min_length=1),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User).where(
        or_(
            User.phone == query,
            User.nickname.ilike(f"%{query}%"),
        )
    ).where(User.id != current_user.id).limit(10)

    result = await db.execute(stmt)
    users = result.scalars().all()

    return {"users": [
        {"id": str(u.id), "nickname": u.nickname, "avatar_url": u.avatar_url}
        for u in users
    ]}


@router.post("/friend-request")
async def send_friend_request(
    friend_id: str = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    target_id = uuid.UUID(friend_id)

    existing = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.user_id == current_user.id, Friendship.friend_id == target_id),
                and_(Friendship.user_id == target_id, Friendship.friend_id == current_user.id),
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="已发送过请求或已是好友")

    friendship = Friendship(user_id=current_user.id, friend_id=target_id, status="pending")
    db.add(friendship)

    notification = Notification(
        user_id=target_id,
        type="friend_request",
        related_id=friendship.id,
    )
    db.add(notification)

    await db.commit()
    return {"message": "好友请求已发送"}


@router.post("/accept-friend")
async def accept_friend_request(
    request_id: str = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Friendship).where(Friendship.id == uuid.UUID(request_id))
    )
    friendship = result.scalar_one_or_none()
    if not friendship or friendship.friend_id != current_user.id:
        raise HTTPException(status_code=404, detail="请求不存在")
    if friendship.status != "pending":
        raise HTTPException(status_code=400, detail="请求已处理")

    friendship.status = "accepted"
    await db.commit()
    return {"message": "已添加好友"}


@router.post("/reject-friend")
async def reject_friend_request(
    request_id: str = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Friendship).where(Friendship.id == uuid.UUID(request_id))
    )
    friendship = result.scalar_one_or_none()
    if not friendship or friendship.friend_id != current_user.id:
        raise HTTPException(status_code=404, detail="请求不存在")

    await db.delete(friendship)
    await db.commit()
    return {"message": "已拒绝"}


@router.delete("/unfriend")
async def remove_friend(
    friend_id: str = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    target_id = uuid.UUID(friend_id)
    result = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.user_id == current_user.id, Friendship.friend_id == target_id, Friendship.status == "accepted"),
                and_(Friendship.user_id == target_id, Friendship.friend_id == current_user.id, Friendship.status == "accepted"),
            )
        )
    )
    friendship = result.scalar_one_or_none()
    if not friendship:
        raise HTTPException(status_code=404, detail="好友关系不存在")

    await db.delete(friendship)
    await db.commit()
    return {"message": "已删除好友"}


# ========== FEED ==========

@router.get("/feed")
async def get_feed(
    cursor: str | None = None,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    friends_q = select(Friendship).where(
        or_(
            and_(Friendship.user_id == current_user.id, Friendship.status == "accepted"),
            and_(Friendship.friend_id == current_user.id, Friendship.status == "accepted"),
        )
    )
    result = await db.execute(friends_q)
    friendships = result.scalars().all()

    friend_ids = []
    for f in friendships:
        friend_ids.append(f.friend_id if f.user_id == current_user.id else f.user_id)

    if not friend_ids:
        return {"items": [], "next_cursor": None}

    query = (
        select(CheckIn)
        .where(CheckIn.user_id.in_(friend_ids))
        .where(CheckIn.is_public == True)
        .order_by(desc(CheckIn.created_at))
    )

    if cursor:
        cursor_time = datetime.fromisoformat(cursor)
        query = query.where(CheckIn.created_at < cursor_time)

    query = query.limit(limit)
    result = await db.execute(query)
    checkins = result.scalars().all()

    user_ids = list(set(c.user_id for c in checkins))
    if user_ids:
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users_map = {u.id: u for u in users_result.scalars().all()}
    else:
        users_map = {}

    next_cursor = None
    if len(checkins) == limit:
        next_cursor = checkins[-1].created_at.isoformat()

    items = []
    for c in checkins:
        user = users_map.get(c.user_id)
        items.append({
            "id": str(c.id),
            "user_id": str(c.user_id),
            "user_nickname": user.nickname if user else "未知用户",
            "user_avatar": user.avatar_url if user else None,
            "photo_url": c.photo_path,
            "place_name": c.place_name,
            "address": c.address,
            "category": c.category,
            "rating": c.rating,
            "tags": c.tags or [],
            "note": c.note,
            "amount": float(c.amount) if c.amount else None,
            "amount_type": c.amount_type,
            "created_at": c.created_at.isoformat(),
        })

    return {"items": items, "next_cursor": next_cursor}


# ========== COMMENTS ==========

@router.get("/comments/{checkin_id}")
async def get_comments(
    checkin_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Comment)
        .where(Comment.checkin_id == uuid.UUID(checkin_id))
        .order_by(Comment.created_at)
    )
    result = await db.execute(query)
    comments = result.scalars().all()

    user_ids = list(set(c.user_id for c in comments))
    if user_ids:
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users_map = {u.id: u for u in users_result.scalars().all()}
    else:
        users_map = {}

    return {"comments": [
        {
            "id": str(c.id),
            "user_id": str(c.user_id),
            "user_nickname": users_map[c.user_id].nickname if c.user_id in users_map else "未知用户",
            "user_avatar": users_map[c.user_id].avatar_url if c.user_id in users_map else None,
            "content": c.content,
            "mentioned_user_ids": [str(uid) for uid in (c.mentioned_user_ids or [])],
            "created_at": c.created_at.isoformat(),
        }
        for c in comments
    ]}


@router.post("/comments/{checkin_id}")
async def create_comment(
    checkin_id: str,
    content: str = Query(..., min_length=1, max_length=500),
    mentioned_user_ids: str = Query(default=""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    checkin_result = await db.execute(
        select(CheckIn).where(CheckIn.id == uuid.UUID(checkin_id))
    )
    checkin = checkin_result.scalar_one_or_none()
    if not checkin:
        raise HTTPException(status_code=404, detail="打卡记录不存在")

    mention_ids = []
    if mentioned_user_ids:
        mention_ids = [uuid.UUID(uid.strip()) for uid in mentioned_user_ids.split(",") if uid.strip()]

    comment = Comment(
        checkin_id=uuid.UUID(checkin_id),
        user_id=current_user.id,
        content=content,
        mentioned_user_ids=mention_ids,
    )
    db.add(comment)

    if checkin.user_id != current_user.id:
        notif = Notification(
            user_id=checkin.user_id,
            type="comment",
            related_id=comment.id,
        )
        db.add(notif)

    for uid in mention_ids:
        if uid != current_user.id:
            mention_notif = Notification(
                user_id=uid,
                type="mention",
                related_id=comment.id,
            )
            db.add(mention_notif)

    await db.commit()
    await db.refresh(comment)

    return {
        "id": str(comment.id),
        "user_id": str(comment.user_id),
        "content": comment.content,
        "mentioned_user_ids": [str(uid) for uid in (comment.mentioned_user_ids or [])],
        "created_at": comment.created_at.isoformat(),
    }


# ========== NOTIFICATIONS ==========

@router.get("/notifications")
async def get_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(desc(Notification.created_at))
        .limit(50)
    )
    result = await db.execute(query)
    notifications = result.scalars().all()

    return {"notifications": [
        {
            "id": str(n.id),
            "type": n.type,
            "related_id": str(n.related_id),
            "is_read": n.is_read,
            "created_at": n.created_at.isoformat(),
        }
        for n in notifications
    ]}


@router.get("/unread-count")
async def get_unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(func.count()).select_from(Notification).where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,
        )
    )
    count = result.scalar()
    return {"count": count}


@router.post("/mark-read")
async def mark_notifications_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import update

    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id)
        .where(Notification.is_read == False)
        .values(is_read=True)
    )
    await db.commit()
    return {"message": "已全部标记为已读"}


# ========== BOOKMARKS ==========

@router.post("/bookmarks/{checkin_id}")
async def toggle_bookmark(
    checkin_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    cid = uuid.UUID(checkin_id)
    existing = await db.execute(
        select(Bookmark).where(
            Bookmark.user_id == current_user.id,
            Bookmark.checkin_id == cid,
        )
    )
    bookmark = existing.scalar_one_or_none()

    if bookmark:
        await db.delete(bookmark)
        await db.commit()
        return {"bookmarked": False}
    else:
        new_bookmark = Bookmark(user_id=current_user.id, checkin_id=cid)
        db.add(new_bookmark)
        await db.commit()
        return {"bookmarked": True}


@router.get("/bookmarks")
async def list_bookmarks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Bookmark)
        .where(Bookmark.user_id == current_user.id)
        .order_by(desc(Bookmark.created_at))
    )
    result = await db.execute(query)
    bookmarks = result.scalars().all()

    if not bookmarks:
        return {"items": []}

    checkin_ids = [b.checkin_id for b in bookmarks]
    checkins_result = await db.execute(
        select(CheckIn).where(CheckIn.id.in_(checkin_ids))
    )
    checkins_map = {c.id: c for c in checkins_result.scalars().all()}

    user_ids = list(set(c.user_id for c in checkins_map.values()))
    if user_ids:
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users_map = {u.id: u for u in users_result.scalars().all()}
    else:
        users_map = {}

    items = []
    for b in bookmarks:
        c = checkins_map.get(b.checkin_id)
        if not c:
            continue
        user = users_map.get(c.user_id)
        items.append({
            "id": str(c.id),
            "user_id": str(c.user_id),
            "user_nickname": user.nickname if user else "未知用户",
            "photo_url": c.photo_path,
            "place_name": c.place_name,
            "address": c.address,
            "category": c.category,
            "rating": c.rating,
            "latitude": float(c.latitude),
            "longitude": float(c.longitude),
            "created_at": c.created_at.isoformat(),
            "bookmarked_at": b.created_at.isoformat(),
        })

    return {"items": items}
