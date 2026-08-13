from app.services.city import normalize_city


def test_melbourne_suburb_is_grouped_as_melbourne():
    assert normalize_city(
        country="Australia",
        province="Victoria",
        city="Glen Waverley",
        latitude=-37.8797,
        longitude=145.1641,
    ) == "墨尔本"


def test_other_countries_keep_geocoder_city_not_district():
    assert normalize_city(
        country="Japan",
        province="Tokyo",
        city="Tokyo",
        latitude=35.6762,
        longitude=139.6503,
    ) == "Tokyo"
