# Phase 2: Check-In Core — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the complete check-in flow: photo capture/selection, location search + manual pin, category/rating/tags/spending input, publish to server, local draft on failure, edit and delete existing check-ins.

**Architecture:** iOS sends multipart form data (photo + JSON fields) to FastAPI. Server saves compressed photo to disk, stores record in PostgreSQL. iOS caches published check-ins in SwiftData for fast local reads. Failed publishes save as local drafts for retry.

**Tech Stack:** SwiftUI (PhotosUI, MapKit, CoreLocation), SwiftData; Python FastAPI, SQLAlchemy, Pillow (image compression)

## Global Constraints

- iOS deployment target: 17.0
- Photo: 1 per check-in, compressed to 1080px width, JPEG 70%
- Category: required, one of: food/drink/entertainment/shopping/scenic/other
- Rating: required, 1-4 (拉/一般/不错/夯)
- Tags: optional, array of strings
- Amount: optional, decimal + type (per_person/total)
- Must be online to publish; save draft on failure
- place_id from MapKit POI used for same-place detection
- Published check-ins immutable on photo+location; rating/tags/note/is_public editable

---

## File Structure

### Backend (new/modified files)

```
backend/
├── app/
│   ├── models/
│   │   └── checkin.py          (NEW)
│   ├── schemas/
│   │   └── checkin.py          (NEW)
│   ├── routers/
│   │   └── checkin.py          (NEW)
│   ├── services/
│   │   └── image.py            (NEW)
│   └── main.py                 (MODIFY: add checkin router)
├── requirements.txt            (MODIFY: add Pillow)
└── tests/
    └── test_checkin.py         (NEW)
```

### iOS (new/modified files)

```
FoodCheckin/FoodCheckin/
├── Models/
│   ├── CheckIn.swift           (NEW)
│   └── CachedCheckIn.swift     (NEW: SwiftData model)
├── Views/
│   └── CheckIn/
│       ├── NewCheckInView.swift       (NEW)
│       ├── LocationSearchView.swift   (NEW)
│       ├── ManualPinView.swift        (NEW)
│       ├── RatingView.swift           (NEW)
│       ├── CategoryPickerView.swift   (NEW)
│       └── CheckInDetailView.swift    (NEW)
├── Services/
│   ├── CheckInService.swift    (NEW)
│   └── LocationService.swift   (NEW)
├── Utils/
│   └── DraftStore.swift        (NEW)
└── ContentView.swift           (MODIFY: wire up + button)
```

---

## Task 1: Backend — CheckIn Model + Image Service

**Files:**
- Modify: `backend/requirements.txt`
- Create: `backend/app/models/checkin.py`
- Modify: `backend/app/models/__init__.py`
- Create: `backend/app/services/image.py`

**Interfaces:**
- Consumes: `Base` from database.py, `User` model
- Produces: `CheckIn` SQLAlchemy model with all PRD fields
- Produces: `compress_and_save_image(file_bytes, filename) -> str` returns saved path

---

- [ ] **Step 1: Add Pillow to requirements.txt**

Append `Pillow==10.3.0` to `backend/requirements.txt`.

- [ ] **Step 2: Create backend/app/models/checkin.py**

```python
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import String, DateTime, Integer, Boolean, Numeric, Text, func
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CheckIn(Base):
    __tablename__ = "checkins"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), index=True)
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
    tags: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    amount: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    amount_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 3: Update backend/app/models/__init__.py**

```python
from app.models.user import User
from app.models.checkin import CheckIn

__all__ = ["User", "CheckIn"]
```

- [ ] **Step 4: Create backend/app/services/image.py**

```python
import uuid
import os
from io import BytesIO

from PIL import Image

UPLOAD_DIR = "uploads"
MAX_WIDTH = 1080
JPEG_QUALITY = 70


def compress_and_save_image(file_bytes: bytes, original_filename: str) -> str:
    img = Image.open(BytesIO(file_bytes))

    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")

    if img.width > MAX_WIDTH:
        ratio = MAX_WIDTH / img.width
        new_height = int(img.height * ratio)
        img = img.resize((MAX_WIDTH, new_height), Image.LANCZOS)

    filename = f"{uuid.uuid4().hex}.jpg"
    filepath = os.path.join(UPLOAD_DIR, filename)

    img.save(filepath, "JPEG", quality=JPEG_QUALITY)
    return f"/uploads/{filename}"
