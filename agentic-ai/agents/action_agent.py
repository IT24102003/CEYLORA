import re

from state.workflow_state import WorkflowState, log_step
from tools.backend_client import find_available_guide, find_available_vehicle
# AGENT ACTION AI

# Fixed guide fee, LKR per day (business rule, mirrored on the mobile Trip
# Plan Review screen's cost estimate).
GUIDE_FEE_PER_DAY_LKR = 10000

# 🔥 Maps a tourist's home country to the language a guide should ideally
# speak, so an AI-planned trip tries to match a guide who speaks the
# tourist's language. Not exhaustive — an unmapped/unknown country just means
# no language preference (any available guide, chosen at random).
_COUNTRY_LANGUAGE = {
    "sri lanka": "Sinhala", "india": "Hindi", "china": "Chinese",
    "japan": "Japanese", "south korea": "Korean", "korea": "Korean",
    "france": "French", "germany": "German", "italy": "Italian",
    "spain": "Spanish", "russia": "Russian", "united kingdom": "English",
    "uk": "English", "usa": "English", "united states": "English",
    "america": "English", "australia": "English", "canada": "English",
    "new zealand": "English", "netherlands": "Dutch", "portugal": "Portuguese",
    "brazil": "Portuguese", "saudi arabia": "Arabic", "uae": "Arabic",
    "qatar": "Arabic", "maldives": "English", "singapore": "English",
    "thailand": "Thai", "nepal": "Hindi",
}

_NUMBER_WORDS = {
    "a": 1, "an": 1, "one": 1, "couple": 2, "two": 2, "three": 3, "four": 4,
    "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
}

# 🔥 Rotating set of generic activity descriptions used to flesh out each day
# of the proposed itinerary (the tourist can freely edit/replace these on the
# Trip Plan Review screen). Cycled so a longer trip doesn't just repeat
# "Day 3" endlessly with the same label.
_ACTIVITY_TEMPLATES = [
    "Destination visit + hotel check-in",
    "Cultural sightseeing",
    "Nature & adventure activities",
    "Local cuisine & shopping",
    "Relaxation & scenic views",
    "Free day / optional excursions",
]


def _extract_group_size(objective: str) -> int:
    """
    Pulls a traveller headcount out of the tourist's free-text objective,
    e.g. "3 day trip for 7 people" -> 7. Defaults to 1 (-> a Car) when no
    group size is mentioned at all, as requested.
    """
    text = objective.lower()

    # A number right next to a people-ish word, so "3 day trip" isn't
    # mistaken for a 3-person group.
    digits_near_people = re.search(
        r"(\d+)\s*(?:people|persons?|pax|travell?ers?|tourists?|adults?|"
        r"denek|kenek|dena|kena)",
        text,
    )
    if digits_near_people:
        return max(1, int(digits_near_people.group(1)))

    words_near_people = re.search(
        r"\b(" + "|".join(_NUMBER_WORDS) + r")\b\s*(?:people|persons?|pax|"
        r"of us|denek|kenek|dena|kena)",
        text,
    )
    if words_near_people:
        return max(1, _NUMBER_WORDS[words_near_people.group(1)])

    # Last resort: any standalone 1-2 digit number that isn't immediately
    # followed by "day"/"days" (a day-count, not a headcount).
    for match in re.finditer(r"\b(\d{1,2})\b", text):
        if text[match.end():match.end() + 5].strip().startswith("day"):
            continue
        return max(1, int(match.group(1)))

    return 1


def _vehicle_type_for_group(group_size: int) -> str:
    """Car for small groups, Van for medium, Bus for large groups."""
    if group_size <= 4:
        return "Car"
    if group_size <= 8:
        return "Van"
    return "Bus"


