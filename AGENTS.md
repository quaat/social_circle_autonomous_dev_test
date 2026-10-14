# Agent instructions for SocialCircle

These are the durable development rules for every agent that works in this
repository: the Agent Sparring stage agent (Claude Code), the independent
sparring reviewer (Codex, read-only), and any interactive session.
`.sparring/PROJECT.md` carries the project context that the engine injects
into every managed turn; `docs/architecture/` carries the design. When they
disagree with the code, the code is the fact and the discrepancy is a finding.

## What this project is

SocialCircle is a small social-network demonstration app: register, sign in,
maintain a profile, find other members, follow and unfollow them. It exists to
showcase staged, independently reviewed agentic development with Agent
Sparring. Synthetic test accounts only; it is not meant for public deployment.

## Repository map

| Path | Owner / purpose |
| --- | --- |
| `backend/` | FastAPI service (`src/socialcircle/`), `tests/`, `alembic/`, `pyproject.toml`, `uv.lock` |
| `frontend/` | Angular app (`src/`), Playwright E2E (`e2e/`), `package.json`, `package-lock.json` |
| `docs/architecture/` | `ARCHITECTURE.md` (design and invariants), `API.md` (the `/api/v1` contract) |
| `docs/plans/` | reviewed staged plans run by Agent Sparring; never edit a plan while a run executes it |
| `docs/demo/` | VS Code workflow guide and the sparring showcase evidence summary |
| `.sparring/` | `project.toml` and `PROJECT.md` are tracked; `stages/`, `plans/`, `intake/` are engine runtime state, git-ignored, never edited by agents |
| `compose.yaml`, `.env.example`, `Makefile` | local development contract (see "Commands") |
| `.github/workflows/` | CI that runs `make check` and the E2E suite on a fresh checkout |

## Commands

The `Makefile` is the command contract. Use it rather than ad-hoc invocations
so that the reviewer, CI and humans run the same thing:

```sh
make setup       # toolchains + dependencies + .env + test database
make up          # docker compose: db, backend, frontend
make down
make migrate     # alembic upgrade head (host, against DATABASE_URL)
make test        # backend pytest (real PostgreSQL) + Angular unit tests
make lint        # ruff + eslint
make typecheck   # mypy + tsc
make e2e         # Playwright against the running stack
make check       # lint + typecheck + test
```

Backend tooling is `uv` (`cd backend && uv run …`); frontend tooling is npm
with the scripts in `frontend/package.json`. Dependency lockfiles (`uv.lock`,
`package-lock.json`) are committed and installs use them (`uv sync --frozen`,
`npm ci`).

## Architectural boundaries

- One FastAPI application created by a factory (`create_app()`), one
  PostgreSQL database, no microservices, no message queues.
- HTTP handlers (routers) only parse requests, call a service function and
  shape the response. Business rules live in service modules that take a
  SQLAlchemy `Session` and typed inputs. Database models are never returned
  from endpoints: every response goes through a Pydantic schema.
- Database sessions are dependency-injected (`Depends(get_db)`) and tests
  override the dependency; nothing opens a global engine at import time.
- Schema changes are Alembic migrations, hand-reviewed, one per change,
  committed with the code that needs them. `alembic upgrade head` on an empty
  database must always succeed; `alembic check` must report no drift.
- The frontend talks to the backend only through `/api/v1`, same-origin, via
  the Angular dev-server proxy in development. No other frontend frameworks or
  state-management libraries. Standalone components, `inject()`, signals,
  typed reactive forms, strict TypeScript.

## Security invariants (never weaken)

- Passwords are hashed with Argon2id (`argon2-cffi`); the hash is never
  returned by any API and plaintext passwords never appear in logs.
- Sessions are opaque random tokens stored server-side as a SHA-256 hash with
  an expiry and a revocation timestamp; the browser holds the raw token only in
  an `HttpOnly`, `SameSite=Lax` cookie (`Secure` when `SESSION_COOKIE_SECURE`).
- Every state-changing request authenticated by cookie must carry a CSRF
  token (`X-XSRF-TOKEN` header matching the `XSRF-TOKEN` cookie); the server
  rejects mismatches with 403 before touching any data.
- Authorization is server-side: a user may only edit their own profile; the
  public profile schema never includes email, password hash or session data.
- Uniqueness (email, username, one follow per pair) and the no-self-follow
  rule are database constraints, not just application checks.
- Only bound-parameter queries through SQLAlchemy; no string-built SQL.
- Invalid input yields a structured error response; unexpected exceptions
  never leak stack traces to clients.
- No secrets in Git: configuration comes from environment variables, with
  development defaults documented in `.env.example` only.

## Code conventions

- Python 3.12+ typing throughout, `ruff` clean (lint and format), `mypy`
  clean in strict mode for `src/`. Pydantic v2 models for all request and
  response schemas; SQLAlchemy 2.x declarative models with `Mapped[]`.
- Angular: standalone components, OnPush change detection where practical,
  accessible forms (labels, `aria-*`, focus management), responsive SCSS
  without a CSS framework. Keep components small and services typed.
- Tests are deterministic: backend integration tests run against the real
  test database with per-test isolation; unit tests do not touch the network.
  E2E tests create their own synthetic accounts and never depend on prior
  state.
- Commit messages: short imperative subject, optional body explaining why.

## Git policy for agents

- Work only on the branch you were given; never switch, rebase or force-push.
- Commit completed, tested stage work on that branch. **Do not push.** The
  Agent Sparring engine pushes verified candidates once a person has
  authorized the push (per candidate, or for the whole run). This is a
  deliberate human checkpoint of the showcase.
- Never commit `.env`, credentials, `node_modules/`, build output or
  `.sparring/stages|plans|intake`.

## Agent Sparring rules

- The plan under `docs/plans/` is read-only input while a run executes it;
  record progress in your handoff, not in the plan.
- Never create, edit or delete anything under `.sparring/stages/`,
  `.sparring/plans/` or `.sparring/intake/`.
- Keep `.sparring/PROJECT.md` truthful: when a stage changes commands, ports
  or the test baseline, update the **Baseline** section with what you
  actually observed (command and result), never with expected results.
- A stage is done when its acceptance criteria are met **and** `make check`
  passes on a clean tree, with the evidence (exact commands and outcomes)
  stated in the handoff. Do not claim a test passed that you did not run.
- Stay inside the stage's scope. Do not start the next stage's work, and do
  not add features outside the plan.

## For the independent reviewer

Your sandbox is read-only. Verify claims against the repository (diffs,
tests, migrations, schemas) and treat the stage agent's test reports as
claims. Hold the candidate to the security invariants above, the API contract
in `docs/architecture/API.md`, and the stage's own acceptance criteria.
Require evidence, not assurances.
