import os
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.checkin import CheckIn
from app.schemas.checkin import CheckInCreate, CheckInUpdate, CheckInResponse, CheckInListResponse
from app.services.image import compress_and_save_image

router = APIRouter(prefix="/api/checkins", tags=["checkins"])


def _checkin_to_response(checkin: CheckIn) -> CheckInResponse:
    return CheckInResponse(
        id=checkin.id,
        user_id=checkin.user_id,
        photo_url=checkin.photo_path,
        place_name=checkin.place_name,
        place_id=checkin.place_id,
        address=checkin.address,
        latitude=float(checkin.latitude),
        longitude=float(checkin.longitude),
        country=checkin.country,
        province=checkin.province,
        city=checkin.city,
        district=checkin.district,
        category=checkin.category,
        rating=checkin.rating,
        tags=checkin.tags or [],
        note=checkin.note,
        is_public=checkin.is_public,
        amount=float(checkin.amount) if checkin.amount is not None else None,
        amount_type=checkin.amount_type,
        created_at=checkin.created_at,
    )


@router.post("", response_model=CheckInResponse)
async def create_checkin(
    photo: UploadFile = File(...),
    data: str = Form(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    parsed = CheckInCreate.model_validate_json(data)

    if parsed.rating < 1 or parsed.rating > 4:
        raise HTTPException(status_code=400, detail="评分必须在1-4之间")

    valid_categories = {"food", "drink", "entertainment", "shopping", "scenic", "other"}
    if parsed.category not in valid_categories:
        raise HTTPException(status_code=400, detail=f"类别必须是: {', '.join(valid_categories)}")

    file_bytes = await photo.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="照片不能为空")

    photo_path = compress_and_save_image(file_bytes, photo.filename or "photo.jpg")

    checkin = CheckIn(
        user_id=current_user.id,
        photo_path=photo_path,
        place_name=parsed.place_name,
        place_id=parsed.place_id,
        address=parsed.address,
        latitude=parsed.latitude,
        longitude=parsed.longitude,
        country=parsed.country,
        province=parsed.province,
        city=parsed.city,
        district=parsed.district,
        category=parsed.category,
        rating=parsed.rating,
        tags=parsed.tags,
        note=parsed.note,
        is_public=parsed.is_public,
        amount=parsed.amount,
        amount_type=parsed.amount_type,
    )
    db.add(checkin)
    await db.commit()
    await db.refresh(checkin)

    return _checkin_to_response(checkin)


@router.get("/search", response_model=CheckInListResponse)
async def search_checkins(
    q: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    search_term = f"%{q}%"
    query = (
        select(CheckIn)
        .where(CheckIn.user_id == current_user.id)
        .where(
            (CheckIn.place_name.ilike(search_term))
            | (CheckIn.address.ilike(search_term))
            | (CheckIn.tags.ilike(search_term))
            | (CheckIn.note.ilike(search_term))
        )
        .order_by(desc(CheckIn.created_at))
        .limit(50)
    )
    result = await db.execute(query)
    checkins = result.scalars().all()
    return CheckInListResponse(
        items=[_checkin_to_response(c) for c in checkins],
        next_cursor=None,
    )


@router.get("/mine", response_model=CheckInListResponse)
async def list_my_checkins(
    cursor: str | None = None,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(CheckIn).where(CheckIn.user_id == current_user.id).order_by(desc(CheckIn.created_at))

    if cursor:
        cursor_time = datetime.fromisoformat(cursor)
        query = query.where(CheckIn.created_at < cursor_time)

    query = query.limit(limit)
    result = await db.execute(query)
    checkins = result.scalars().all()

    next_cursor = None
    if len(checkins) == limit:
        next_cursor = checkins[-1].created_at.isoformat()

    return CheckInListResponse(
        items=[_checkin_to_response(c) for c in checkins],
        next_cursor=next_cursor,
    )


@router.get("/calendar", response_model=CheckInListResponse)
async def list_checkins_by_month(
    year: int,
    month: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from datetime import date
    import calendar as cal

    start_date = datetime(year, month, 1, tzinfo=None)
    last_day = cal.monthrange(year, month)[1]
    end_date = datetime(year, month, last_day, 23, 59, 59)

    query = (
        select(CheckIn)
        .where(CheckIn.user_id == current_user.id)
        .where(CheckIn.created_at >= start_date)
        .where(CheckIn.created_at <= end_date)
        .order_by(desc(CheckIn.created_at))
    )

    result = await db.execute(query)
    checkins = result.scalars().all()

    return CheckInListResponse(
        items=[_checkin_to_response(c) for c in checkins],
        next_cursor=None,
    )


@router.get("/year-summary")
async def year_summary(
    year: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import extract, func as sqlfunc

    query = (
        select(
            extract("month", CheckIn.created_at).label("month"),
            sqlfunc.count().label("count"),
        )
        .where(CheckIn.user_id == current_user.id)
        .where(extract("year", CheckIn.created_at) == year)
        .group_by(extract("month", CheckIn.created_at))
    )

    result = await db.execute(query)
    rows = result.all()

    summary = {int(row.month): row.count for row in rows}
    return {"year": year, "months": summary}


@router.get("/map-pins")
async def get_map_pins(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(
            CheckIn.id,
            CheckIn.place_name,
            CheckIn.place_id,
            CheckIn.latitude,
            CheckIn.longitude,
            CheckIn.category,
            CheckIn.rating,
            CheckIn.photo_path,
            CheckIn.created_at,
        )
        .where(CheckIn.user_id == current_user.id)
        .order_by(desc(CheckIn.created_at))
    )
    result = await db.execute(query)
    rows = result.all()

    pins = []
    for row in rows:
        pins.append({
            "id": str(row.id),
            "place_name": row.place_name,
            "place_id": row.place_id,
            "latitude": float(row.latitude),
            "longitude": float(row.longitude),
            "category": row.category,
            "rating": row.rating,
            "photo_url": row.photo_path,
            "created_at": row.created_at.isoformat(),
        })

    return {"pins": pins}


@router.get("/visited-regions")
async def get_visited_regions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import distinct, func as sqlfunc

    countries_q = select(distinct(CheckIn.country)).where(
        CheckIn.user_id == current_user.id
    ).where(CheckIn.country != "")
    provinces_q = select(distinct(CheckIn.province)).where(
        CheckIn.user_id == current_user.id
    ).where(CheckIn.province != "")
    cities_q = select(distinct(CheckIn.city)).where(
        CheckIn.user_id == current_user.id
    ).where(CheckIn.city != "")
    districts_q = select(distinct(CheckIn.district)).where(
        CheckIn.user_id == current_user.id
    ).where(CheckIn.district != "")

    countries = [row[0] for row in (await db.execute(countries_q)).all()]
    provinces = [row[0] for row in (await db.execute(provinces_q)).all()]
    cities = [row[0] for row in (await db.execute(cities_q)).all()]
    districts = [row[0] for row in (await db.execute(districts_q)).all()]

    return {
        "countries": countries,
        "provinces": provinces,
        "cities": cities,
        "districts": districts,
    }


@router.get("/{checkin_id}", response_model=CheckInResponse)
async def get_checkin(
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
    if checkin.user_id != current_user.id and not checkin.is_public:
        raise HTTPException(status_code=403, detail="无权访问")
    return _checkin_to_response(checkin)


@router.put("/{checkin_id}", response_model=CheckInResponse)
async def update_checkin(
    checkin_id: str,
    body: CheckInUpdate,
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
    if checkin.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权修改")

    if body.rating is not None:
        if body.rating < 1 or body.rating > 4:
            raise HTTPException(status_code=400, detail="评分必须在1-4之间")
        checkin.rating = body.rating
    if body.tags is not None:
        checkin.tags = body.tags
    if body.note is not None:
        checkin.note = body.note
    if body.is_public is not None:
        checkin.is_public = body.is_public

    await db.commit()
    await db.refresh(checkin)
    return _checkin_to_response(checkin)


@router.delete("/{checkin_id}")
async def delete_checkin(
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
    if checkin.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权删除")

    if checkin.photo_path:
        file_path = checkin.photo_path.lstrip("/")
        if os.path.exists(file_path):
            os.remove(file_path)

    await db.delete(checkin)
    await db.commit()
    return {"message": "已删除"}
