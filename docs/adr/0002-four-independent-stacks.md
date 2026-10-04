# ADR 0002: Four Independent Codebases Instead of a Monorepo Framework

## Status
Accepted

## Context
CEYLORA needs: a public-facing mobile app for tourists (Flutter), an admin/operations panel for staff (web), a REST API + data layer (backend), and an AI trip-planning capability (LLM-driven, multi-step). These have very different runtime and deployment needs.

## Decision
Keep each concern as its own top-level folder/project with its own toolchain, rather than forcing everything into one framework (e.g. a single Node/Next.js app, or a Flutter web admin panel reusing the mobile codebase):
- `backend/CeyloraAPI` — ASP.NET Core 8 Web API + EF Core + PostgreSQL (Npgsql), JWT auth.
- `frontend-react` — React 19 + Vite admin panel (Axios → backend REST API).
- `mobile-flutter` — Flutter app (tourists, guides, vehicle owners), Provider for state, talks to the same backend REST API.
- `agentic-ai` — Python FastAPI micro-service running a LangGraph multi-agent workflow (Planner → Domain Analysis → Action → Validation), called **only** by the backend (never directly by the clients).

## Consequences
- Each stack can use the idiomatic tools of its ecosystem (xUnit, Vitest, flutter_test, pytest) instead of a lowest-common-denominator test/build setup.
- CI (`.github/workflows/`) is 4 small, independently-triggered pipelines (path-filtered) instead of one monolithic one — a change to the mobile app does not need to rebuild/retest the backend.
- Trade-off: no shared types across stacks (e.g. a `Booking` DTO is defined separately in C#, JS and Dart) — accepted because the REST API is the only integration point and keeping each client idiomatic was judged more valuable than cross-language codegen for a project of this size.
