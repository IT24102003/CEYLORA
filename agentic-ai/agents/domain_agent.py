from state.workflow_state import WorkflowState, log_step
from tools.destination_tools import search_destinations, search_hotels


async def domain_analysis_node(state: WorkflowState) -> WorkflowState:
    """
    Domain Analysis Agent (Student 1's contribution).
    Matches the objective to actual destinations and hotels in the database.
    """
    destinations_result = await search_destinations.ainvoke({})
    hotels_result = await search_hotels.ainvoke({})

    state["candidate_destinations"] = [{"summary": destinations_result}]
    state["candidate_hotels"] = [{"summary": hotels_result}]

    log_step(state, "DomainAnalysisAgent", "search_destinations_and_hotels",
              {"destinations": destinations_result, "hotels": hotels_result})
    return state