# ADR 0005: Four Path-Filtered GitHub Actions Pipelines Instead of One Combined Workflow

## Status
Accepted

## Context
Each of the 4 stacks has its own test runner (`dotnet test`, `npm test` via Vitest, `flutter test`, `pytest`) and its own dependency install step. A single combined workflow would either always run all 4 test suites on every push (wasting CI minutes on unrelated changes) or need complex conditional logic inside one YAML file.

## Decision
Create one workflow file per stack under `.github/workflows/`:
- `backend-tests.yml`, `frontend-tests.yml`, `mobile-tests.yml`, `agentic-ai-tests.yml`

Each is scoped with `paths:` filters to its own folder (plus the workflow file itself, so editing the pipeline also re-triggers it), and runs on both `push` to `main` and `pull_request`.

## Consequences
- A change to only `mobile-flutter/` triggers only the Flutter pipeline — the other 3 stay untouched, keeping CI feedback fast and minutes low.
- Each pipeline's failure is unambiguous about which stack broke, without needing to read job names inside a combined run.
- Known operational gotcha hit during setup: GitHub repository settings can mark `.github/workflows/*.yml` as protected from certain automated write paths — these files had to be delivered as plain downloads and placed manually by a human with write access, which is expected/normal for workflow files (GitHub treats workflow-file changes as higher-privilege by design).
