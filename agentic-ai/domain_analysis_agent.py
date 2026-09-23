from typing import Dict, Any, List
from tools import search_destinations, search_hotels

class DomainAnalysisAgent:
    """
    Agent 2: Domain Analysis Agent (Student 1)
    Responsibility: Takes structured plan, executes search_destinations & search_hotels tools, and ranks candidate destinations & hotels.
    """
    def __init__(self, name: str = "Domain Analysis Agent"):
        self.name = name

    def execute_domain_matching(self, plan: Dict[str, Any]) -> Dict[str, Any]:
        prefs = plan.get("extractedPreferences", {})
        target_region = prefs.get("targetRegion", "Hill Country")
        budget_cap = prefs.get("budgetCapLKR", 40000.0)

        # 1. Tool Call: search_destinations
        destinations = search_destinations(region=target_region)
        if not destinations:
            destinations = search_destinations() # fallback to all

        # 2. Tool Call: search_hotels
        max_hotel_price = budget_cap * 0.5 # Allocate 50% budget cap to hotel stay
        hotels = search_hotels(region=target_region, max_price=max_hotel_price)
        if not hotels:
            hotels = search_hotels(region=target_region)

        # Ranking candidate items
        selected_destinations = destinations[:2] if len(destinations) >= 2 else destinations
        selected_hotel = hotels[0] if hotels else None

        result = {
            "agent": self.name,
            "matchedRegion": target_region,
            "destinationsCount": len(destinations),
            "matchedDestinations": selected_destinations,
            "recommendedHotel": selected_hotel,
            "status": "Success",
            "summary": f"Found {len(destinations)} destinations and selected {selected_hotel['name'] if selected_hotel else 'N/A'} for region {target_region}."
        }
        return result
