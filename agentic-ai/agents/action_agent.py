from state.workflow_state import WorkflowState, log_step
from tools.operations_tools import find_guide, find_vehicle, get_package_quote  # noqa: F401
#AGENT ACTION AI

async def action_node(state: WorkflowState) -> WorkflowState:
    """
    Action/Tool Agent (Student 2's contribution).
    Builds the concrete itinerary: finds guide, vehicle, and price quote.
    """
    region = "Kandy"  # TODO: extract dynamically from state["candidate_destinations"]

    guide_result = await find_guide.ainvoke({"region": region})
    vehicle_result = await find_vehicle.ainvoke({"region": region, "min_capacity": 2})

    state["matched_guide"] = {"summary": guide_result}
    state["matched_vehicle"] = {"summary": vehicle_result}
    state["proposed_itinerary"] = [
        {"day": 1, "activity": "Destination visit + hotel check-in"},
        {"day": 2, "activity": "Cultural sightseeing"},
    ]

    log_step(
        state,
        "ActionAgent",
        "find_guide_and_vehicle",
        {"guide": guide_result, "vehicle": vehicle_result},
    )
    return state