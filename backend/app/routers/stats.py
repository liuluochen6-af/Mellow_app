from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, distinct, extract
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.checkin import CheckIn
from app.services.city import normalize_city

router = APIRouter(prefix="/api/stats", tags=["stats"])


@router.get("/overview")
async def get_overview(
    year: int | None = None,
    month: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    filters = [CheckIn.user_id == current_user.id]
    if year:
        filters.append(extract("year", CheckIn.created_at) == year)
    if month:
        filters.append(extract("month", CheckIn.created_at) == month)

    total_count = (await db.execute(
        select(func.count()).select_from(CheckIn).where(*filters)
    )).scalar() or 0

    countries = (await db.execute(
        select(func.count(distinct(CheckIn.country))).where(
            *filters, CheckIn.country != ""
        )
    )).scalar() or 0

    provinces = (await db.execute(
        select(func.count(distinct(CheckIn.province))).where(
            *filters, CheckIn.province != ""
        )
    )).scalar() or 0

    city_rows = (await db.execute(
        select(
            CheckIn.country,
            CheckIn.province,
            CheckIn.city,
            CheckIn.latitude,
            CheckIn.longitude,
        ).where(*filters, CheckIn.city != "")
    )).all()
    cities = len({
        normalize_city(
            country=row.country or "",
            province=row.province or "",
            city=row.city or "",
            latitude=float(row.latitude),
            longitude=float(row.longitude),
        )
        for row in city_rows
    } - {""})

    districts = (await db.execute(
        select(func.count(distinct(CheckIn.district))).where(
            *filters, CheckIn.district != ""
        )
    )).scalar() or 0

    unique_places = (await db.execute(
        select(func.count(distinct(CheckIn.place_name))).where(*filters)
    )).scalar() or 0

    return {
        "total_checkins": total_count,
        "unique_places": unique_places,
        "countries": countries,
        "provinces": provinces,
        "cities": cities,
        "districts": districts,
    }


@router.get("/category-breakdown")
async def category_breakdown(
    year: int | None = None,
    month: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    filters = [CheckIn.user_id == current_user.id]
    if year:
        filters.append(extract("year", CheckIn.created_at) == year)
    if month:
        filters.append(extract("month", CheckIn.created_at) == month)

    result = await db.execute(
        select(CheckIn.category, func.count().label("count"))
        .where(*filters)
        .group_by(CheckIn.category)
    )
    rows = result.all()
    return {"categories": [{"category": r.category, "count": r.count} for r in rows]}


@router.get("/spending")
async def spending_stats(
    year: int | None = None,
    month: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(CheckIn).where(
        CheckIn.user_id == current_user.id,
        CheckIn.amount.isnot(None),
    )

    if year:
        query = query.where(extract("year", CheckIn.created_at) == year)
    if month:
        query = query.where(extract("month", CheckIn.created_at) == month)

    result = await db.execute(query)
    checkins = result.scalars().all()

    total = sum(float(c.amount) for c in checkins if c.amount)
    by_category = {}
    for c in checkins:
        if c.amount:
            by_category.setdefault(c.category, 0)
            by_category[c.category] += float(c.amount)

    return {
        "total": total,
        "count": len(checkins),
        "by_category": [{"category": k, "amount": v} for k, v in by_category.items()],
    }


@router.get("/top-places")
async def top_places(
    year: int | None = None,
    month: int | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    filters = [CheckIn.user_id == current_user.id]
    if year:
        filters.append(extract("year", CheckIn.created_at) == year)
    if month:
        filters.append(extract("month", CheckIn.created_at) == month)

    result = await db.execute(
        select(
            CheckIn.place_name,
            CheckIn.category,
            func.count().label("visit_count"),
            func.max(CheckIn.rating).label("best_rating"),
        )
        .where(*filters)
        .group_by(CheckIn.place_name, CheckIn.category)
        .order_by(func.max(CheckIn.rating).desc(), func.count().desc())
        .limit(10)
    )
    rows = result.all()

    return {"places": [
        {
            "place_name": r.place_name,
            "category": r.category,
            "visit_count": r.visit_count,
            "best_rating": r.best_rating,
        }
        for r in rows
    ]}


@router.get("/monthly-summary")
async def monthly_summary(
    year: int = Query(...),
    month: int = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    CATEGORY_EMOJI = {
        "food": "🍽️",
        "drink": "☕",
        "entertainment": "🎮",
        "shopping": "🛍️",
        "scenic": "🏖️",
        "other": "📌",
    }

    base_filter = [
        CheckIn.user_id == current_user.id,
        extract("year", CheckIn.created_at) == year,
        extract("month", CheckIn.created_at) == month,
    ]

    # Total check-ins
    total_checkins = (await db.execute(
        select(func.count()).select_from(CheckIn).where(*base_filter)
    )).scalar() or 0

    # Unique places
    unique_places = (await db.execute(
        select(func.count(distinct(CheckIn.place_name))).where(*base_filter)
    )).scalar() or 0

    # Total spending
    total_spending = (await db.execute(
        select(func.coalesce(func.sum(CheckIn.amount), 0)).where(*base_filter)
    )).scalar() or 0.0

    # Daily breakdown
    result = await db.execute(
        select(CheckIn).where(*base_filter).order_by(CheckIn.created_at.desc())
    )
    checkins = result.scalars().all()

    days_map: dict[int, list] = {}
    for c in checkins:
        day = c.created_at.day
        days_map.setdefault(day, []).append(c)

    daily_breakdown = []
    for day in sorted(days_map.keys(), reverse=True):
        day_checkins = days_map[day]
        places = [
            {
                "place_name": c.place_name,
                "category": c.category,
                "emoji": CATEGORY_EMOJI.get(c.category, "📌"),
            }
            for c in day_checkins
        ]
        daily_breakdown.append({
            "day": day,
            "places": places,
            "count": len(day_checkins),
        })

    return {
        "total_checkins": total_checkins,
        "unique_places": unique_places,
        "total_spending": float(total_spending),
        "daily_breakdown": daily_breakdown,
    }