def _extract_trip_days(objective: str) -> int:
    """
    🔥 Pulls the trip's actual requested duration out of the free-text
    objective, e.g. "3 day trip for 7 people" -> 3. Previously
    proposed_itinerary was hardcoded to exactly 2 days no matter what the
    tourist asked for (a "5 day trip" still only showed 2 days on the Trip
    Plan Review screen, with duplicate destinations filling the gap).
    Defaults to 2 days when no duration is mentioned at all. Capped at 30 to
    keep the itinerary sane against a malformed/very long prompt.
    """
    text = objective.lower()

    # 🔥 Per-day plans like "1 day - kandy, 2 day - monaragala, 3 day - galle"
    # are a day-by-day ROUTE, not "a 1 day trip": the old first-match regex
    # below read only the leading "1 day" and produced a 1-day itinerary.
    # When days are listed with a region/place after them ("N day - place" or
    # "day N - place"), the trip length is the highest day number mentioned.
    per_day_numbers = [
        int(a or b)
        for a, b in re.findall(
            r"(?:\bday\s*(\d+)|(\d+)\s*-?\s*day)\s*[-:]\s*[a-z]", text
        )
    ]

    digits_near_day = re.search(r"(\d+)\s*-?\s*day", text)
    if digits_near_day or per_day_numbers:
        # Take the larger of the leading "N day" and the highest listed day,
        # so "5 day trip. 1 day - colombo, 2 day - kandy" stays 5 days while
        # "1 day - kandy, 2 day - galle, 3 day - ella" becomes 3.
        leading = int(digits_near_day.group(1)) if digits_near_day else 0
        return max(1, min(30, max([leading] + per_day_numbers)))

    words_near_day = re.search(
        r"\b(" + "|".join(_NUMBER_WORDS) + r")\b\s*-?\s*day", text
    )
    if words_near_day:
        return max(1, _NUMBER_WORDS[words_near_day.group(1)])

    return 2


async def action_node(state: WorkflowState) -> WorkflowState:
    """
    Action/Tool Agent (Student 2's contribution).
    Builds the concrete itinerary: finds guide, vehicle, and price quote.
    """
    objective = state.get("objective") or ""
    # 🔥 Fix: this was hardcoded to "Kandy" regardless of what the tourist
    # actually asked for. Use the region the Domain Analysis Agent matched
    # from the objective text; fall back to "Kandy" only if nothing matched.
    region = state.get("matched_region") or "Kandy"

    # 🔥 Vehicle: pick Car/Van/Bus by how many people are actually travelling
    # (parsed from the objective), instead of always requesting a flat
    # 2-seat minimum with no type preference.
    group_size = _extract_group_size(objective)
    vehicle_type = _vehicle_type_for_group(group_size)

    # 🔥 Guide: prefer one who speaks the tourist's language, derived from
    # their home country (passed in from the backend). Falls back to a
    # random available guide if nobody matches that language.
    tourist_country = (state.get("tourist_country") or "").strip().lower()
    preferred_language = _COUNTRY_LANGUAGE.get(tourist_country)

    guide = await find_available_guide(region=region, language=preferred_language)
    vehicle = await find_available_vehicle(
        region=region, min_capacity=group_size, vehicle_type=vehicle_type
    )

    # 🔥 matched_guide/matched_vehicle used to be {"summary": "<text>"} with
    # no "id" field at all. The mobile Trip Plan Review screen reads
    # matched_guide["id"] / matched_vehicle["id"] to pre-select the AI's
    # pick, so that "id" being permanently missing meant it always silently
    # fell back to the first guide/vehicle in the full list, regardless of
    # what was actually matched here.
    state["matched_guide"] = guide  # None if nobody is available in the region
    state["matched_vehicle"] = vehicle
    state["group_size"] = group_size

    # 🔥 Fix: used to always be exactly 2 hardcoded days regardless of the
    # trip's actual requested duration (a "3 day trip" or "5 day trip" still
    # only ever got 2 days with the 2nd one duplicating the 1st's
    # destination). Now sized to match what the tourist actually asked for.
    trip_days = _extract_trip_days(objective)
    state["proposed_itinerary"] = [
        {"day": i + 1, "activity": _ACTIVITY_TEMPLATES[i % len(_ACTIVITY_TEMPLATES)]}
        for i in range(trip_days)
    ]

    if guide:
        guide_label = guide.get("name") or f"Guide #{guide.get('id')}"
        guide_summary = (
            f"Guide found: {guide_label} "
            f"(Languages: {guide.get('languages', 'N/A')}, "
            f"Fee: LKR {GUIDE_FEE_PER_DAY_LKR}/day)"
        )
    else:
        guide_summary = f"No available guide found in {region}."

    if vehicle:
        vehicle_summary = f"Vehicle found: {vehicle.get('type')} (Capacity: {vehicle.get('capacity')})"
    else:
        vehicle_summary = (
            f"No available {vehicle_type.lower()} found in {region} "
            f"for {group_size} people."
        )

    log_step(
        state,
        "ActionAgent",
        "find_guide_and_vehicle",
        {
            "group_size": group_size,
            "vehicle_type_needed": vehicle_type,
            "preferred_language": preferred_language,
            "trip_days": trip_days,
            "guide": guide_summary,
            "vehicle": vehicle_summary,
        },
    )
    return state
