# Agentic AI Service — FastAPI + LangGraph

A Python micro-service that turns a tourist's free-text trip objective (e.g. *"5 days around the hill country for a family of 4"*) into a concrete, bookable plan — matched destinations, a selected guide and vehicle, and a day-by-day itinerary — using a 4-agent [LangGraph](https://langchain-ai.github.io/langgraph/) workflow.

**Called only by the ASP.NET Core backend** (`AgentWorkflowController`) — never directly by the React admin panel or the Flutter app. See [ADR 0003](../docs/adr/0003-agentic-ai-as-separate-service.md) for why this is a separate service.

## Agent workflow

```
Planner Agent  →  Domain Agent  →  Action Agent  →  Validation Agent
 (interpret       (match real       (find an         (business-rule
  the objective)   destinations/     available         checks; always
                    regions)          guide + vehicle)  requires_approval)
```

Every run's steps are logged to `AgentExecutionLog` (via the backend) so an Admin can see exactly what the AI decided before approving a plan.

## Prerequisites

- Python 3.12+
- [Ollama](https://ollama.com) running locally (or any OpenAI-compatible endpoint `langchain_ollama` can reach) — only `planner_agent.py` calls the LLM; the rest of the pipeline is deterministic.

## Setup

```
cd agentic-ai
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Environment variables (`.env` or shell):
```
OLLAMA_MODEL=llama3.1          # defaults to llama3.1 if unset
OLLAMA_BASE_URL=http://localhost:11434
```

Run the service:
```
uvicorn main:app --reload --port 8000
```

- `GET /health` — health check
- `POST /agent/run` — `{ "objective": "...", "booking_id": 1, "tourist_country": "Germany" }` → runs the full workflow and returns the final state
- `GET /agent/status/{workflow_id}` — poll a previous run's result

## Running the tests

```
pip install -r requirements.txt -r requirements-dev.txt
pytest
```

`pytest.ini` sets `asyncio_mode = auto` so `async def test_...()` functions work without `@pytest.mark.asyncio`. The suite tests **pure, deterministic code only** — `validation_node`, the regex-based text-extraction helpers in `action_agent.py`, the difflib-based fuzzy-matching helpers in `domain_agent.py`, and `_pick_guide` — plus one full `action_node()` integration test with the network calls **faked via `monkeypatch`** (never a real HTTP call). `planner_agent.py` and `graph.py` (which call a real Ollama LLM) are deliberately not imported by the test suite, keeping it fast and dependency-light. See [ADR 0004](../docs/adr/0004-core-coverage-testing-strategy.md).

## Project layout

```
agentic-ai/
├── main.py              # FastAPI app — /health, /agent/run, /agent/status
├── agents/
│   ├── planner_agent.py     # LLM call — interprets the objective
│   ├── domain_agent.py      # fuzzy-matches destinations/regions
│   ├── action_agent.py      # finds an available guide + vehicle
│   ├── validation_agent.py  # deterministic business-rule checks
│   └── graph.py              # wires the 4 agents into a LangGraph StateGraph
├── tools/
│   ├── backend_client.py    # HTTP calls back into the ASP.NET Core API
│   ├── destination_tools.py
│   └── operations_tools.py
├── state/
│   └── workflow_state.py    # shared WorkflowState dataclass + logging
└── tests/                   # pytest suite (see above)
```

## Deploying on Railway (hosted LLM via Groq)

1. New service from this repo, **Root Directory = `agentic-ai`** (Nixpacks detects Python; the `Procfile` sets the start command).
2. Variables:
   - `GROQ_API_KEY=<your Groq key>` — when set, `planner_agent.py` uses Groq instead of Ollama.
   - `GROQ_MODEL` (optional, default `llama-3.1-8b-instant`)
   - `BACKEND_API_URL=https://<backend-domain>.up.railway.app/api` — the agent calls the CEYLORA backend for destinations, guides, vehicles and pricing.
3. Generate a public domain for the service, then on the **backend** service set `AgenticAI__BaseUrl=https://<agent-domain>.up.railway.app`.

Without `GROQ_API_KEY` the service falls back to local Ollama (`OLLAMA_MODEL`, `OLLAMA_BASE_URL`).
