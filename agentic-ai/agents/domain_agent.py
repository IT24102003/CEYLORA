import difflib
import re

from state.workflow_state import WorkflowState, log_step
from tools.destination_tools import search_destinations, search_hotels
from tools.backend_client import get_destinations, get_hotels

# Minimum similarity (0-1) for a window of the objective text to count as
# naming a destination. Tuned loose enough to forgive typos like "Nuwra" for
# "Nuwara" but tight enough not to match unrelated places.
_MATCH_THRESHOLD = 0.72

# 🔥 Matches a per-day region plan written either as "<N> day - <region>" or
# "day <N> - <region>" (dash optional), e.g. "1 day - colombo, 2 day - kandy,
# 3 day - ampara". Used so a multi-region itinerary ("5 day trip. 1 day -
# colombo, 2 day - kandy, ...") seeds each day with ITS OWN region's
# destinations/hotel instead of every day getting the same single
# best-matching region for the whole trip.
_DAY_REGION_RE = re.compile(
    r"(?:day\s*(\d+)|(\d+)\s*day)\s*[-:]?\s*([a-zA-Z][a-zA-Z\s]*?)"
    r"(?=\s*[,.]|\s*(?:day\s*\d+|\d+\s*day)|$)",
    re.IGNORECASE,
)


def _best_window_ratio(words: list, phrase: str) -> float:
    """Best similarity between `phrase` and any same-length run of `words`."""
    phrase_words = phrase.lower().split()
    n = len(phrase_words)
    if n == 0 or len(words) < n:
        return 0.0
    best = 0.0
    for i in range(len(words) - n + 1):
        window = " ".join(words[i:i + n])
        best = max(best, difflib.SequenceMatcher(None, window, phrase.lower()).ratio())
    return best


def _find_best_destination_matches(objective: str, destinations: list) -> list:
    """
    Fuzzy-matches destination NAMES against the free-text objective so small
    typos ("Nuwra eliya" vs "Nuwara Eliya") still resolve correctly. Exact
    substring matching was too strict: any misspelling meant NOTHING matched,
    and the agent silently fell back to the first few destinations in the DB
    instead of the one the tourist actually asked for.

    🔥 Also falls back to matching the destination's REGION when no specific
    destination name matches. A tourist asking for "a 3 day trip in Colombo"
    is naming a region/city, not a specific attraction's name — e.g. the
    destination named "Galle Face Green" has region "Colombo", so searching
    only by name never found anything for a region-only request like this.
    """
    words = re.findall(r"[a-zA-Z]+", objective.lower())

    name_scored = []
    for d in destinations:
        ratio = _best_window_ratio(words, d["name"])
        if ratio >= _MATCH_THRESHOLD:
            name_scored.append((ratio, d))

    if name_scored:
        name_scored.sort(key=lambda pair: pair[0], reverse=True)
        return [d for _, d in name_scored]

    # No destination NAME matched — try matching a REGION instead, and return
    # every destination in the best-matching region.
    regions = {d["region"] for d in destinations if d.get("region")}
    best_region, best_region_ratio = None, 0.0
    for region in regions:
        ratio = _best_window_ratio(words, region)
        if ratio > best_region_ratio:
            best_region, best_region_ratio = region, ratio

    if best_region and best_region_ratio >= _MATCH_THRESHOLD:
        return [d for d in destinations if d.get("region") == best_region]

    return []


def _extract_day_regions(objective: str, known_regions: set) -> dict:
    """
    Parses "<N> day - <region>" / "day <N> - <region>" mentions out of the
    objective (comma-separated lists like "1 day - colombo, 2 day - kandy,
    3 day - ampara" are the expected shape) and fuzzy-matches each named
    region against the regions that actually exist in the DB. Returns
    {day_number: region_name} only for days whose region was confidently
    matched — days not mentioned, or whose region text didn't match
    anything, are simply absent so the caller can fall back for them.
    """
    results = {}
    for m in _DAY_REGION_RE.finditer(objective):
        day_num = int(m.group(1) or m.group(2))
        region_text = (m.group(3) or "").strip()
        if not region_text:
            continue

        words = re.findall(r"[a-zA-Z]+", region_text.lower())
        best_region, best_ratio = None, 0.0
        for region in known_regions:
            ratio = _best_window_ratio(words, region)
            if ratio > best_ratio:
                best_region, best_ratio = region, ratio

        if best_region and best_ratio >= _MATCH_THRESHOLD:
            results[day_num] = best_region

    return results


