# AGENTS.md (root)

Entry point for any agent session in this repository (MVS ERP monorepo).
This file is a mandatory first step for planning and execution.

## Language rule (mandatory)

- Code comments, documentation, and commit messages are written in **English only**.
- User-facing UI strings and runtime messages stay in Russian (the product language) — do not translate them.
- Existing instructions below are kept in English; treat them as the single source of truth.

## Rule #1 — read AGENTS.md before any work

Any session in any workspace of this repository **starts by reading
AGENTS.md** — and not just once:

1. **At session start** — read this root file.
2. **Before each new task** (even within the same session) — re-read the
   AGENTS.md of the services the work touches.
3. **After a context switch** (long break, new task, someone else's diff) —
   re-read is mandatory: rules change, memory goes stale.

Never rely on "I already read it" — rule files are alive.

## Reading order per service

The repository is a monorepo of two git-submodule services. Before working,
read the rules of the affected services:

| Service | Path | When |
|---|---|---|
| Backend (Go) | `services/backend/AGENTS.md` | any backend work |
| Frontend (Vue) | `services/frontend/AGENTS.md` | any frontend work |
| Backend profile rules | `services/backend/.continue/rules/*.md` | work in `internal/**/delivery`, `sqlc`, `internal/auth` |
| Frontend profile rules | `services/frontend/.continue/rules/*.md` | work with the API client, `src/components/` |
| Code review | `services/*/CODE_REVIEW.md` | refactoring, architectural changes, large changes |

## Steps at session start

1. `pwd` — determine the current directory.
2. Read the root `AGENTS.md` (this file).
3. Read the `AGENTS.md` of all affected services (backend and/or frontend).
4. Read the profile `.continue/rules/*.md` and `CODE_REVIEW.md` for the affected areas.
5. Only then start planning/changes.

## Why this matters

- The repository has strict conventions: layered architecture, `{data, error}`
  envelope, "API only in views/composables/store", generated code (sqlc,
  swagger, OpenAPI client) — it must not be hand-edited, regeneration is required.
- Breaking the rules breaks builds/contracts (e.g., editing `src/api/*` is lost
  on regeneration; a new endpoint without swagger does not reach the client).
- Reading AGENTS.md is cheap and eliminates a whole class of errors.

## Verification and rebuild after changes

After any code change, verify and rebuild what was touched:

- **Frontend (Vue)**:
  1. `npm run check` (vue-tsc) and, if needed, `npm run build` in
     `services/frontend/`.
  2. **Rebuild the Electron wrapper**: from `services/frontend/desktop/`
     `npm run dist` / `dist:win` / `dist:linux` (electron-builder). Building
     requires a previously built `services/frontend/dist/`.
  3. Second step — **restart the stack**: from the repository root
     `docker compose down && docker compose up --build -d`.
- **Backend (Go)**: only restart the stack — `docker compose down &&
  docker compose up --build -d` (from the repository root). A desktop build is
  not needed for backend changes.

### Heavy processes — in parallel

Heavy/long commands (vite builds, electron-builder, docker compose rebuild)
should run in **background parallel processes** (run_in_background) rather than
sequentially in one call — this shortens the overall cycle time.
Do not duplicate running work and collect results on completion.

## Repository structure (brief)

- `services/backend` — Go 1.25 / Gin / Wire / sqlc / Flyway (submodule erp-backend).
- `services/frontend` — Vue 3 / TS / Vite / Pinia / Storybook + `desktop/`
  (Electron wrapper) (submodule erp-frontend).
- `nginx/`, `scripts/`, `docker-compose.yml` — stack infrastructure.
- Config and secrets: `config.yaml` (backend) + `.env` (secrets only).