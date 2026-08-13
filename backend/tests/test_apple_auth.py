import base64
import hashlib
import time

import pytest
import rsa
from jose import jwt

import app.services.apple_auth as apple_auth
from app.config import settings
from app.services.apple_auth import AppleAuthError, verify_apple_identity_token


def _base64url_uint(value: int) -> str:
    raw = value.to_bytes((value.bit_length() + 7) // 8, byteorder="big")
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _signed_token(raw_nonce: str, audience: str | None = None):
    public_key, private_key = rsa.newkeys(1024)
    jwk = {
        "kty": "RSA",
        "kid": "test-key",
        "use": "sig",
        "alg": "RS256",
        "n": _base64url_uint(public_key.n),
        "e": _base64url_uint(public_key.e),
    }
    claims = {
        "iss": apple_auth.APPLE_ISSUER,
        "aud": audience or settings.apple_client_id,
        "sub": "apple-user-123",
        "iat": int(time.time()),
        "exp": int(time.time()) + 300,
        "nonce": hashlib.sha256(raw_nonce.encode("utf-8")).hexdigest(),
    }
    token = jwt.encode(
        claims,
        private_key.save_pkcs1(),
        algorithm="RS256",
        headers={"kid": "test-key"},
    )
    return token, jwk


@pytest.mark.asyncio
async def test_verify_apple_identity_token(monkeypatch):
    nonce = "secure-test-nonce-value"
    token, jwk = _signed_token(nonce)

    async def keys(_force_refresh=False):
        return [jwk]

    monkeypatch.setattr(apple_auth, "_get_apple_keys", keys)
    assert await verify_apple_identity_token(token, nonce) == "apple-user-123"


@pytest.mark.asyncio
async def test_verify_apple_identity_token_rejects_wrong_nonce(monkeypatch):
    token, jwk = _signed_token("original-nonce-value")

    async def keys(_force_refresh=False):
        return [jwk]

    monkeypatch.setattr(apple_auth, "_get_apple_keys", keys)
    with pytest.raises(AppleAuthError, match="nonce"):
        await verify_apple_identity_token(token, "different-nonce-value")


@pytest.mark.asyncio
async def test_verify_apple_identity_token_rejects_wrong_audience(monkeypatch):
    nonce = "secure-test-nonce-value"
    token, jwk = _signed_token(nonce, audience="com.example.wrong-app")

    async def keys(_force_refresh=False):
        return [jwk]

    monkeypatch.setattr(apple_auth, "_get_apple_keys", keys)
    with pytest.raises(AppleAuthError, match="无效或已过期"):
        await verify_apple_identity_token(token, nonce)
