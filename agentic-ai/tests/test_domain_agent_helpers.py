import pytest

from agents.domain_agent import (
    _best_window_ratio,
    _find_best_destination_matches,
    _extract_day_regions,
)

_DESTINATIONS = [
    {"id": 1, "name": "Nuwara Eliya", "region": "Central"},
    {"id": 2, "name": "Galle Face Green", "region": "Colombo"},
    {"id": 3, "name": "Sigiriya Rock", "region": "Central"},
    {"id": 4, "name": "Mirissa Beach", "region": "Southern"},
]


def test_best_window_ratio_scores_an_exact_match_as_1():
    words = "a trip to nuwara eliya next week".split()
    assert _best_window_ratio(words, "nuwara eliya") == pytest.approx(1.0)


def test_best_window_ratio_is_0_when_the_phrase_is_longer_than_the_words():
    assert _best_window_ratio(["kandy"], "nuwara eliya") == 0.0


def test_find_best_destination_matches_an_exact_name():
    matches = _find_best_destination_matches("I want to visit Sigiriya Rock", _DESTINATIONS)
    assert matches[0]["name"] == "Sigiriya Rock"


def test_find_best_destination_matches_tolerates_a_typo():
    # "Nuwra eliya" (missing the second 'a') should still resolve to Nuwara Eliya —
    # this is the whole reason fuzzy matching replaced exact substring matching.
    matches = _find_best_destination_matches("3 day trip to Nuwra eliya", _DESTINATIONS)
    assert matches
    assert matches[0]["name"] == "Nuwara Eliya"


def test_find_best_destination_matches_falls_back_to_region_when_no_name_matches():
    # "Colombo" names no specific destination, but Galle Face Green is IN Colombo.
    matches = _find_best_destination_matches("A weekend trip in Colombo", _DESTINATIONS)
    assert matches
    assert all(d["region"] == "Colombo" for d in matches)


def test_find_best_destination_matches_returns_empty_when_nothing_matches():
    matches = _find_best_destination_matches("A trip to Antarctica", _DESTINATIONS)
    assert matches == []


def test_extract_day_regions_parses_a_multi_region_itinerary():
    objective = "5 day trip. 1 day - colombo, 2 day - central, 3 day - southern"
    known_regions = {"Colombo", "Central", "Southern"}

    day_regions = _extract_day_regions(objective, known_regions)

    assert day_regions == {1: "Colombo", 2: "Central", 3: "Southern"}


def test_extract_day_regions_is_empty_for_a_single_region_objective():
    known_regions = {"Colombo", "Central", "Southern"}
    assert _extract_day_regions("A 3 day trip to Kandy", known_regions) == {}
