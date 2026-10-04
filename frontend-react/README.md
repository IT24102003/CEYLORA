# Admin Panel — React + Vite

The staff-facing dashboard for CEYLORA: manage packages/hotels/destinations/guides/vehicles, review bookings, moderate reviews, approve or reject AI-generated trip plans, and view analytics. Admin-only — login rejects any account that isn't `Role = Admin` on the backend.

## Prerequisites

- Node.js 20+
- The backend API running (see [`../backend/README.md`](../backend/README.md)) — the admin panel calls it over REST via Axios.

## Setup

```
cd frontend-react
npm install
npm run dev
```

Vite serves the dev build (default `http://localhost:5173`). Point `src/services/api.js`'s base URL at wherever the backend is running (defaults to `http://localhost:5220`).

## Running the tests

```
npm test
```

Uses **Vitest** + **React Testing Library** (jsdom environment, configured in `vite.config.js`'s `test` block — there is no separate `vitest.config.js`). Covers: pure utility functions (`src/lib/hooks.test.js`), `AuthContext` (including the **non-Admin login rejection** business rule), `ProtectedRoute`, and the full `LoginPage` flow. Tests are colocated with the source files they test (`*.test.jsx` next to the component). See [ADR 0004](../docs/adr/0004-core-coverage-testing-strategy.md).

```
npm run test:watch   # watch mode while developing
```

## Other scripts

```
npm run build     # production build
npm run lint      # ESLint
npm run preview   # preview the production build locally
```

## Project layout

```
src/
├── components/   # shared UI + ProtectedRoute
├── context/      # AuthContext (login/logout, session persistence)
├── pages/        # one file per admin page (Login, Bookings, Packages, Analytics, ...)
├── services/      # api.js — Axios client to the backend
├── lib/          # formatting/validation helpers
└── test/         # Vitest setup (jest-dom matchers)
```
