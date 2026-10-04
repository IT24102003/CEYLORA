from tools.backend_client import _pick_guide


def test_pick_guide_returns_none_for_an_empty_list():
    assert _pick_guide([], "English") is None


def test_pick_guide_prefers_a_language_match():
    items = [
        {"id": 1, "languages": "Sinhala"},
        {"id": 2, "languages": "Sinhala,English"},
    ]
    result = _pick_guide(items, "English")
    assert result["id"] == 2


def test_pick_guide_falls_back_to_any_guide_when_no_language_matches():
    items = [{"id": 1, "languages": "Sinhala"}]
    result = _pick_guide(items, "French")
    assert result["id"] == 1


def test_pick_guide_is_case_insensitive_on_language():
    items = [{"id": 1, "languages": "sinhala, ENGLISH"}]
    result = _pick_guide(items, "english")
    assert result["id"] == 1


def test_pick_guide_picks_randomly_when_no_language_requested():
    items = [{"id": 1, "languages": "Sinhala"}]
    result = _pick_guide(items, None)
    assert result["id"] == 1
