"""Canonical city-level grouping for check-ins.

The client supplies the geocoder's city/locality value. This module is the
server-side authority so old and new records are grouped consistently. Rules
that correct provider-specific locality quirks belong here; all other places
retain the geocoder's city value and never fall back to district/suburb.
"""


def normalize_city(
    *,
    country: str,
    province: str,
    city: str,
    latitude: float,
    longitude: float,
) -> str:
    del country, province  # Reserved for future provider/country corrections.

    # Apple Maps commonly reports an Australian suburb as locality. Melbourne
    # metro check-ins must aggregate under one city instead of Glen Waverley,
    # Richmond, Box Hill, etc. This also normalizes historical records.
    in_melbourne_metro = (
        -38.50 <= latitude <= -37.40 and 144.40 <= longitude <= 145.80
    )
    if in_melbourne_metro:
        return "墨尔本"

    return city.strip()
