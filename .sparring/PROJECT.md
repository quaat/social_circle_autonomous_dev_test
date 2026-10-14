# SocialCircle — project context for Agent Sparring actors

Read with `AGENTS.md` (rules), `docs/architecture/ARCHITECTURE.md` (design)
and `docs/architecture/API.md` (contract). This file is injected into every
stage-agent and reviewer turn; keep it short and **true of the working
tree**.

## Purpose

A minimal social network used to demonstrate staged, independently reviewed
agentic development: register, sign in, maintain a profile, find members,
follow/unfollow. Synthetic accounts only; not for public deployment.

## Stack

- Backend: Python 3.13 (`requires-python >= 3.12`), FastAPI, Pydantic v2,
  pydantic-settings, SQLAlchemy 2.x, Alembic, psycopg 3, uvicorn,
  argon2-cffi; pytest + httpx; ruff; mypy (strict for `src/`); managed by `uv`.
- Frontend: Angular 22 (standalone components, Router, HttpClient, signals,
  typed reactive forms), strict TypeScript, SCSS, angular-eslint, Angular
  unit tests, Playwright E2E; managed by npm with `package-lock.json`.
- Infrastructure: PostgreSQL 17 in Docker, Docker Compose (`db`, `backend`,
  `frontend`), environment-variable configuration (`.env.example`), Alembic
  migrations, `/api/v1/health` and `/api/v1/ready`.

## Directory map

```text
backend/src/socialcircle/   api/ (routers)  services/  db/ (models, session)  core/ (settings, security, errors)
backend/tests/              pytest; integration tests use TEST_DATABASE_URL (real PostgreSQL)
backend/alembic/            migrations (one revision per schema change)
frontend/src/app/           Angular app; frontend/e2e/ Playwright
docs/architecture/          ARCHITECTURE.md, API.md      docs/plans/  staged plans (read-only during a run)
docs/demo/                  VS Code workflow + showcase   .sparring/   project.toml, PROJECT.md (tracked); stages|plans|intake (engine state, ignored)
compose.yaml  .env.example  Makefile  AGENTS.md  CLAUDE.md  README.md  .github/workflows/
```

## Architectural boundaries

- One FastAPI app from `create_app()`, one PostgreSQL database. Routers parse
  and respond; services hold rules and take a SQLAlchemy `Session`; DB models
  are never returned directly; every response is a Pydantic schema.
- Sessions are dependency-injected (`get_db`); tests override dependencies.
- Schema changes only through Alembic; `alembic check` must stay clean.
- Frontend talks only to `/api/v1` via relative URLs (dev proxy);
  no extra UI/state libraries.

## Commands (the `Makefile` is the contract)

| Target | What it runs |
| --- | --- |
| `make setup` | `.env` from example, `uv sync --frozen`, `npm ci`, Playwright Chromium, start `db`, create `socialcircle_test` |
| `make up` / `make down` | `docker compose up -d --build --wait` / `down` |
| `make migrate` | `cd backend && uv run alembic upgrade head` |
| `make test` | `make test-backend` (`uv run pytest -q`) + `make test-frontend` (`npm test -- --watch=false`) |
| `make lint` | `uv run ruff check . && uv run ruff format --check .` + `npm run lint` |
| `make typecheck` | `uv run mypy` + `npm run typecheck` |
| `make e2e` | `npm run e2e` (Playwright against the running stack) |
| `make check` | lint + typecheck + test |

Ports (from `.env`, defaults): frontend 4200, backend 8010, Postgres 5440.
Backend direct run: `cd backend && uv run uvicorn socialcircle.main:app
--reload --port 8010`. Frontend: `cd frontend && npm start`.

## Conventions

- Python: typed, `ruff` clean (check + format), `mypy --strict` for `src/`;
  Pydantic v2 schemas separate from SQLAlchemy models; typed domain errors
  mapped to the error envelope by one handler layer.
- Angular: standalone components, `inject()`, signals, OnPush where
  practical, accessible forms, responsive SCSS, eslint clean, strict TS.
- Tests deterministic and isolated: backend integration tests against the
  real test DB with per-test rollback/truncation; E2E creates its own
  synthetic accounts.
- Commits: imperative subject, body says why. Commit on the given branch;
  never push (the engine pushes authorized candidates).

## Security invariants

Argon2id password hashing; opaque session tokens stored as SHA-256 with
expiry and revocation; `HttpOnly` + `SameSite=Lax` (+ `Secure` when
configured) session cookie; CSRF double-submit (`XSRF-TOKEN` cookie /
`X-XSRF-TOKEN` header) on every cookie-authenticated `POST`/`PATCH`/`DELETE`;
server-side authorization; DB uniqueness and no-self-follow constraints;
bound-parameter queries only; structured errors, no stack traces to clients;
no secrets in Git. Public profile responses never include email, password
hash or session data.

## Migration conventions

One Alembic revision per schema change, hand-reviewed, descriptive slug,
committed with the code that needs it. `alembic upgrade head` on an empty
database must succeed; the new revision's `downgrade` must work; `alembic
check` must report no drift. Migrations are never auto-applied at app start.

## Baseline (verified; update with real results when a stage changes it)

Recorded at bootstrap, before Stage 1 (commit: initial baseline):

- `backend/` and `frontend/` do **not exist yet**. There is no application
  code, no test suite and no CI workflow.
- `make check` exits 2 with
  `error: backend/ does not exist yet — it is created by Stage 1 of docs/plans/socialcircle-mvp.md`
  (observed 2026-10-14 on the bootstrap tree).
- `sparring check-config` exits 0: stage artifacts, plan-run state and plan
  intake are git-ignored; no setup problems.
- Toolchain observed on the bootstrap machine: Python 3.13.5, uv 0.13.1,
  Node 25.9.0 / npm 11.17.0, Docker 29.8.1 with Compose v5.5.1, Git 2.47.3.

Stage 1 establishes the first green baseline and must replace this section
with the commands actually run and their observed results.

## Manual UI checks (only a person can judge)

- Register, login, profile, editor, directory and member pages at 360 px
  and 1280 px: no clipped or overlapping content, no horizontal scroll.
- Keyboard-only navigation through every form with a visible focus ring.
- Text contrast is readable (≥ 4.5:1 for body text).
- The demo walkthrough (`docs/demo/demo-walkthrough.md`, Stage 6) produces
  each documented observation.

## Definition of done (every stage)

1. The stage's acceptance criteria in `docs/plans/socialcircle-mvp.md` are
   met and nothing outside its scope was changed.
2. `make check` passes on a clean tree; `make e2e` passes where the stage
   requires it; migrations up/down/check verified when the schema changed.
3. The security invariants above hold; docs (`README.md`, `API.md`,
   `ARCHITECTURE.md`) match the code.
4. This file's Baseline section states what was actually run and observed.
5. Work is committed on the run branch with a handoff listing exact commands,
   results, and anything unverified. No claim of a test that was not run.
