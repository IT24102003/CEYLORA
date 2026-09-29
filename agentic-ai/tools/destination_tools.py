from langchain_core.tools import tool
from tools.backend_client import get_destinations, get_hotels


@tool
async def search_destinations(region: str = None, category: str = None, search: str = None) -> str:
    """
    Search for tourist destinations in the CEYLORA database.
    Use this to find destinations matching a region (e.g. 'Kandy', 'Central'),
    a category (e.g. 'Historical', 'Nature'), or a free-text search term.
    Returns a list of matching destinations with their names, regions and descriptions.
    """
    result = await get_destinations(region=region, category=category, search=search)
    items = result.get("items", [])

    if not items:
        return "No destinations found matching the criteria."

    summary = "\n".join([
        f"- {d['name']} ({d['region']}, {d.get('category', 'N/A')}): {d.get('description', 'No description')}"
        for d in items
    ])
    return f"Found {len(items)} destination(s):\n{summary}"


@tool
async def search_hotels(region: str = None, min_stars: int = None) -> str:
    """
    Search for hotels in the CEYLORA database.
    Use this to find accommodation options in a region, optionally filtered by minimum star rating.
    Returns a list of matching hotels with pricing information.
    """
    result = await get_hotels(region=region, min_stars=min_stars)
    items = result.get("items", [])

    if not items:
        return "No hotels found matching the criteria."

    summary = "\n".join([
        f"- {h['name']} ({h['starRating']}★, {h['region']}): LKR {h['pricePerNight']}/night, {h['roomsAvailable']} rooms available"
        for h in items
    ])
    return f"Found {len(items)} hotel(s):\n{summary}"