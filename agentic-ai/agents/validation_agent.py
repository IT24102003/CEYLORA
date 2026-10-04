#VALIDATION AI 

from state.workflow_state import WorkflowState, log_step


async def validation_node(state: WorkflowState) -> WorkflowState:
    """
    Validation/Safety Agent (Student 2's contribution).
    Deterministic checks - no LLM here, pure business rule validation.
    """
    errors = []

    # matched_guide/matched_vehicle are now the real matched record (a dict)
    # or None if nobody was available — no more "No available" text to sniff
    # out of a summary string.
    if not state.get("matched_guide"):
        errors.append("No guide could be matched.")

    if not state.get("matched_vehicle"):
        errors.append("No vehicle could be matched.")

    if not state.get("candidate_destinations"):
        errors.append("No destinations found for this objective.")

    state["validation_passed"] = len(errors) == 0
    state["validation_errors"] = errors
    state["requires_approval"] = True  # high-impact action always needs human approval
    state["status"] = "completed" if len(errors) == 0 else "failed"

    log_step(
        state,
        "ValidationAgent",
        "validate_plan",
        {"errors": errors, "passed": len(errors) == 0},
    )
    return state