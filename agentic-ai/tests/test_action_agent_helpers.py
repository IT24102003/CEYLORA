import pytest

from agents.action_agent import (
    _extract_group_size,
    _vehicle_type_for_group,
    _extract_trip_days,
)


@pytest.mark.parametrize(
    "objective,expected",
    [
        ("A 3 day trip for 7 people", 7),
        ("Trip for 2 persons to Galle", 2),
        ("Honeymoon trip for a couple of us", 2),
        ("3 day trip to Kandy", 1),  # no group size mentioned -> default 1
        ("Trip for three people to Ella", 3),
    ],
)
def test_extract_group_size(objective, expected):
    assert _extract_group_size(objective) == expected


def test_extract_group_size_does_not_match_a_number_word_with_nothing_after_it():
    # "a couple" on its own, with no trailing "people"/"of us"/etc., is too ambiguous
    # to read as a headcount ("a couple of days"? "a couple of photos"?) — must fall
    # back to the default of 1 rather than guessing 2 from "couple" alone.
    assert _extract_group_size("Honeymoon trip for a couple") == 1


def test_extract_group_size_does_not_mistake_a_day_count_for_a_headcount():
    # "5 day trip" alone (no "people"/"pax" nearby) must not be read as 5 people.
    assert _extract_group_size("A 5 day trip to Ella") == 1


@pytest.mark.parametrize(
    "group_size,expected_type",
    [(1, "Car"), (4, "Car"), (5, "Van"), (8, "Van"), (9, "Bus"), (20, "Bus")],
)
def test_vehicle_type_for_group(group_size, expected_type):
    assert _vehicle_type_for_group(group_size) == expected_type


@pytest.mark.parametrize(
    "objective,expected_days",
    [
        ("A 3 day trip to Kandy", 3),
        ("5-day trip for 4 people", 5),
        ("A two day trip to Galle", 2),
        ("Plan my trip to Ella", 2),  # no duration mentioned -> default 2
        ("A 45 day trip", 30),  # capped at 30 against a malformed/very long prompt
    ],
)
def test_extract_trip_days(objective, expected_days):
    assert _extract_trip_days(objective) == expected_days
