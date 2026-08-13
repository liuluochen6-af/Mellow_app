import io
import json
import pytest
from PIL import Image

from app.services.sms import _code_store


def make_test_image() -> io.BytesIO:
    output = io.BytesIO()
    Image.new("RGB", (2, 2), color="white").save(output, format="JPEG")
    output.seek(0)
    return output


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

    fake_image = make_test_image()

    response = await client.post(
        "/api/checkins",
        headers={"Authorization": f"Bearer {token}"},
        data={"data": json.dumps(data)},
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
async def test_melbourne_checkin_is_saved_at_city_level(client):
    token = await get_auth_token(client)
    data = {
        "place_name": "The Glen",
        "address": "235 Springvale Rd, Glen Waverley VIC",
        "latitude": -37.8797,
        "longitude": 145.1641,
        "country": "Australia",
        "province": "Victoria",
        "city": "Glen Waverley",
        "district": "Glen Waverley",
        "category": "shopping",
        "rating": 4,
    }
    response = await client.post(
        "/api/checkins",
        headers={"Authorization": f"Bearer {token}"},
        data={"data": json.dumps(data)},
        files={"photo": ("test.jpg", make_test_image(), "image/jpeg")},
    )
    assert response.status_code == 200
    assert response.json()["city"] == "墨尔本"

    regions = await client.get(
        "/api/checkins/visited-regions",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert regions.json()["cities"] == ["墨尔本"]


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
    fake_image = make_test_image()
    create_resp = await client.post(
        "/api/checkins",
        headers={"Authorization": f"Bearer {token}"},
        data={"data": json.dumps(data)},
        files={"photo": ("test.jpg", fake_image, "image/jpeg")},
    )
    checkin_id = create_resp.json()["id"]

    response = await client.delete(
        f"/api/checkins/{checkin_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200

    response = await client.get(
        f"/api/checkins/{checkin_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404
