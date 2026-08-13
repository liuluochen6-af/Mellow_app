import base64
import hashlib
import hmac
import json
import re
import time
import urllib.parse
import uuid
from datetime import datetime, timezone

import httpx

from app.config import settings

_code_store: dict[str, tuple[str, float]] = {}


class SMSDeliveryError(RuntimeError):
    pass


def normalize_phone(phone: str) -> str:
    """Return a stable login key and validate mainland/E.164 phone formats.

    Existing Chinese accounts keep their 11-digit key for compatibility.
    International numbers are stored in E.164 form with a leading plus.
    """
    compact = re.sub(r"[\s()\-.]", "", phone.strip())
    if compact.startswith("0086"):
        compact = "+86" + compact[4:]
    if compact.startswith("+86") and re.fullmatch(r"\+861\d{10}", compact):
        return compact[3:]
    if re.fullmatch(r"1\d{10}", compact):
        return compact
    if not re.fullmatch(r"\+[1-9]\d{7,14}", compact):
        raise ValueError("请输入中国大陆手机号，或带国家区号的国际号码（例如 +61412345678）")
    return compact


def _is_mainland_phone(phone: str) -> bool:
    return bool(re.fullmatch(r"1\d{10}", phone))


def _generate_code() -> str:
    return f"{uuid.uuid4().int % 1_000_000:06d}"


def _sign_rpc_params(params: dict[str, str]) -> dict[str, str]:
    sorted_params = sorted(params.items())
    query_string = urllib.parse.urlencode(
        sorted_params,
        quote_via=urllib.parse.quote,
        safe="",
    )
    string_to_sign = f"GET&%2F&{urllib.parse.quote(query_string, safe='')}"
    sign_key = f"{settings.sms_access_key_secret}&"
    signature = base64.b64encode(
        hmac.new(sign_key.encode(), string_to_sign.encode(), hashlib.sha1).digest()
    ).decode()
    return {**params, "Signature": signature}


def _common_params(*, action: str, version: str) -> dict[str, str]:
    return {
        "Action": action,
        "Version": version,
        "Format": "JSON",
        "SignatureMethod": "HMAC-SHA1",
        "SignatureVersion": "1.0",
        "SignatureNonce": str(uuid.uuid4()),
        "Timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "AccessKeyId": settings.sms_access_key_id,
    }


async def _request_sms(endpoint: str, params: dict[str, str], success_key: str) -> None:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(endpoint, params=_sign_rpc_params(params))
            response.raise_for_status()
            payload = response.json()
    except (httpx.HTTPError, json.JSONDecodeError) as exc:
        raise SMSDeliveryError("短信服务暂时不可用，请稍后重试") from exc

    if payload.get(success_key) != "OK":
        error_code = payload.get(success_key, "UNKNOWN")
        description = payload.get("Message") or payload.get("ResponseDescription") or ""
        raise SMSDeliveryError(f"阿里云短信发送失败：{error_code} {description}".strip())


async def _send_domestic(phone: str, code: str) -> None:
    if not settings.sms_sign_name or not settings.sms_template_code:
        raise SMSDeliveryError("中国大陆短信签名或模板未配置")
    params = {
        **_common_params(action="SendSms", version="2017-05-25"),
        "PhoneNumbers": phone,
        "SignName": settings.sms_sign_name,
        "TemplateCode": settings.sms_template_code,
        "TemplateParam": json.dumps({"code": code}, ensure_ascii=False, separators=(",", ":")),
    }
    await _request_sms("https://dysmsapi.aliyuncs.com/", params, "Code")


async def _send_international(phone: str, code: str) -> None:
    try:
        message = settings.sms_international_message_template.format(code=code)
    except (KeyError, ValueError) as exc:
        raise SMSDeliveryError("国际短信文案模板必须包含 {code}") from exc

    params = {
        **_common_params(action="SendMessageToGlobe", version="2018-05-01"),
        "RegionId": "ap-southeast-1",
        "To": phone.removeprefix("+"),
        "Message": message,
        "Type": "OTP",
        "ValidityPeriod": "300",
    }
    if settings.sms_international_sender_id:
        params["From"] = settings.sms_international_sender_id
    await _request_sms(
        "https://dysmsapi.ap-southeast-1.aliyuncs.com/",
        params,
        "ResponseCode",
    )


async def send_verification_code(phone: str) -> tuple[str, bool]:
    normalized = normalize_phone(phone)
    code = _generate_code()

    if not settings.sms_access_key_id or not settings.sms_access_key_secret:
        if settings.app_env.lower() == "production":
            raise SMSDeliveryError("生产环境尚未配置阿里云短信 AccessKey")
        print(f"[DEV] SMS code for {normalized}: {code}")
        _code_store[normalized] = (code, time.time() + 300)
        return code, True

    if _is_mainland_phone(normalized):
        await _send_domestic(normalized, code)
    else:
        await _send_international(normalized, code)

    # Only store a usable code after Alibaba Cloud accepts the request.
    _code_store[normalized] = (code, time.time() + 300)
    return code, False


def verify_code(phone: str, code: str) -> bool:
    try:
        normalized = normalize_phone(phone)
    except ValueError:
        return False
    stored = _code_store.get(normalized)
    if not stored:
        return False
    stored_code, expire_time = stored
    if time.time() > expire_time:
        del _code_store[normalized]
        return False
    if not hmac.compare_digest(stored_code, code):
        return False
    del _code_store[normalized]
    return True


def get_last_send_time(phone: str) -> float | None:
    try:
        normalized = normalize_phone(phone)
    except ValueError:
        return None
    stored = _code_store.get(normalized)
    if stored:
        _, expire_time = stored
        return expire_time - 300
    return None
