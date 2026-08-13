import pytest

from app.services import sms


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("13800138000", "13800138000"),
        ("+86 138 0013 8000", "13800138000"),
        ("+61 412 345 678", "+61412345678"),
        ("+1 (415) 555-2671", "+14155552671"),
    ],
)
def test_normalize_phone(raw, expected):
    assert sms.normalize_phone(raw) == expected


@pytest.mark.parametrize("raw", ["", "0412345678", "+012345678", "abc"])
def test_reject_phone_without_valid_country_code(raw):
    with pytest.raises(ValueError):
        sms.normalize_phone(raw)


@pytest.mark.asyncio
async def test_international_sms_uses_globe_api(monkeypatch):
    captured = {}

    async def fake_request(endpoint, params, success_key):
        captured.update(endpoint=endpoint, params=params, success_key=success_key)

    monkeypatch.setattr(sms, "_request_sms", fake_request)
    monkeypatch.setattr(sms.settings, "sms_international_sender_id", "Mellow")
    await sms._send_international("+61412345678", "123456")

    assert captured["endpoint"] == "https://dysmsapi.ap-southeast-1.aliyuncs.com/"
    assert captured["params"]["Action"] == "SendMessageToGlobe"
    assert captured["params"]["Version"] == "2018-05-01"
    assert captured["params"]["To"] == "61412345678"
    assert captured["params"]["From"] == "Mellow"
    assert captured["params"]["Type"] == "OTP"
    assert "123456" in captured["params"]["Message"]
    assert captured["success_key"] == "ResponseCode"
