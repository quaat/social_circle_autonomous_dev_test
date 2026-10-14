# SocialCircle

A deliberately small social network — register, sign in, keep a profile, find
other members, follow and unfollow them — built to **demonstrate staged,
independently reviewed agentic development** with
[Agent Sparring](https://github.com/sigmundas/agent-sparring) and its
[VS Code extension](https://github.com/sigmundas/agent-sparring-vscode).
Claude Code implements each stage; Codex reviews it independently; the engine
accepts only a reviewed, pushed commit.

Synthetic test accounts only. Not intended for public deployment (see
"Before public deployment" in `docs/architecture/ARCHITECTURE.md`).

## Status

**Bootstrap.** The repository currently contains the architecture, the API
contract, the agent instructions, the Agent Sparring configuration and the
six-stage plan. The application itself (`backend/`, `frontend/`,
`compose.yaml`, CI) is produced by running the plan:

| Stage | Delivers |
| --- | --- |
| 1 | Project foundation: FastAPI + Angular skeletons, PostgreSQL, Compose, Alembic, lint/type/test tooling, CI, clean baseline |
| 2 | Registration and authentication (Argon2id, server-side sessions, CSRF) |
| 3 | Profile API, member search, follow/unfollow |
| 4 | Angular registration, login, profile and editor UI |
| 5 | Member directory, member detail and follow controls |
| 6 | End-to-end journey test, seed data, demo walkthrough, docs and security review |

Follow the run in `docs/demo/vscode-workflow.md`; the faithful record of
what the reviewer found lives in `docs/demo/sparring-showcase.md`.

## Stack

Python 3.13 · FastAPI · Pydantic v2 · SQLAlchemy 2.x · Alembic · PostgreSQL 17
· pytest · ruff · mypy · `uv` — Angular 22 (standalone, signals, strict TS)
· Playwright — Docker Compose.

## Quick start (after Stage 1 is accepted)

Prerequisites: Git, Docker with Compose v2, `uv`, Node.js 20+ with npm.

```sh
cp .env.example .env     # or: make env
make setup               # dependencies, Playwright browser, db + test database
make up                  # db :5440, backend :8010, frontend :4200
make migrate             # alembic upgrade head
open http://localhost:4200
```

Default ports are chosen to avoid common collisions and can be changed in
`.env`.

## Commands

```sh
make setup | up | down | migrate
make test        # backend (real PostgreSQL) + Angular unit tests
make lint        # ruff + eslint
make typecheck   # mypy + tsc
make e2e         # Playwright against the running stack
make check       # lint + typecheck + test (what CI runs)
```

`make help` lists everything. Until Stage 1 lands, targets that need
`backend/` or `frontend/` fail with an explicit message instead of silently
succeeding.

## Documentation

- `docs/architecture/ARCHITECTURE.md` — system context, components, data
  model, auth/session design, error handling, security assumptions, tests
- `docs/architecture/API.md` — the `/api/v1` contract
- `docs/plans/socialcircle-mvp.md` — the staged plan Agent Sparring executes
- `docs/demo/vscode-workflow.md` — running and observing the plan in VS Code
- `docs/demo/sparring-showcase.md` — tool versions, actual review outcomes,
  accepted commits, limitations
- `AGENTS.md` / `CLAUDE.md` — rules for agents working here
- `.sparring/PROJECT.md` — context injected into every Agent Sparring turn

## Agent Sparring in this repository

```sh
sparring check-config                                   # setup is sane
sparring check-plan docs/plans/socialcircle-mvp.md      # lists the six stages, runs nothing
sparring run-plan docs/plans/socialcircle-mvp.md --managed --target-branch main   # CLI route
sparring runs --json                                    # managed runs and their worktrees
```

The recommended route is VS Code: **Agent Sparring: Run Plan** → **Run in its
own workspace (recommended)**. The engine creates a worktree and branch,
runs implementation and review stage by stage, pauses when a person is
needed, and **Merge & clean up** integrates the result.

## License

Not chosen yet. Add a `LICENSE` file before sharing the repository publicly.
