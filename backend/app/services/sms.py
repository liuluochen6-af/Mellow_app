import hashlib
import hmac
import time
import urllib.parse
import base64
from datetime import datetime, timezone
import uuid

import httpx

from app.config import settings

_code_store: dict[str, tuple[str, float]] = {}


def _generate_code() -> str:
    return str(uuid.uuid4().int)[:6]


async def send_verification_code(phone: str) -> str:
    code = _generate_code()
    _code_store[phone] = (code, time.time() + 300)

    if not settings.sms_access_key_id:
        print(f"[DEV] SMS code for {phone}: {code}")
        return code

    params = {
        "PhoneNumbers": phone,
        "SignName": settings.sms_sign_name,
        "TemplateCode": settings.sms_template_code,
        "TemplateParam": f'{{"code":"{code}"}}',
        "Action": "SendSms",
        "Version": "2017-05-25",
        "Format": "JSON",
        "SignatureMethod": "HMAC-SHA1",
        "SignatureVersion": "1.0",
        "SignatureNonce": str(uuid.uuid4()),
        "Timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "AccessKeyId": settings.sms_access_key_id,
    }

    sorted_params = sorted(params.items())
    query_string = urllib.parse.urlencode(sorted_params, quote_via=urllib.parse.quote)
    string_to_sign = f"GET&%2F&{urllib.parse.quote(query_string, safe='')}"

    sign_key = f"{settings.sms_access_key_secret}&"
    signature = base64.b64encode(
        hmac.new(sign_key.encode(), string_to_sign.encode(), hashlib.sha1).digest()
    ).decode()
    params["Signature"] = signature

    async with httpx.AsyncClient() as client:
        await client.get("https://dysmsapi.aliyuncs.com/", params=params)

    return code


def verify_code(phone: str, code: str) -> bool:
    stored = _code_store.get(phone)
    if not stored:
        return False
    stored_code, expire_time = stored
    if time.time() > expire_time:
        del _code_store[phone]
        return False
    if stored_code != code:
        return False
    del _code_store[phone]
    return True


def get_last_send_time(phone: str) -> float | None:
    stored = _code_store.get(phone)
    if stored:
        _, expire_time = stored
        return expire_time - 300
    return None
