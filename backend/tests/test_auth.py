import pytest

from app.services.sms import _code_store


@pytest.mark.asyncio
async def test_health(client):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_send_code(client):
    response = await client.post("/api/auth/send-code", json={"phone": "13800138000"})
    assert response.status_code == 200
    assert response.json() == {"message": "ok"}
    assert "13800138000" in _code_store


@pytest.mark.asyncio
async def test_send_code_rate_limit(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138001"})
    response = await client.post("/api/auth/send-code", json={"phone": "13800138001"})
    assert response.status_code == 429


@pytest.mark.asyncio
async def test_phone_login_success(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138002"})
    code = _code_store["13800138002"][0]

    response = await client.post("/api/auth/phone-login", json={"phone": "13800138002", "code": code})
    assert response.status_code == 200
    data = response.json()
    assert "token" in data
    assert data["user"]["phone"] == "13800138002"
    assert data["user"]["nickname"] == "用户8002"


@pytest.mark.asyncio
async def test_phone_login_wrong_code(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138003"})
    response = await client.post("/api/auth/phone-login", json={"phone": "13800138003", "code": "000000"})
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_apple_login(client):
    response = await client.post("/api/auth/apple-login", json={"apple_id": "apple_test_123", "nickname": "Test"})
    assert response.status_code == 200
    data = response.json()
    assert "token" in data
    assert data["user"]["nickname"] == "Test"


@pytest.mark.asyncio
async def test_apple_login_existing_user(client):
    await client.post("/api/auth/apple-login", json={"apple_id": "apple_repeat", "nickname": "First"})
    response = await client.post("/api/auth/apple-login", json={"apple_id": "apple_repeat", "nickname": "Second"})
    assert response.status_code == 200
    assert response.json()["user"]["nickname"] == "First"


@pytest.mark.asyncio
async def test_get_me_success(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138010"})
    code = _code_store["13800138010"][0]
    login_resp = await client.post("/api/auth/phone-login", json={"phone": "13800138010", "code": code})
    token = login_resp.json()["token"]

    response = await client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["phone"] == "13800138010"


@pytest.mark.asyncio
async def test_get_me_no_token(client):
    response = await client.get("/api/auth/me")
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_get_me_invalid_token(client):
    response = await client.get("/api/auth/me", headers={"Authorization": "Bearer invalid_token"})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_delete_account(client):
    await client.post("/api/auth/send-code", json={"phone": "13800138011"})
    code = _code_store["13800138011"][0]
    login_resp = await client.post("/api/auth/phone-login", json={"phone": "13800138011", "code": code})
    token = login_resp.json()["token"]

    response = await client.delete("/api/auth/delete-account", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200

    response = await client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401
