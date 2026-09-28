"""Manual smoke test for the Action + Validation nodes (backend must be running).
Run from the agentic-ai folder:  python -m tests.test_my_agents
"""
import asyncio

from state.workflow_state import new_workflow_state
from agents.action_agent import action_node
from agents.validation_agent import validation_node


async def test_run():
    state = new_workflow_state("test-1", "Plan a 3-day Kandy trip for 2 people")
    state["candidate_destinations"] = [{"summary": "Temple of the Tooth found in Kandy"}]
    state = await action_node(state)
    state = await validation_node(state)
    print(state)


if __name__ == "__main__":
    asyncio.run(test_run())