```

- [ ] **Step 5: Generate migration and commit**

```bash
cd backend
alembic revision --autogenerate -m "create checkins table"
git add .
git commit -m "feat: add CheckIn model and image compression service"
```

---

## Task 2: Backend — CheckIn CRUD Endpoints

**Files:**
- Create: `backend/app/schemas/checkin.py`
- Create: `backend/app/routers/checkin.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_checkin.py`

**Interfaces:**
- Consumes: `CheckIn` model, `compress_and_save_image`, `get_current_user`, `get_db`
- Produces: `POST /api/checkins` — create check-in (multipart: photo + JSON)
- Produces: `GET /api/checkins/mine?cursor=&limit=` — list my check-ins with pagination
- Produces: `GET /api/checkins/{id}` — single check-in detail
- Produces: `PUT /api/checkins/{id}` — edit rating/tags/note/is_public
- Produces: `DELETE /api/checkins/{id}` — delete check-in + photo file

---

- [ ] **Step 1: Create backend/app/schemas/checkin.py**

```python
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
```

- [ ] **Step 2: Create backend/app/routers/checkin.py**

```python
import json
import os
from datetime import datetime, timezone

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
        amount=checkin.amount,
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


@router.get("/{checkin_id}", response_model=CheckInResponse)
async def get_checkin(
    checkin_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(CheckIn).where(CheckIn.id == checkin_id))
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
    result = await db.execute(select(CheckIn).where(CheckIn.id == checkin_id))
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
    result = await db.execute(select(CheckIn).where(CheckIn.id == checkin_id))
    checkin = result.scalar_one_or_none()
    if not checkin:
        raise HTTPException(status_code=404, detail="打卡记录不存在")
    if checkin.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权删除")

    # Delete photo file
    if checkin.photo_path:
        file_path = checkin.photo_path.lstrip("/")
        if os.path.exists(file_path):
            os.remove(file_path)

    await db.delete(checkin)
    await db.commit()
    return {"message": "已删除"}
```

- [ ] **Step 3: Update backend/app/main.py to add checkin router**

```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import os

from app.routers.auth import router as auth_router
from app.routers.checkin import router as checkin_router

