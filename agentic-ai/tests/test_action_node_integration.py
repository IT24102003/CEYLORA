from agents import action_agent
from state.workflow_state import new_workflow_state

# BUSINESS-SPECIFIC OPERATION: the Action/Tool Agent's orchestration — turning a free-text
# objective into a concrete (group size -> vehicle type) decision and a guide pick that
# prefers the tourist's own language, exercised end-to-end with the network calls
# (find_available_guide / find_available_vehicle) replaced by fakes via monkeypatch.


async def test_action_node_builds_an_itinerary_sized_to_the_requested_trip_days(monkeypatch):
    async def fake_find_guide(region, language=None):
        return {"id": 1, "name": "Kamal", "languages": "Sinhala,English"}

    async def fake_find_vehicle(region, min_capacity=1, vehicle_type=None):
        return {"id": 2, "type": vehicle_type, "capacity": min_capacity}

    monkeypatch.setattr(action_agent, "find_available_guide", fake_find_guide)
    monkeypatch.setattr(action_agent, "find_available_vehicle", fake_find_vehicle)

    state = new_workflow_state("wf-action-1", "A 5 day trip to Kandy for 7 people")
    state["matched_region"] = "Central"

    result = await action_agent.action_node(state)

    assert len(result["proposed_itinerary"]) == 5
    assert result["group_size"] == 7
    # 7 people falls in the 5-8 tier -> Van, passed straight through to the vehicle lookup.
    assert result["matched_vehicle"]["type"] == "Van"
    assert result["matched_guide"]["name"] == "Kamal"


async def test_action_node_picks_a_guide_who_speaks_the_tourists_language(monkeypatch):
    seen = {}

    async def fake_find_guide(region, language=None):
        seen["language"] = language
        return {"id": 1, "name": "Suresh", "languages": "Hindi"}

    async def fake_find_vehicle(region, min_capacity=1, vehicle_type=None):
        return {"id": 2, "type": vehicle_type, "capacity": min_capacity}

    monkeypatch.setattr(action_agent, "find_available_guide", fake_find_guide)
    monkeypatch.setattr(action_agent, "find_available_vehicle", fake_find_vehicle)

    state = new_workflow_state("wf-action-2", "A 3 day trip to Kandy")
    state["matched_region"] = "Central"
    state["tourist_country"] = "India"  # mapped to Hindi in _COUNTRY_LANGUAGE

    await action_agent.action_node(state)

    assert seen["language"] == "Hindi"


async def test_action_node_handles_no_guide_or_vehicle_available_without_raising(monkeypatch):
    async def fake_find_guide(region, language=None):
        return None

    async def fake_find_vehicle(region, min_capacity=1, vehicle_type=None):
        return None

    monkeypatch.setattr(action_agent, "find_available_guide", fake_find_guide)
    monkeypatch.setattr(action_agent, "find_available_vehicle", fake_find_vehicle)

    state = new_workflow_state("wf-action-3", "A 2 day trip to Galle")
    state["matched_region"] = "Southern"

    result = await action_agent.action_node(state)

    assert result["matched_guide"] is None
    assert result["matched_vehicle"] is None
    # ActionAgent itself never raises on a miss — it just reports what it found (or
    # didn't); it's ValidationAgent's job to turn that into a pass/fail outcome.
    assert len(result["execution_log"]) == 1


async def test_action_node_falls_back_to_kandy_when_no_region_was_matched(monkeypatch):
    seen = {}

    async def fake_find_guide(region, language=None):
        seen["region"] = region
        return None

    async def fake_find_vehicle(region, min_capacity=1, vehicle_type=None):
        return None

    monkeypatch.setattr(action_agent, "find_available_guide", fake_find_guide)
    monkeypatch.setattr(action_agent, "find_available_vehicle", fake_find_vehicle)

    state = new_workflow_state("wf-action-4", "Plan me a nice trip somewhere")
    # matched_region left as None, as Domain Analysis would leave it when nothing matched.

    await action_agent.action_node(state)

    assert seen["region"] == "Kandy"
