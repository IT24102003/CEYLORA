from datetime import datetime

from state.workflow_state import new_workflow_state, log_step


def test_new_workflow_state_has_sensible_defaults():
    state = new_workflow_state("wf-1", "3 day trip to Kandy")

    assert state["workflow_id"] == "wf-1"
    assert state["objective"] == "3 day trip to Kandy"
    assert state["booking_id"] is None
    assert state["tourist_country"] is None
    assert state["plan"] is None
    assert state["matched_guide"] is None
    assert state["matched_vehicle"] is None
    assert state["validation_passed"] is None
    # High-impact action (real guide/vehicle/booking) — every fresh workflow must start
    # out requiring human approval before anything is actually booked.
    assert state["requires_approval"] is True
    assert state["approval_status"] == "pending"
    assert state["execution_log"] == []
    assert state["status"] == "running"
    assert state["error"] is None


def test_new_workflow_state_carries_booking_id_and_tourist_country():
    state = new_workflow_state("wf-2", "Plan my trip", booking_id=42, tourist_country="Germany")

    assert state["booking_id"] == 42
    assert state["tourist_country"] == "Germany"


def test_log_step_appends_an_entry_with_agent_step_and_timestamp():
    state = new_workflow_state("wf-3", "objective")

    log_step(state, "PlannerAgent", "create_plan", "1. Find destinations")

    assert len(state["execution_log"]) == 1
    entry = state["execution_log"][0]
    assert entry["agent_name"] == "PlannerAgent"
    assert entry["step_name"] == "create_plan"
    assert entry["output"] == "1. Find destinations"
    datetime.fromisoformat(entry["timestamp"])  # must be a valid ISO timestamp


def test_log_step_truncates_long_output_to_keep_the_log_readable():
    state = new_workflow_state("wf-4", "objective")
    long_output = "x" * 1000

    log_step(state, "ActionAgent", "find_guide_and_vehicle", long_output)

    assert len(state["execution_log"][0]["output"]) == 500


def test_log_step_appends_without_overwriting_earlier_entries():
    state = new_workflow_state("wf-5", "objective")
    log_step(state, "PlannerAgent", "create_plan", "step 1")
    log_step(state, "DomainAnalysisAgent", "search_destinations_and_hotels", "step 2")

    assert len(state["execution_log"]) == 2
    assert state["execution_log"][0]["agent_name"] == "PlannerAgent"
    assert state["execution_log"][1]["agent_name"] == "DomainAnalysisAgent"
