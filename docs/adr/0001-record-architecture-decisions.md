# ADR 0001: Record Architecture Decisions with ADRs

## Status
Accepted

## Context
CEYLORA spans 4 independent tech stacks (ASP.NET Core backend, React admin panel, Flutter mobile app, Python agentic-AI service) built up over many feature branches. Several non-obvious technical choices were made along the way (why Postgres over SQL Server, why a separate Python service instead of doing AI planning in C#, why Provider instead of Bloc/Riverpod, etc.) that are easy to forget the reasoning for later, especially when handing the project to a marker or a new contributor.

## Decision
We record significant, hard-to-reverse architectural decisions as lightweight Architecture Decision Records (ADRs) under `docs/adr/`, numbered sequentially, using the format: Status / Context / Decision / Consequences.

## Consequences
- Future contributors (and the module marker) can see *why* a decision was made, not just *what* was decided.
- ADRs are immutable once accepted — a later change in direction gets a **new** ADR that supersedes the old one, rather than editing history.
