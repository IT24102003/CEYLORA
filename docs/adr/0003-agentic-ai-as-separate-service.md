# ADR 0003: AI Trip Planning as a Separate Python Service, Not In-Process in the Backend

## Status
Accepted

## Context
Trip planning needs an LLM-driven, multi-step reasoning workflow (interpret the tourist's objective → match destinations/hotels → pick a guide + vehicle → validate feasibility). The rest of the backend is ASP.NET Core/C#. The best-supported agent-orchestration tooling available (LangGraph, LangChain) is Python-first.

## Decision
Run the agent workflow as its own FastAPI service (`agentic-ai/`) with a 4-node LangGraph state graph:
1. **Planner Agent** — turns the free-text objective into a structured plan.
2. **Domain Agent** — fuzzy-matches destinations/regions from the plan against the real catalogue (difflib-based matching, tested without any LLM/network call).
3. **Action Agent** — looks up an available guide + vehicle for the matched region/dates via the backend's own REST endpoints.
4. **Validation Agent** — runs deterministic business-rule checks (guide/vehicle/destinations all resolved) and always sets `requires_approval = true` so a human (Admin) signs off before a plan is committed.

The ASP.NET Core backend calls this service over HTTP (`AgentWorkflowController` → `agentic-ai`'s `/agent/run`), persists the result (`AgentWorkflow` + `AgentExecutionLog` tables), and is the **only** caller — React/Flutter never call the Python service directly.

## Consequences
- The two most volatile concerns (LLM prompting/orchestration vs. relational data/auth/business rules) can evolve independently and be deployed/scaled separately.
- The backend stays a thin, auditable proxy: every agent run is logged to `AgentExecutionLog` regardless of which service produced it.
- Trade-off: an extra network hop and an extra service to keep running/deployed (see ADR 0004 on test isolation of this service, since it has no CI dependency on a live Ollama LLM).