app = FastAPI(title="FoodCheckIn API")

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(auth_router)
app.include_router(checkin_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
```

- [ ] **Step 4: Create backend/tests/test_checkin.py**

```python
import io
import pytest

from app.services.sms import _code_store


async def get_auth_token(client) -> str:
    await client.post("/api/auth/send-code", json={"phone": "13900000001"})
    code = _code_store["13900000001"][0]
    resp = await client.post("/api/auth/phone-login", json={"phone": "13900000001", "code": code})
    return resp.json()["token"]


@pytest.mark.asyncio
async def test_create_checkin(client):
    token = await get_auth_token(client)

    data = {
        "place_name": "星巴克国贸店",
        "address": "北京市朝阳区国贸",
        "latitude": 39.9042,
        "longitude": 116.4074,
        "country": "中国",
        "province": "北京市",
        "city": "北京市",
        "district": "朝阳区",
        "category": "drink",
        "rating": 4,
        "tags": ["好喝", "环境好"],
        "is_public": True,
    }

    fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

    response = await client.post(
        "/api/checkins",
        headers={"Authorization": f"Bearer {token}"},
        data={"data": __import__("json").dumps(data)},
        files={"photo": ("test.jpg", fake_image, "image/jpeg")},
    )
    assert response.status_code == 200
    result = response.json()
    assert result["place_name"] == "星巴克国贸店"
    assert result["rating"] == 4
    assert result["category"] == "drink"


@pytest.mark.asyncio
async def test_list_my_checkins(client):
    token = await get_auth_token(client)

    response = await client.get(
        "/api/checkins/mine",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert "items" in response.json()


@pytest.mark.asyncio
async def test_update_checkin(client):
    token = await get_auth_token(client)

    # Create first
    data = {
        "place_name": "Test Place",
        "address": "Test Addr",
        "latitude": 39.9,
        "longitude": 116.4,
        "country": "中国",
        "province": "北京市",
        "city": "北京市",
        "district": "朝阳区",
        "category": "food",
        "rating": 3,
    }
    fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
    create_resp = await client.post(
        "/api/checkins",
        headers={"Authorization": f"Bearer {token}"},
        data={"data": __import__("json").dumps(data)},
        files={"photo": ("test.jpg", fake_image, "image/jpeg")},
    )
    checkin_id = create_resp.json()["id"]

    # Update
    response = await client.put(
        f"/api/checkins/{checkin_id}",
        headers={"Authorization": f"Bearer {token}"},
        json={"rating": 1, "note": "太难吃了"},
    )
    assert response.status_code == 200
    assert response.json()["rating"] == 1
    assert response.json()["note"] == "太难吃了"


@pytest.mark.asyncio
async def test_delete_checkin(client):
    token = await get_auth_token(client)

    data = {
        "place_name": "Delete Me",
        "address": "Addr",
        "latitude": 39.9,
        "longitude": 116.4,
        "country": "中国",
        "province": "北京市",
        "city": "北京市",
        "district": "朝阳区",
        "category": "food",
        "rating": 2,
    }
    fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
    create_resp = await client.post(
        "/api/checkins",
        headers={"Authorization": f"Bearer {token}"},
        data={"data": __import__("json").dumps(data)},
        files={"photo": ("test.jpg", fake_image, "image/jpeg")},
    )
    checkin_id = create_resp.json()["id"]

    response = await client.delete(
        f"/api/checkins/{checkin_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200

    # Verify gone
    response = await client.get(
        f"/api/checkins/{checkin_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404
```

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add check-in CRUD endpoints with photo upload"
```

---

## Task 3: iOS — CheckIn Models + Service

**Files:**
- Create: `FoodCheckin/FoodCheckin/Models/CheckIn.swift`
- Create: `FoodCheckin/FoodCheckin/Models/CachedCheckIn.swift`
- Create: `FoodCheckin/FoodCheckin/Services/CheckInService.swift`
- Create: `FoodCheckin/FoodCheckin/Utils/DraftStore.swift`
- Modify: `FoodCheckin/FoodCheckin/Services/APIClient.swift` (add multipart upload)

**Interfaces:**
- Consumes: `APIClient`, `KeychainHelper`
- Produces: `CheckInData` struct (local form data before upload)
- Produces: `CheckInResponse` struct (server response)
- Produces: `CachedCheckIn` SwiftData model
- Produces: `CheckInService` with `publish()`, `listMine()`, `update()`, `delete()`
- Produces: `DraftStore` with `saveDraft()`, `loadDrafts()`, `deleteDraft()`

---

- [ ] **Step 1: Create FoodCheckin/FoodCheckin/Models/CheckIn.swift**

```swift
import Foundation

enum CheckInCategory: String, CaseIterable, Codable {
    case food
    case drink
    case entertainment
    case shopping
    case scenic
    case other

    var displayName: String {
        switch self {
        case .food: return "餐饮"
        case .drink: return "饮品"
        case .entertainment: return "娱乐"
        case .shopping: return "购物"
        case .scenic: return "景点"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .food: return "🍽️"
        case .drink: return "☕"
        case .entertainment: return "🎮"
        case .shopping: return "🛍️"
        case .scenic: return "🏖️"
        case .other: return "📌"
        }
    }
}

enum AmountType: String, Codable {
    case perPerson = "per_person"
    case total = "total"
}

struct CheckInData: Codable {
    var placeName: String = ""
    var placeId: String?
    var address: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var country: String = ""
    var province: String = ""
    var city: String = ""
    var district: String = ""
    var category: CheckInCategory = .food
    var rating: Int = 0
    var tags: [String] = []
    var note: String?
    var isPublic: Bool = true
    var amount: Double?
    var amountType: AmountType?

    var serverJSON: [String: Any] {
        var dict: [String: Any] = [
            "place_name": placeName,
            "address": address,
            "latitude": latitude,
            "longitude": longitude,
            "country": country,
            "province": province,
            "city": city,
            "district": district,
            "category": category.rawValue,
            "rating": rating,
            "tags": tags,
            "is_public": isPublic,
        ]
        if let placeId { dict["place_id"] = placeId }
        if let note { dict["note"] = note }
        if let amount { dict["amount"] = amount }
        if let amountType { dict["amount_type"] = amountType.rawValue }
        return dict
    }
}

struct CheckInResponse: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let photoUrl: String
    let placeName: String
    let placeId: String?
    let address: String
    let latitude: Double
    let longitude: Double
    let country: String
    let province: String
    let city: String
    let district: String
    let category: String
    let rating: Int
    let tags: [String]
    let note: String?
    let isPublic: Bool
    let amount: Double?
    let amountType: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, address, latitude, longitude, country, province, city, district, category, rating, tags, note, amount
        case userId = "user_id"
        case photoUrl = "photo_url"
        case placeName = "place_name"
        case placeId = "place_id"
        case isPublic = "is_public"
        case amountType = "amount_type"
        case createdAt = "created_at"
    }
}

struct CheckInListResponse: Codable {
    let items: [CheckInResponse]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct CheckInUpdateBody: Codable {
    var rating: Int?
    var tags: [String]?
    var note: String?
    var isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case rating, tags, note
        case isPublic = "is_public"
    }
}
```

- [ ] **Step 2: Create FoodCheckin/FoodCheckin/Models/CachedCheckIn.swift**

```swift
import Foundation
import SwiftData

@Model
class CachedCheckIn {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var photoUrl: String
    var placeName: String
    var placeId: String?
    var address: String
    var latitude: Double
    var longitude: Double
    var country: String
    var province: String
    var city: String
    var district: String
    var category: String
    var rating: Int
    var tags: [String]
    var note: String?
    var isPublic: Bool
    var amount: Double?
    var amountType: String?
    var createdAt: Date

    init(from response: CheckInResponse) {
        self.id = response.id
        self.userId = response.userId
        self.photoUrl = response.photoUrl
        self.placeName = response.placeName
        self.placeId = response.placeId
        self.address = response.address
        self.latitude = response.latitude
        self.longitude = response.longitude
        self.country = response.country
        self.province = response.province
        self.city = response.city
        self.district = response.district
        self.category = response.category
        self.rating = response.rating
        self.tags = response.tags
        self.note = response.note
        self.isPublic = response.isPublic
        self.amount = response.amount
        self.amountType = response.amountType
        self.createdAt = ISO8601DateFormatter().date(from: response.createdAt) ?? Date()
    }
}
```

- [ ] **Step 3: Add multipart upload to APIClient.swift**

Add this method to the `APIClient` class in `FoodCheckin/FoodCheckin/Services/APIClient.swift`:

```swift
func uploadCheckIn(photoData: Data, jsonData: Data) async throws -> Data {
    guard let url = URL(string: baseURL + "/api/checkins") else { throw APIError.invalidURL }

    let boundary = UUID().uuidString
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    if let token = KeychainHelper.getToken() {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    var body = Data()

    // Photo part
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(photoData)
    body.append("\r\n".data(using: .utf8)!)

    // Data part
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"data\"\r\n\r\n".data(using: .utf8)!)
    body.append(jsonData)
    body.append("\r\n".data(using: .utf8)!)

    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    request.httpBody = body

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return data
    } catch let error as APIError {
        throw error
    } catch {
        throw APIError.networkError(error)
    }
}
```

- [ ] **Step 4: Create FoodCheckin/FoodCheckin/Services/CheckInService.swift**

```swift
import Foundation
import SwiftUI
import UIKit

@MainActor
class CheckInService: ObservableObject {
    @Published var myCheckIns: [CheckInResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func publish(data: CheckInData, image: UIImage) async -> Bool {
        guard let photoData = image.jpegData(compressionQuality: 0.7) else {
            errorMessage = "图片处理失败"
            return false
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data.serverJSON) else {
            errorMessage = "数据序列化失败"
            return false
        }

        do {
            let responseData = try await APIClient.shared.uploadCheckIn(photoData: photoData, jsonData: jsonData)
            let response = try JSONDecoder().decode(CheckInResponse.self, from: responseData)
            myCheckIns.insert(response, at: 0)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "发布失败，请重试"
            return false
        }
    }

    func loadMyCheckIns(cursor: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        var path = "/api/checkins/mine?limit=20"
        if let cursor { path += "&cursor=\(cursor)" }

        do {
            let data = try await APIClient.shared.get(path)
            let response = try JSONDecoder().decode(CheckInListResponse.self, from: data)
            if cursor == nil {
                myCheckIns = response.items
            } else {
                myCheckIns.append(contentsOf: response.items)
            }
        } catch {
            errorMessage = "加载失败"
        }
    }

    func update(id: UUID, body: CheckInUpdateBody) async -> Bool {
        do {
            let data = try await APIClient.shared.post("/api/checkins/\(id.uuidString)", body: body)
            return true
        } catch {
            errorMessage = "更新失败"
            return false
        }
    }

    func delete(id: UUID) async -> Bool {
        do {
            _ = try await APIClient.shared.delete("/api/checkins/\(id.uuidString)")
            myCheckIns.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = "删除失败"
            return false
        }
    }
}
```

- [ ] **Step 5: Create FoodCheckin/FoodCheckin/Utils/DraftStore.swift**

```swift
import Foundation
import UIKit

struct CheckInDraft: Codable, Identifiable {
    let id: UUID
    let data: CheckInData
    let imageFileName: String
    let createdAt: Date

    init(data: CheckInData, imageFileName: String) {
        self.id = UUID()
        self.data = data
        self.imageFileName = imageFileName
        self.createdAt = Date()
    }
}

enum DraftStore {
    private static var draftsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("drafts.json")
    }

    private static var imagesDir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("draft_images")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func saveDraft(data: CheckInData, image: UIImage) {
        let fileName = "\(UUID().uuidString).jpg"
        let imageURL = imagesDir.appendingPathComponent(fileName)
        if let jpegData = image.jpegData(compressionQuality: 0.7) {
            try? jpegData.write(to: imageURL)
        }

        var drafts = loadDrafts()
        drafts.append(CheckInDraft(data: data, imageFileName: fileName))

        if let encoded = try? JSONEncoder().encode(drafts) {
            try? encoded.write(to: draftsURL)
        }
    }

    static func loadDrafts() -> [CheckInDraft] {
        guard let data = try? Data(contentsOf: draftsURL),
              let drafts = try? JSONDecoder().decode([CheckInDraft].self, from: data) else {
            return []
        }
        return drafts
    }

    static func getDraftImage(fileName: String) -> UIImage? {
        let url = imagesDir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func deleteDraft(id: UUID) {
        var drafts = loadDrafts()
        if let index = drafts.firstIndex(where: { $0.id == id }) {
            let draft = drafts[index]
            let imageURL = imagesDir.appendingPathComponent(draft.imageFileName)
            try? FileManager.default.removeItem(at: imageURL)
            drafts.remove(at: index)
            if let encoded = try? JSONEncoder().encode(drafts) {
                try? encoded.write(to: draftsURL)
            }
        }
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "feat: iOS check-in models, service, draft store, and multipart upload"
```

---

## Task 4: iOS — Location Service + Search View

**Files:**
- Create: `FoodCheckin/FoodCheckin/Services/LocationService.swift`
- Create: `FoodCheckin/FoodCheckin/Views/CheckIn/LocationSearchView.swift`
- Create: `FoodCheckin/FoodCheckin/Views/CheckIn/ManualPinView.swift`

**Interfaces:**
- Consumes: MapKit, CoreLocation
- Produces: `LocationService` ObservableObject — manages GPS permission + current location
- Produces: `LocationSearchView` — search bar + MKLocalSearch results list
- Produces: `ManualPinView` — map with draggable pin + name text field

---

- [ ] **Step 1: Create FoodCheckin/FoodCheckin/Services/LocationService.swift**

```swift
import Foundation
import CoreLocation
import MapKit

@MainActor
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func search(query: String, near coordinate: CLLocationCoordinate2D?) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> (country: String, province: String, city: String, district: String, address: String)? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return (
                country: placemark.country ?? "",
                province: placemark.administrativeArea ?? "",
                city: placemark.locality ?? "",
                district: placemark.subLocality ?? "",
                address: [placemark.country, placemark.administrativeArea, placemark.locality, placemark.subLocality, placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.joined()
            )
        } catch {
            return nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last?.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
        }
    }
}
```

- [ ] **Step 2: Create FoodCheckin/FoodCheckin/Views/CheckIn/LocationSearchView.swift**

```swift
import SwiftUI
import MapKit

struct LocationSearchView: View {
    @Binding var selectedPlace: SelectedPlace?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()
    @State private var searchText = ""
    @State private var showManualPin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索店铺名称", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                .onChange(of: searchText) { _, newValue in
                    Task {
                        await locationService.search(query: newValue, near: locationService.currentLocation)
                    }
                }

                if locationService.isSearching {
                    ProgressView()
                        .padding()
                }

                // Results list
                List {
                    if !locationService.searchResults.isEmpty {
                        ForEach(locationService.searchResults, id: \.self) { item in
                            Button {
                                selectMapItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "未知地点")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(item.placemark.title ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            showManualPin = true
                        } label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("在地图上手动标注")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("选择地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                locationService.requestPermission()
            }
            .sheet(isPresented: $showManualPin) {
                ManualPinView(selectedPlace: $selectedPlace, initialCoordinate: locationService.currentLocation)
            }
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let placemark = item.placemark

        selectedPlace = SelectedPlace(
            name: item.name ?? "未知地点",
            placeId: item.identifier?.rawValue,
            address: placemark.title ?? "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            country: placemark.country ?? "",
            province: placemark.administrativeArea ?? "",
            city: placemark.locality ?? "",
            district: placemark.subLocality ?? ""
        )
        dismiss()
    }
}

struct SelectedPlace {
    var name: String
    var placeId: String?
    var address: String
    var latitude: Double
    var longitude: Double
    var country: String
    var province: String
    var city: String
    var district: String
}
```

- [ ] **Step 3: Create FoodCheckin/FoodCheckin/Views/CheckIn/ManualPinView.swift**

```swift
import SwiftUI
import MapKit

struct ManualPinView: View {
    @Binding var selectedPlace: SelectedPlace?
    var initialCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss
    @State private var pinCoordinate: CLLocationCoordinate2D
    @State private var placeName = ""
    @State private var cameraPosition: MapCameraPosition
    @StateObject private var locationService = LocationService()

    init(selectedPlace: Binding<SelectedPlace?>, initialCoordinate: CLLocationCoordinate2D?) {
        _selectedPlace = selectedPlace
        let coord = initialCoordinate ?? CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        _pinCoordinate = State(initialValue: coord)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("输入地点名称", text: $placeName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()

                ZStack {
                    Map(position: $cameraPosition) {
                        Annotation("", coordinate: pinCoordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                    .onMapCameraChange { context in
                        pinCoordinate = context.region.center
                    }

                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .navigationTitle("手动标注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        confirmPin()
                    }
                    .disabled(placeName.isEmpty)
                }
            }
        }
    }

    private func confirmPin() {
        Task {
            let geo = await locationService.reverseGeocode(coordinate: pinCoordinate)
            selectedPlace = SelectedPlace(
                name: placeName,
                placeId: nil,
                address: geo?.address ?? "",
                latitude: pinCoordinate.latitude,
                longitude: pinCoordinate.longitude,
                country: geo?.country ?? "",
                province: geo?.province ?? "",
                city: geo?.city ?? "",
                district: geo?.district ?? ""
            )
            dismiss()
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: iOS location service, search view, and manual pin annotation"
```

---

## Task 5: iOS — New Check-In View (Full Flow)

**Files:**
- Create: `FoodCheckin/FoodCheckin/Views/CheckIn/NewCheckInView.swift`
- Create: `FoodCheckin/FoodCheckin/Views/CheckIn/RatingView.swift`
- Create: `FoodCheckin/FoodCheckin/Views/CheckIn/CategoryPickerView.swift`
- Modify: `FoodCheckin/FoodCheckin/ContentView.swift` (wire "+" button)

**Interfaces:**
- Consumes: `CheckInService`, `DraftStore`, `LocationSearchView`, all models
- Produces: `NewCheckInView` — full multi-step check-in form
- Produces: `RatingView` — 4-level rating picker (夯/不错/一般/拉)
- Produces: `CategoryPickerView` — 6-category icon grid
- Produces: Updated `ContentView` with working "+" tab

---

- [ ] **Step 1: Create FoodCheckin/FoodCheckin/Views/CheckIn/CategoryPickerView.swift**

```swift
import SwiftUI

struct CategoryPickerView: View {
    @Binding var selected: CheckInCategory

    private let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(CheckInCategory.allCases, id: \.self) { category in
                Button {
                    selected = category
                } label: {
                    VStack(spacing: 6) {
                        Text(category.icon)
                            .font(.title)
                        Text(category.displayName)
                            .font(.caption)
                            .foregroundColor(selected == category ? .white : Color(red: 0.35, green: 0.25, blue: 0.15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selected == category
                            ? Color(red: 0.76, green: 0.6, blue: 0.42)
                            : Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Create FoodCheckin/FoodCheckin/Views/CheckIn/RatingView.swift**

```swift
import SwiftUI

struct RatingView: View {
    @Binding var rating: Int

    private let levels = [
        (value: 4, label: "夯", icon: "🔥"),
        (value: 3, label: "不错", icon: "👍"),
        (value: 2, label: "一般", icon: "😐"),
        (value: 1, label: "拉", icon: "💩"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(levels, id: \.value) { level in
                Button {
                    rating = level.value
                } label: {
                    VStack(spacing: 4) {
                        Text(level.icon)
                            .font(.title2)
                        Text(level.label)
                            .font(.caption)
                            .foregroundColor(rating == level.value ? .white : Color(red: 0.35, green: 0.25, blue: 0.15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        rating == level.value
                            ? Color(red: 0.76, green: 0.6, blue: 0.42)
                            : Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Create FoodCheckin/FoodCheckin/Views/CheckIn/NewCheckInView.swift**

```swift
import SwiftUI
import PhotosUI

struct NewCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var checkInService: CheckInService

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var data = CheckInData()
    @State private var selectedPlace: SelectedPlace?
    @State private var showLocationSearch = false
    @State private var tagInput = ""
    @State private var amountText = ""
    @State private var isPublishing = false
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Photo section
                    photoSection

                    // Location section
                    locationSection

                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("类别").font(.headline)
                        CategoryPickerView(selected: $data.category)
                    }

                    // Rating
                    VStack(alignment: .leading, spacing: 8) {
                        Text("评分").font(.headline)
                        RatingView(rating: $data.rating)
                    }

                    // Tags
                    tagsSection

                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注").font(.headline)
                        TextField("写点什么...", text: Binding(
                            get: { data.note ?? "" },
                            set: { data.note = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Amount
                    amountSection

                    // Public toggle
                    Toggle("公开（好友可见）", isOn: $data.isPublic)
                        .tint(Color(red: 0.76, green: 0.6, blue: 0.42))
                }
                .padding()
            }
            .background(Color(red: 0.98, green: 0.96, blue: 0.93).ignoresSafeArea())
            .navigationTitle("打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { publish() }
                        .disabled(!canPublish || isPublishing)
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(selectedPlace: $selectedPlace)
            }
            .onChange(of: selectedPlace) { _, place in
                if let place {
                    data.placeName = place.name
                    data.placeId = place.placeId
                    data.address = place.address
                    data.latitude = place.latitude
                    data.longitude = place.longitude
                    data.country = place.country
                    data.province = place.province
                    data.city = place.city
                    data.district = place.district
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let photoData = try? await item?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: photoData) {
                        image = uiImage
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("照片").font(.headline)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture { selectedPhoto = nil; self.image = nil }
            } else {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                        Text("选择照片")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("地点").font(.headline)
            Button {
                showLocationSearch = true
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                    if data.placeName.isEmpty {
                        Text("选择地点")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading) {
                            Text(data.placeName)
                                .foregroundColor(.primary)
                            Text(data.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签").font(.headline)
            HStack {
                TextField("添加标签", text: $tagInput)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onSubmit { addTag() }

                Button("添加") { addTag() }
                    .disabled(tagInput.isEmpty)
            }
            if !data.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(data.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                            Button {
                                data.tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.2))
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("消费金额（可选）").font(.headline)
            HStack {
                TextField("¥", text: $amountText)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onChange(of: amountText) { _, val in
                        data.amount = Double(val)
                    }

                Picker("", selection: Binding(
                    get: { data.amountType ?? .perPerson },
                    set: { data.amountType = $0 }
                )) {
                    Text("人均").tag(AmountType.perPerson)
                    Text("总计").tag(AmountType.total)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }

    private var canPublish: Bool {
        image != nil && !data.placeName.isEmpty && data.rating > 0
    }

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty && !data.tags.contains(tag) {
            data.tags.append(tag)
        }
        tagInput = ""
    }

    private func publish() {
        guard let image else { return }
        isPublishing = true

        Task {
            let success = await checkInService.publish(data: data, image: image)
            isPublishing = false
            if success {
                dismiss()
            } else {
                // Save draft on failure
                DraftStore.saveDraft(data: data, image: image)
            }
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
```

- [ ] **Step 4: Update ContentView.swift to wire the "+" button**

Replace the entire `ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var checkInService = CheckInService()
    @State private var selectedTab = 0
    @State private var showNewCheckIn = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Text("日历")
                    .tag(0)
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("日历")
                    }

                Text("地图")
                    .tag(1)
                    .tabItem {
                        Image(systemName: "map")
                        Text("地图")
                    }

                Text("")
                    .tag(2)
                    .tabItem {
                        Image(systemName: "")
                        Text("")
                    }

                Text("动态")
                    .tag(3)
                    .tabItem {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("动态")
                    }

                ProfileView()
                    .tag(4)
                    .tabItem {
                        Image(systemName: "person")
                        Text("我的")
                    }
            }
            .tint(Color(red: 0.76, green: 0.6, blue: 0.42))

            // Central raised "+" button
            Button {
                showNewCheckIn = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(red: 0.76, green: 0.6, blue: 0.42))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            .offset(y: -20)
        }
        .fullScreenCover(isPresented: $showNewCheckIn) {
            NewCheckInView()
                .environmentObject(checkInService)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                selectedTab = 0
                showNewCheckIn = true
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                        VStack(alignment: .leading) {
                            Text(authService.currentUser?.nickname ?? "用户")
                                .font(.headline)
                            Text(authService.currentUser?.phone ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button("退出登录") {
                        authService.logout()
                    }
                    .foregroundColor(.orange)

                    Button("删除账号") {
                        Task { await authService.deleteAccount() }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("我的")
        }
    }
}
```

- [ ] **Step 5: Update FoodCheckinApp.swift to include SwiftData**

```swift
import SwiftUI
import SwiftData

@main
struct FoodCheckinApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            if authService.isLoggedIn {
                ContentView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .modelContainer(for: [CachedCheckIn.self])
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "feat: complete check-in flow UI with photo, location, rating, tags, and draft"
```

---

## Summary: What Phase 2 Delivers

After completing all 5 tasks:

1. **Backend:**
   - `POST /api/checkins` — multipart photo upload + create check-in
   - `GET /api/checkins/mine` — paginated list of user's check-ins
   - `GET /api/checkins/{id}` — single check-in detail
   - `PUT /api/checkins/{id}` — edit rating/tags/note/visibility
   - `DELETE /api/checkins/{id}` — delete check-in + photo
   - Automatic image compression (1080px, 70% quality)

2. **iOS:**
   - Full check-in flow: photo → location → category → rating → tags → note → amount → publish
   - Location search via MapKit + manual pin drop
   - Category picker (6 types with icons)
   - Rating picker (夯/不错/一般/拉)
   - Tag input with flow layout
   - Draft auto-save on publish failure
   - Central raised "+" button in tab bar
   - SwiftData model ready for local caching

## Next Plans

- **Phase 3:** Calendar/Date Wall (month + year views)
- **Phase 4:** Map Module (GeoJSON fill + pins)
- **Phase 5:** Social Features (friends, feed, comments, @)
- **Phase 6:** Statistics + Polish + App Store submission