async def domain_analysis_node(state: WorkflowState) -> WorkflowState:
    """
    Domain Analysis Agent (Student 1's contribution).
    Matches the objective to actual destinations and hotels in the database.
    """
    objective = (state.get("objective") or "")

    # 🔥 Fix: this used to call search_destinations/search_hotels with {} every
    # time, so it always returned whatever happened to be first in the DB's
    # default order (e.g. "Ampara") no matter what the tourist actually typed
    # (e.g. "Nuwara Eliya"). The backend's `search` filter only matches when the
    # destination's NAME *contains* the search term, not the other way around,
    # so passing the whole free-text objective as `search` wouldn't have worked
    # either — a full sentence is never a substring of a short destination name.
    # A first fix used exact substring matching, but that broke on ordinary
    # typos ("Nuwra" instead of "Nuwara"), so this uses fuzzy matching instead.
    all_destinations = await get_destinations(page_size=200)
    matched = _find_best_destination_matches(objective, all_destinations.get("items", []))

    matched_region = matched[0]["region"] if matched else None

    if matched:
        destinations_result = await search_destinations.ainvoke({"search": matched[0]["name"]})
    else:
        # Nothing in the objective matched a known destination name — fall back
        # to a plain listing rather than silently showing the wrong place.
        destinations_result = await search_destinations.ainvoke({})

    hotels_summary = await search_hotels.ainvoke({"region": matched_region} if matched_region else {})
    matched_hotels_raw = await get_hotels(region=matched_region) if matched_region else {}

    # 🔥 Fix: candidate_destinations/candidate_hotels only ever held a single
    # free-text "summary" string meant for the LLM/log, with no destination or
    # hotel IDs in it. The mobile Trip Plan Review screen can't do anything
    # useful with that, so it never even tried to read it — it just filled
    # each day with `_allDestinations[idx % length]` from the FULL unfiltered
    # catalog, completely ignoring whatever the tourist actually asked for.
    # Now we also return the real matched records (with ids) so the mobile
    # app can seed each day with the destination the tourist meant.
    state["candidate_destinations"] = matched if matched else all_destinations.get("items", [])[:5]
    state["candidate_hotels"] = matched_hotels_raw.get("items", []) if matched_region else []
    state["matched_region"] = matched_region

    # 🔥 Multi-region itinerary support: "5 day trip. 1 day - colombo, 2 day -
    # kandy, 3 day - ampara, ..." used to ignore all of that and seed every
    # single day with the one best-matching region for the WHOLE objective
    # text (so all 5 days showed the same Galle destination/hotel). Now each
    # day mentioned with its own region gets its own candidate
    # destinations/hotels, keyed by day number, so the mobile app can seed
    # each day correctly instead of repeating one region.
    all_items = all_destinations.get("items", [])
    known_regions = {d["region"] for d in all_items if d.get("region")}
    day_regions = _extract_day_regions(objective, known_regions)

    day_plan = {}
    for day_num, region in day_regions.items():
        day_destinations = [d for d in all_items if d.get("region") == region]
        day_hotels_raw = await get_hotels(region=region)
        day_plan[str(day_num)] = {
            "region": region,
            "destinations": day_destinations[:5],
            "hotels": day_hotels_raw.get("items", [])[:5],
        }
    state["day_plan"] = day_plan or None

    log_step(state, "DomainAnalysisAgent", "search_destinations_and_hotels",
              {
                  "destinations": destinations_result,
                  "hotels": hotels_summary,
                  "matched_region": matched_region,
                  "day_regions": day_regions,
              })
    return state