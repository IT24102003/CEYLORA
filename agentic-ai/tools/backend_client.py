import httpx
import os
from dotenv import load_dotenv

load_dotenv()

BACKEND_API_URL = os.getenv("BACKEND_API_URL", "http://localhost:5220/api")


async def get_destinations(region: str = None, category: str = None, search: str = None):
    """Calls the ASP.NET Core Destinations API to fetch matching destinations."""
    params = {}
    if region:
        params["region"] = region
    if category:
        params["category"] = category
    if search:
        params["search"] = search
    params["pageSize"] = 10

    async with httpx.AsyncClient() as client:
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

    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BACKEND_API_URL}/hotels", params=params)
        response.raise_for_status()
        return response.json()


 
# Student 2 additions: Action/Tool Agent backend calls (Guides, Vehicles, Packages)
 
async def find_available_guide(region: str, language: str = None):
    """Calls the ASP.NET Core Guides API to find an available guide."""
    params = {"region": region, "available": "true", "pageSize": 5}
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BACKEND_API_URL}/guides", params=params)
        response.raise_for_status()
        items = response.json().get("items", [])

    if language:
        matched = [
            g for g in items
            if g.get("languages") and language.lower() in g["languages"].lower()
        ]
        if matched:
            return matched[0]

    return items[0] if items else None


async def find_available_vehicle(region: str, min_capacity: int = 1):
    """Calls the ASP.NET Core Vehicles API to find an available vehicle."""
    params = {"region": region, "available": "true", "pageSize": 5}
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BACKEND_API_URL}/vehicles", params=params)
        response.raise_for_status()
        items = response.json().get("items", [])

    suitable = [v for v in items if v.get("capacity", 0) >= min_capacity]
    return suitable[0] if suitable else None


async def check_package_price(package_id: int, group_size: int, travel_date: str):
    """Calls the ASP.NET Core Packages API quote endpoint for dynamic pricing."""
    body = {"groupSize": group_size, "travelDate": travel_date}
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{BACKEND_API_URL}/packages/{package_id}/quote", json=body
        )
        response.raise_for_status()
        return response.json()