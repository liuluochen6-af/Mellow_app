import hashlib
import hmac
import time
from typing import Any

import httpx
from jose import JWTError, jwt

from app.config import settings


APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"
APPLE_KEYS_CACHE_SECONDS = 60 * 60


class AppleAuthError(ValueError):
    """Raised when an Apple identity token cannot be trusted."""


_cached_keys: list[dict[str, Any]] = []
_cached_keys_at = 0.0


async def _get_apple_keys(force_refresh: bool = False) -> list[dict[str, Any]]:
    global _cached_keys, _cached_keys_at

    now = time.monotonic()
    if (
        not force_refresh
        and _cached_keys
        and now - _cached_keys_at < APPLE_KEYS_CACHE_SECONDS
    ):
        return _cached_keys

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(APPLE_KEYS_URL)
            response.raise_for_status()
            keys = response.json().get("keys", [])
    except (httpx.HTTPError, ValueError, AttributeError) as exc:
        raise AppleAuthError("暂时无法验证 Apple 登录凭证") from exc

    if not isinstance(keys, list) or not keys:
        raise AppleAuthError("Apple 公钥响应无效")

    _cached_keys = keys
    _cached_keys_at = now
    return keys


async def verify_apple_identity_token(identity_token: str, raw_nonce: str) -> str:
    try:
        header = jwt.get_unverified_header(identity_token)
    except JWTError as exc:
        raise AppleAuthError("Apple 身份令牌格式无效") from exc

    key_id = header.get("kid")
    if not key_id or header.get("alg") != "RS256":
        raise AppleAuthError("Apple 身份令牌算法无效")

    keys = await _get_apple_keys()
    public_key = next((key for key in keys if key.get("kid") == key_id), None)
    if public_key is None:
        keys = await _get_apple_keys(force_refresh=True)
        public_key = next((key for key in keys if key.get("kid") == key_id), None)
    if public_key is None:
        raise AppleAuthError("找不到对应的 Apple 公钥")

    try:
        claims = jwt.decode(
            identity_token,
            public_key,
            algorithms=["RS256"],
            audience=settings.apple_client_id,
            issuer=APPLE_ISSUER,
            options={"verify_at_hash": False},
        )
    except JWTError as exc:
        raise AppleAuthError("Apple 身份令牌无效或已过期") from exc

    expected_nonce = hashlib.sha256(raw_nonce.encode("utf-8")).hexdigest()
    token_nonce = claims.get("nonce")
    if not isinstance(token_nonce, str) or not hmac.compare_digest(
        token_nonce, expected_nonce
    ):
        raise AppleAuthError("Apple 登录 nonce 验证失败")

    subject = claims.get("sub")
    if not isinstance(subject, str) or not subject:
        raise AppleAuthError("Apple 用户标识无效")
    return subject
