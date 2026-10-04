# ADR 0004: "Core Coverage" Testing Strategy Across All 4 Stacks

## Status
Accepted

## Context
With 4 independent stacks and a coursework deadline, 100%-coverage testing everywhere is not a realistic goal. We needed one consistent, defensible testing depth that still demonstrates real engineering practice for the module's Testing/CI/Git rubric criterion.

## Decision
Apply the same shape of "Core coverage" to every stack:
1. **Pure/deterministic unit tests** for business logic that doesn't need mocking (pricing calculations, regex-based text extraction, fuzzy destination matching, validators).
2. **CRUD / auth / validation-equivalent tests** for the main user-facing flows (register/login, controller authorization checks, form validation, protected routes).
3. **Exactly one clearly-labelled "business-specific operation" test** per stack — a rule that's easy to get wrong and specific to this domain:
   - Backend: a vehicle **cannot** be re-enabled (`IsAvailable = true`) while it has an active (`Confirmed`/`OnGoing`) trip assignment.
   - React: a login that is cryptographically correct but **not an Admin account** is still rejected by the admin panel.
   - Flutter: `VehicleEditScreen` makes `Type`/`PricePerKm` **read-only** after creation (an owner can rename a vehicle, not re-price it after bookings may already reference it).
   - Python: `action_node()` end-to-end — itinerary length from extracted trip days, vehicle type from group size, guide language from tourist country, graceful `None` handling when nobody's available — with the network calls faked via `monkeypatch`, never a real HTTP call.
4. Network- and LLM-calling code paths (Flutter's `ApiService` singleton HTTP calls, the Python `planner_agent`/real LangGraph `graph.py` execution against Ollama) are **deliberately excluded** rather than mocked at the cost of changing production code just to make it testable — documented inline in the test files/comments, not silently skipped.

## Consequences
- Test suites stay fast (no live network/LLM calls in CI) and meaningful (each one asserts a real business rule, not just "does it render"/"does it return 200").
- A marker/reviewer can find the same testing pattern in all 4 stacks and compare them directly.
- Known gap: `login()`/`register()`/`refreshVerificationStatus()` in Flutter and `planner_agent.py`/`graph.py` in Python are not unit-tested — would need either a DI seam added to `ApiService` or an LLM-call fake, both out of scope for this pass.
