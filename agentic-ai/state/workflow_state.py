from typing import TypedDict, Optional, List, Dict, Any
from datetime import datetime

class WorkflowState(TypedDict):
    # THE Identification
    workflow_id: str
    booking_id: Optional[int]

    # Input
    objective: str
    # The tourist's home country (from their profile), passed in by the
    # backend so the Action Agent can try to match a guide who speaks their
    # language.
    tourist_country: Optional[str]

    # Planning (set by Planner Agent)
    plan: Optional[List[Dict[str, Any]]]

    # Domain Analysis output (set by Domain Analysis Agent)
    candidate_destinations: Optional[List[Dict[str, Any]]]
    candidate_hotels: Optional[List[Dict[str, Any]]]
    matched_region: Optional[str]
    # 🔥 Multi-region itinerary support: {"1": {"region": "Colombo",
    # "destinations": [...], "hotels": [...]}, "2": {...}, ...} for a
    # "1 day - colombo, 2 day - kandy, ..." style objective. None when the
    # objective didn't spell out per-day regions (the usual single-region
    # case, which still uses candidate_destinations/candidate_hotels above).
    day_plan: Optional[Dict[str, Dict[str, Any]]]

    # Action/Tool output (set by Action Agent)
    proposed_itinerary: Optional[List[Dict[str, Any]]]
    matched_guide: Optional[Dict[str, Any]]
    matched_vehicle: Optional[Dict[str, Any]]
    group_size: Optional[int]

    # Validation output (set by Validation Agent)
    validation_passed: Optional[bool]
    validation_errors: Optional[List[str]]

    # Approval
    requires_approval: bool
    approval_status: str  # "pending", "approved", "rejected", "revision_requested"

    # Execution log (for observability / audit)
    execution_log: List[Dict[str, Any]]

    # Final outcome
    status: str  # "running", "completed", "failed"
    error: Optional[str]


def new_workflow_state(
    workflow_id: str,
    objective: str,
    booking_id: Optional[int] = None,
    tourist_country: Optional[str] = None,
) -> WorkflowState:
    """Creates a fresh workflow state with sensible defaults."""
    return WorkflowState(
        workflow_id=workflow_id,
        booking_id=booking_id,
        objective=objective,
        tourist_country=tourist_country,
        plan=None,
        candidate_destinations=None,
        candidate_hotels=None,
        matched_region=None,
        day_plan=None,
        proposed_itinerary=None,
        matched_guide=None,
        matched_vehicle=None,
        group_size=None,
        validation_passed=None,
        validation_errors=None,
        requires_approval=True,
        approval_status="pending",
        execution_log=[],
        status="running",
        error=None,
    )


def log_step(state: WorkflowState, agent_name: str, step_name: str, output: Any) -> None:
    """Appends an entry to the execution log — used for observability/audit (spec requirement)."""
    state["execution_log"].append({
        "agent_name": agent_name,
        "step_name": step_name,
        "output": str(output)[:500],  # truncate to keep log readable
        "timestamp": datetime.utcnow().isoformat(),
    })

