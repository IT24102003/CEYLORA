import os
import requests
from typing import List, Dict, Any, Optional

BACKEND_API_URL = os.getenv("BACKEND_API_URL", "http://localhost:5000/api")

def search_destinations(region: Optional[str] = None, category: Optional[str] = None, search: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Allow-listed Tool: Queries the CEYLORA backend DB for destinations.
    """
    url = f"{BACKEND_API_URL}/destinations"
    params = {}
    if region: params["region"] = region
    if category: params["category"] = category
    if search: params["search"] = search
    
    try:
        response = requests.get(url, params=params, timeout=5)
        if response.status_code == 200:
            return response.json()
        print(f"[Tool: search_destinations] Warning HTTP {response.status_code}")
    except Exception as e:
        print(f"[Tool: search_destinations] Backend offline/fallback mode: {e}")

    # Fallback mock data if backend API is not yet running locally
    mock_destinations = [
        {"id": 1, "name": "Sigiriya Rock Fortress", "region": "Cultural Triangle", "category": "Historical & Heritage", "description": "Ancient palace rock fortress with frescoes.", "imageUrl": "https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?w=800"},
        {"id": 2, "name": "Nine Arch Bridge Ella", "region": "Hill Country", "category": "Nature & Adventure", "description": "Iconic colonial viaduct bridge in tea estate.", "imageUrl": "https://images.unsplash.com/photo-1546708973-b339540b5162?w=800"},
        {"id": 3, "name": "Temple of the Sacred Tooth Relic", "region": "Central Province", "category": "Culture & Heritage", "description": "Buddhist temple in Kandy.", "imageUrl": "https://images.unsplash.com/photo-1588598050720-333d02f5a6b7?w=800"},
        {"id": 4, "name": "Mirissa Beach & Coconut Tree Hill", "region": "Southern Coast", "category": "Beach & Relaxation", "description": "Golden beach known for whale watching.", "imageUrl": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800"}
    ]
    if region:
        return [d for d in mock_destinations if region.lower() in d["region"].lower()]
    return mock_destinations

def search_hotels(region: Optional[str] = None, min_stars: Optional[int] = None, max_price: Optional[float] = None) -> List[Dict[str, Any]]:
    """
    Allow-listed Tool: Queries the CEYLORA backend DB for hotels.
    """
    url = f"{BACKEND_API_URL}/hotels"
    params = {}
    if region: params["region"] = region
    if min_stars: params["minStars"] = min_stars
    if max_price: params["maxPrice"] = max_price
    
    try:
        response = requests.get(url, params=params, timeout=5)
        if response.status_code == 200:
            return response.json()
        print(f"[Tool: search_hotels] Warning HTTP {response.status_code}")
    except Exception as e:
        print(f"[Tool: search_hotels] Backend offline/fallback mode: {e}")

    mock_hotels = [
        {"id": 1, "name": "Heritance Kandalama", "region": "Cultural Triangle", "starRating": 5, "pricePerNight": 35000, "description": "Eco-luxury hotel near Sigiriya rock.", "imageUrl": "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800"},
        {"id": 2, "name": "Grand Hotel Nuwara Eliya", "region": "Hill Country", "starRating": 4, "pricePerNight": 24000, "description": "Colonial heritage hotel in tea country.", "imageUrl": "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800"},
        {"id": 3, "name": "Cinnamon Citadel Kandy", "region": "Central Province", "starRating": 4, "pricePerNight": 18000, "description": "Riverside resort in Kandy.", "imageUrl": "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800"}
    ]
    if region:
        return [h for h in mock_hotels if region.lower() in h["region"].lower()]
    return mock_hotels
