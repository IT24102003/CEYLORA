from langchain_core.tools import tool
from tools.backend_client import (
    find_available_guide,
    find_available_vehicle,
    check_package_price,
)


@tool
async def find_guide(region: str, preferred_language: str = None) -> str:
    """
    Find an available tour guide in a given region for CEYLORA.
    Optionally filter by preferred language (e.g. 'English', 'Sinhala').
    Returns the best-matched available guide, or a message if none found.
    """
    result = await find_available_guide(region=region, language=preferred_language)
    if not result:
        return f"No available guide found in {region}."
    # Guides API returns the Guide entity, which has no 'name' field
    # (the name lives on the linked User), so fall back to the guide id.
    label = result.get("name") or f"Guide #{result.get('id', '?')}"
    return (
        f"Guide found: {label} "
        f"(Languages: {result.get('languages', 'N/A')}, "
        f"Rating: {result.get('rating', 'N/A')})"
    )


@tool
async def find_vehicle(region: str, min_capacity: int = 1) -> str:
    """
    Find an available vehicle in a given region for CEYLORA, with at least the
    given passenger capacity.
    Returns the matched vehicle type and capacity, or a message if none found.
    """
    result = await find_available_vehicle(region=region, min_capacity=min_capacity)
    if not result:
        return f"No available vehicle found in {region} with capacity >= {min_capacity}."
    return f"Vehicle found: {result['type']} (Capacity: {result['capacity']})"


@tool
async def get_package_quote(package_id: int, group_size: int, travel_date: str) -> str:
    """
    Get a dynamic price quote for a CEYLORA package, given the group size and
    travel date (YYYY-MM-DD).
    Applies seasonal pricing and group discounts automatically.
    """
    result = await check_package_price(
        package_id=package_id, group_size=group_size, travel_date=travel_date
    )
    if not result:
        return "Could not retrieve a price quote for this package."
    return (
        f"Price quote: LKR {result['finalPricePerPerson']}/person, "
        f"Total: LKR {result['totalPrice']}. {result['pricingNote']}"
    )