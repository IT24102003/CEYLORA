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