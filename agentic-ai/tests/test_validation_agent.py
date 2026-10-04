from agents.validation_agent import validation_node
from state.workflow_state import new_workflow_state


def _base_state(**overrides):
    state = new_workflow_state("wf-validation", "3 day trip to Kandy")
    state.update(overrides)
    return state


# Validation/Safety Agent — deterministic business-rule checks, no LLM involved.
# Covers the agent the spec calls out explicitly: a dedicated validation/safety agent.


async def test_validation_fails_when_no_guide_matched():
    state = _base_state(
        matched_guide=None,
        matched_vehicle={"id": 1, "type": "Van"},
        candidate_destinations=[{"id": 1, "name": "Kandy Lake"}],
    )

    result = await validation_node(state)

    assert result["validation_passed"] is False
    assert "No guide could be matched." in result["validation_errors"]
    assert result["status"] == "failed"


async def test_validation_fails_when_no_vehicle_matched():
    state = _base_state(
        matched_guide={"id": 1, "name": "Kamal"},
        matched_vehicle=None,
        candidate_destinations=[{"id": 1, "name": "Kandy Lake"}],
    )

    result = await validation_node(state)

    assert result["validation_passed"] is False
    assert "No vehicle could be matched." in result["validation_errors"]
    assert result["status"] == "failed"


async def test_validation_fails_when_no_destinations_found():
    state = _base_state(
        matched_guide={"id": 1, "name": "Kamal"},
        matched_vehicle={"id": 1, "type": "Van"},
        candidate_destinations=[],
    )

    result = await validation_node(state)

    assert result["validation_passed"] is False
    assert "No destinations found for this objective." in result["validation_errors"]
    assert result["status"] == "failed"


async def test_validation_collects_all_errors_at_once():
    state = _base_state(matched_guide=None, matched_vehicle=None, candidate_destinations=None)

    result = await validation_node(state)

    assert len(result["validation_errors"]) == 3


async def test_validation_passes_when_everything_is_matched():
    state = _base_state(
        matched_guide={"id": 1, "name": "Kamal"},
        matched_vehicle={"id": 1, "type": "Van"},
        candidate_destinations=[{"id": 1, "name": "Kandy Lake"}],
    )

    result = await validation_node(state)

    assert result["validation_passed"] is True
    assert result["validation_errors"] == []
    assert result["status"] == "completed"


async def test_validation_always_requires_human_approval_regardless_of_outcome():
    # Booking a real guide/vehicle is high-impact — approval must never be skipped,
    # whether the plan passed or failed validation.
    passing_state = _base_state(
        matched_guide={"id": 1, "name": "Kamal"},
        matched_vehicle={"id": 1, "type": "Van"},
        candidate_destinations=[{"id": 1, "name": "Kandy Lake"}],
    )
    failing_state = _base_state(matched_guide=None, matched_vehicle=None, candidate_destinations=None)

    passing_result = await validation_node(passing_state)
    failing_result = await validation_node(failing_state)

    assert passing_result["requires_approval"] is True
    assert failing_result["requires_approval"] is True


async def test_validation_logs_the_step():
    state = _base_state(matched_guide=None, matched_vehicle=None, candidate_destinations=None)

    result = await validation_node(state)

    assert len(result["execution_log"]) == 1
    assert result["execution_log"][0]["agent_name"] == "ValidationAgent"
    assert result["execution_log"][0]["step_name"] == "validate_plan"
