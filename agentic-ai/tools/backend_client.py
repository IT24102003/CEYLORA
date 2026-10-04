import httpx
import os
import random
from dotenv import load_dotenv

load_dotenv()

BACKEND_API_URL = os.getenv("BACKEND_API_URL", "http://localhost:5220/api")

# The ASP.NET Core backend talks to a cloud (Supabase) Postgres database, so a
# "cold" connection or a slow network hop can easily take longer than httpx's
# default 5-second timeout. That showed up as httpx.ReadTimeout even though the
# backend WAS reachable — it just hadn't finished the DB round-trip yet.
BACKEND_TIMEOUT = httpx.Timeout(30.0, connect=10.0)


async def get_destinations(region: str = None, category: str = None, search: str = None, page_size: int = 10):
    """Calls the ASP.NET Core Destinations API to fetch matching destinations."""
    params = {}
    if region:
        params["region"] = region
    if category:
        params["category"] = category
    if search:
        params["search"] = search
    params["pageSize"] = page_size

    async with httpx.AsyncClient(timeout=BACKEND_TIMEOUT) as client:
        response = await client.get(f"{BACKEND_API_URL}/destinations", params=params)
        response.raise_for_status()
        return response.json()


async def get_hotels(region: str = None, min_stars: int = None):
    """Calls the ASP.NET Core Hotels API to fetch matching hotels."""
    params = {}
    if region:
        params["region"] = region
    if min_stars:
        params["minStars"] = min_stars
    params["pageSize"] = 10

    async with httpx.AsyncClient(timeout=BACKEND_TIMEOUT) as client:
        response = await client.get(f"{BACKEND_API_URL}/hotels", params=params)
        response.raise_for_status()
        return response.json()


 
# Student 2 additions: Action/Tool Agent backend calls (Guides, Vehicles, Packages)
 
async def _fetch_guides(region: str = None):
    params = {"available": "true", "pageSize": 20}
    if region:
        params["region"] = region
    async with httpx.AsyncClient(timeout=BACKEND_TIMEOUT) as client:
        response = await client.get(f"{BACKEND_API_URL}/guides", params=params)
        response.raise_for_status()
        return response.json().get("items", [])


def _pick_guide(items, language):
    if not items:
        return None
    if language:
        matched = [
            g for g in items
            if g.get("languages") and language.lower() in g["languages"].lower()
        ]
        if matched:
            return random.choice(matched)
    return random.choice(items)


async def find_available_guide(region: str, language: str = None):
    """
    Calls the ASP.NET Core Guides API to find an available guide.
    Prefers a guide who speaks `language` (matched to the tourist's home
    country). 🔥 If no guide speaks that language, picks a RANDOM available
    guide instead of always the same first-in-list one — this used to call
    `items[0]`, so the "no match" case silently always returned the same
    guide no matter who was actually free.

    🔥 If NO guide at all is available in `region` (region has no guides, or
    none are marked available), this now falls back to ANY region instead of
    giving up with None — as requested: "guide kenekwa match une nattam wena
    guide kenekwa danna" (if no guide matches, give a different guide
    instead of nothing). A guide from another region is still a real person
    who can be reassigned/contacted — better than leaving the trip with no
    guide at all; the tourist/admin can always swap them out later.
    """
    items = await _fetch_guides(region=region)
    guide = _pick_guide(items, language)
    if guide:
        return guide

    # Nobody at all available in that specific region — widen to every region.
    items = await _fetch_guides()
    return _pick_guide(items, language)


async def _fetch_vehicles(region: str = None, vehicle_type: str = None):
    params = {"available": "true", "pageSize": 20}
    if region:
        params["region"] = region
    if vehicle_type:
        params["type"] = vehicle_type
    async with httpx.AsyncClient(timeout=BACKEND_TIMEOUT) as client:
        response = await client.get(f"{BACKEND_API_URL}/vehicles", params=params)
        response.raise_for_status()
        return response.json().get("items", [])


async def find_available_vehicle(region: str, min_capacity: int = 1, vehicle_type: str = None):
    """
    Calls the ASP.NET Core Vehicles API to find an available vehicle big
    enough for the group, preferring the right `vehicle_type` ("Car"/"Van"/
    "Bus", chosen by the Action Agent from the tourist's group size).

    🔥 Tries four tiers, each one loosening a constraint, so a 7/20-person
    group actually gets a Van/Bus instead of silently ending up with nothing
    (or, worse, a Car that can't fit them) just because the exact type wasn't
    free in that specific region:
      1. region + type + capacity
      2. region, any type, capacity only (e.g. a bigger Van covers a Bus ask)
      3. type + capacity, ANY region (a vehicle isn't tied to one place the
         way a local guide is — the real per-km fare is priced separately
         from wherever it actually drives)
      4. capacity only, ANY region — last resort before giving up
    Each tier is itself sorted by capacity ascending, so the smallest vehicle
    that still fits everyone is picked (no reason to hand a 40-seat bus to a
    5-person group just because it showed up first).
    """

    def best_fit(items):
        suitable = [v for v in items if v.get("capacity", 0) >= min_capacity]
        if not suitable:
            return None
        suitable.sort(key=lambda v: v.get("capacity", 0))
        return suitable[0]

    # Tier 1: region + type
    items = await _fetch_vehicles(region=region, vehicle_type=vehicle_type)
    match = best_fit(items)
    if match:
        return match

    # Tier 2: region, any type
    if vehicle_type:
        items = await _fetch_vehicles(region=region)
        match = best_fit(items)
        if match:
            return match

    # Tier 3: any region, right type
    if vehicle_type:
        items = await _fetch_vehicles(vehicle_type=vehicle_type)
        match = best_fit(items)
        if match:
            return match

    # Tier 4: any region, any type — last resort
    items = await _fetch_vehicles()
    return best_fit(items)


async def check_package_price(package_id: int, group_size: int, travel_date: str):
    """Calls the ASP.NET Core Packages API quote endpoint for dynamic pricing."""
    body = {"groupSize": group_size, "travelDate": travel_date}
    async with httpx.AsyncClient(timeout=BACKEND_TIMEOUT) as client:
        response = await client.post(
            f"{BACKEND_API_URL}/packages/{package_id}/quote", json=body
        )
        response.raise_for_status()
        return response.json()