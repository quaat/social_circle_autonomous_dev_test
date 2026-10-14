# SocialCircle MVP — staged Agent Sparring plan

This plan builds SocialCircle, a minimal social network (register, sign in,
profile, member directory, follow/unfollow), in six independently reviewable
stages. It is executed by the Agent Sparring engine: Claude Code implements
each stage, Codex reviews it read-only, and the engine accepts only a pushed,
reviewed commit. Prose above the first stage heading is for the person
approving the plan; agents receive only their own stage section plus
`.sparring/PROJECT.md`, so every stage below is self-contained.

Shared references every stage relies on (read them from the repository):
`AGENTS.md` (rules, command contract, security invariants),
`docs/architecture/ARCHITECTURE.md` (design and invariants),
`docs/architecture/API.md` (the `/api/v1` contract). Product scope is fixed:
no messaging, feeds, recommendations, image uploads, notifications, OAuth,
email, admin tooling or complex social graphs.

## Stage 1 — Project Foundation

**Goal.** A runnable, testable skeleton: FastAPI backend, Angular frontend,
PostgreSQL, Docker Compose, Alembic, linting, type checking, test frameworks,
CI and documentation — with every `make` target in the command contract
working and a recorded clean baseline. No product features yet.

**Scope.**
- `backend/`: a `uv`-managed Python 3.13 project (`pyproject.toml`,
  `uv.lock`, `.python-version`; `requires-python >= 3.12`) with FastAPI,
  Pydantic v2, pydantic-settings, SQLAlchemy 2.x, Alembic, psycopg 3,
  uvicorn, argon2-cffi, pytest, httpx (test client), ruff, mypy. Package
  `src/socialcircle/` with an application factory `create_app()`, settings
  loaded from environment variables (names as in `.env.example`), a
  dependency-injected database session (`get_db`), the uniform error
  envelope and exception handlers from `docs/architecture/API.md`, and the
  `GET /api/v1/health` and `GET /api/v1/ready` endpoints.
- `backend/alembic/`: Alembic configured against `DATABASE_URL`, an initial
  revision (it may be a no-op) so `alembic upgrade head`, `alembic
  downgrade base` and `alembic check` are exercised end to end. The users
  schema is **not** part of this stage.
- `backend/tests/`: pytest configured with a real PostgreSQL test database
  (`TEST_DATABASE_URL`), migrations applied before the session, per-test
  isolation (transaction rollback or truncation), an app/client fixture, and
  tests for health, readiness (including the 503 path with an unreachable
  database) and the error envelope for a validation error and an unknown
  route.
- `frontend/`: an Angular 22 application generated with the Angular CLI
  (standalone, routing, SCSS, strict TypeScript, `npm` lockfile), an
  application shell (header with the SocialCircle name, `<main>` outlet,
  responsive layout), a placeholder home route, `proxy.conf.json` forwarding
  `/api` to `API_PROXY_TARGET` (default `http://localhost:8010`),
  angular-eslint, and npm scripts `start`, `build`, `test`, `lint`,
  `typecheck`, `e2e` so that the `Makefile` targets work unchanged.
- `frontend/e2e/`: Playwright configured to run against the already running
  stack at `http://localhost:${FRONTEND_PORT:-4200}` (no `webServer` block
  that starts servers itself), with one smoke test: the shell renders and
  `GET /api/v1/health` through the proxy returns `{"status":"ok"}`.
- `compose.yaml`: services `db` (`postgres:17`, named volume, health check,
  host port `${POSTGRES_PORT:-5440}`), `backend` (built from
  `backend/Dockerfile`, uvicorn with reload, env from `.env`, depends on a
  healthy `db`, health check on `/api/v1/health`, host port
  `${BACKEND_PORT:-8010}`) and `frontend` (node image running `ng serve
  --host 0.0.0.0` with the proxy pointed at `http://backend:8010`, host port
  `${FRONTEND_PORT:-4200}`). `make up` must bring up all three healthy.
- `.github/workflows/ci.yml`: on push and pull request, on a fresh checkout,
  with a PostgreSQL service: `make setup`-equivalent installs from the
  lockfiles, then `make lint`, `make typecheck`, `make test`; a second job
  runs `make up`, `make migrate` and `make e2e` with Docker Compose. Cache
  `uv` and `npm` downloads.
- Documentation: update `README.md` (prerequisites, quick start, commands,
  ports, troubleshooting) and the **Baseline** section of
  `.sparring/PROJECT.md` with the commands you actually ran and their
  results.

**Expected deliverables.** Everything above, committed on the run branch,
with `make setup`, `make up`, `make migrate`, `make test`, `make lint`,
`make typecheck`, `make e2e` and `make check` all succeeding on this machine.

**Relevant components.** `backend/`, `frontend/`, `compose.yaml`,
`Makefile` (adjust only if a target cannot work as written; keep the target
names and semantics), `.github/workflows/`, `README.md`,
`.sparring/PROJECT.md`.

**Technical constraints.**
- Keep the application factory, dependency-injected sessions and the
  router/service/db separation described in `ARCHITECTURE.md` from the start,
  even though there is little code yet.
- `mypy` strict for `backend/src`; `ruff` with an explicit rule set in
  `pyproject.toml`; `ruff format` as the formatter.
- Angular: standalone components only, no NgModules, strict template type
  checking, no additional UI frameworks or state libraries.
- Ports and credentials only from environment variables with the defaults in
  `.env.example`; never commit `.env`.
- Lockfiles are committed; installs use `uv sync --frozen` and `npm ci`.
- Do not create the users/sessions/follows schema or any auth code.

**Required tests.** Backend: health, readiness (ok and 503), error envelope
(422 shape with `details`, 404 for unknown route). Frontend: the shell
component renders the app name and the outlet. E2E: the smoke test above.

**Acceptance criteria.**
- `make up` starts db, backend and frontend and all report healthy;
  `curl http://localhost:8010/api/v1/ready` returns 200 with
  `"database": "ok"`.
- `make migrate` succeeds on an empty database; `uv run alembic check`
  reports no drift; `downgrade base` then `upgrade head` succeed.
- `make check` passes (ruff, mypy, eslint, tsc, pytest, Angular tests) and
  `make e2e` passes against the running stack.
- The CI workflow is syntactically valid and runs the same targets; its
  first real run is verified later when a remote exists (state this in the
  handoff rather than claiming a green run).
- `README.md` lets a new developer start the stack with documented commands;
  `.sparring/PROJECT.md` Baseline reflects actual results.

**Non-goals.** Any user, session or follow functionality; UI pages beyond the
shell; production Dockerfiles; deployment.

**Dependencies.** None (first stage).

**Human verification.** None required. The reviewer can verify structure,
configuration, tests and CI by reading; actual command results are the stage
agent's reported evidence and may be recorded as deferred if the reviewer
cannot reproduce them in its read-only sandbox.

## Stage 2 — Registration and Authentication

**Goal.** Members can register, sign in, stay signed in across requests,
retrieve their own account and sign out, with the security invariants in
`AGENTS.md` enforced by code, constraints and tests.

**Scope.**
- Alembic migration creating `users` and `sessions` exactly as described in
  `docs/architecture/ARCHITECTURE.md` §3 (UUID PKs, unique lower-cased
  `email` and `username`, `password_hash`, `display_name`, `bio` default
  empty, timestamps; `sessions` with unique `token_hash`, `expires_at`,
  nullable `revoked_at`, FK cascade, index on `user_id`).
- SQLAlchemy models, Pydantic schemas (`RegisterRequest`, `LoginRequest`,
  `PrivateUser`, `PublicProfile` with the validation rules in `API.md`), and
  services for registration (Argon2id hashing, normalization, conflict
  detection backed by the unique constraints), login (constant-time
  verification, identical error for unknown identifier and wrong password),
  session creation (opaque token, SHA-256 at rest, TTL from settings),
  session lookup (rejects expired and revoked) and logout (revocation).
- Endpoints `POST /api/v1/auth/register`, `POST /api/v1/auth/login`,
  `POST /api/v1/auth/logout`, `GET /api/v1/auth/me` with the exact status
  codes, cookies and error codes in `API.md`.
- `get_current_user` dependency (401 `unauthenticated`) and `require_csrf`
  dependency (403 `csrf_failed`) applied to logout; the CSRF cookie and
  header names are `XSRF-TOKEN` / `X-XSRF-TOKEN`.
- `PublicProfile` may return zeroed `follower_count`/`following_count` and
  `viewer_follows: false` until Stage 3 implements follows, but the fields
  must exist.

**Expected deliverables.** Migration, models, schemas, services, routers,
dependencies, tests, updated `API.md` only if a detail had to change (say so
in the handoff), updated `.sparring/PROJECT.md` Baseline.

**Relevant components.** `backend/src/socialcircle/{api,services,db,core}`,
`backend/alembic/versions/`, `backend/tests/`.

**Technical constraints.**
- Argon2id via `argon2-cffi` with library defaults; never log or return
  hashes or raw tokens; the session cookie is `HttpOnly`, `SameSite=Lax`,
  `Path=/`, `Secure` iff `SESSION_COOKIE_SECURE`.
- Login always creates a new session (no fixation); logout revokes rather
  than deletes.
- Uniqueness is decided by the database constraints: the service may
  pre-check, but an `IntegrityError` must still map to the right 409.
- Routers contain no business logic; services take a `Session` and typed
  inputs and raise typed domain errors mapped by the Stage 1 handlers.
- `alembic check` reports no drift after the migration; `downgrade` of the
  new revision works.

**Required tests (backend, real PostgreSQL).**
- Register: success returns 201 `PrivateUser` without `password_hash`, sets
  both cookies; duplicate email and duplicate username (including different
  case) return 409 with the right code; each validation rule in `API.md`
  yields 422 with field `details`; the stored hash is Argon2id and not the
  plaintext.
- Login: by email and by username; wrong password and unknown identifier
  both 401 `invalid_credentials` with identical bodies; a login replaces the
  session cookie with a new token.
- Session: `GET /auth/me` works with the cookie, 401 without it, 401 with an
  expired session, 401 after logout; the session row stores only the hash.
- CSRF: logout without the header → 403 and the session stays valid; with a
  mismatching header → 403; with the matching header → 204.
- Error envelope shape on every failure above.

**Acceptance criteria.** All required tests pass in `make test`; `make
check` passes; `make e2e` smoke still passes; migration up/down/check
verified; no secret or hash appears in any response or log line; handoff
lists the exact commands and results.

**Non-goals.** Profiles beyond `GET /auth/me`, member listing, follows, any
frontend work, password reset, email verification, rate limiting.

**Dependencies.** Stage 1 accepted (app factory, error envelope, test
database fixtures, migrations infrastructure).

**Human verification.** None required.

## Stage 3 — Profile API and Social Connections

**Goal.** Authenticated members can read and edit their own profile, browse
and search other members with pagination, follow and unfollow them, and see
consistent follower/following counts and lists, with privacy and integrity
rules enforced server-side and in the database.

**Scope.**
- Alembic migration creating `follows` (composite PK `(follower_id,
  followed_id)`, `CHECK follower_id <> followed_id`, FKs with cascade, index
  on `followed_id`) plus indexes supporting search on `users.username` and
  `users.display_name`.
- Services and endpoints per `docs/architecture/API.md`: `GET
  /api/v1/users` (search `q`, `limit`/`offset`, ordered by username, total
  count), `GET /api/v1/users/{user_id}`, `PATCH /api/v1/me/profile`, `POST
  /api/v1/users/{user_id}/follow`, `DELETE /api/v1/users/{user_id}/follow`,
  `GET /api/v1/me/following`.
- `PublicProfile` now carries real `follower_count`, `following_count`,
  `viewer_follows` and `is_self`, computed from the `follows` table.
- CSRF enforced on `PATCH` and both follow endpoints; all endpoints require
  a session.

**Expected deliverables.** Migration, models, schemas, services, routers,
tests, `.sparring/PROJECT.md` Baseline update, `API.md` touched only if a
detail had to change (explain in the handoff).

**Relevant components.** `backend/src/socialcircle/{api,services,db}`,
`backend/alembic/versions/`, `backend/tests/`.

**Technical constraints.**
- No denormalized counters; counts are queries (one query per profile is
  fine, N+1 across a page is not: compute counts for a page in bounded
  queries).
- Search is a case-insensitive substring match with bound parameters; limit
  is clamped 1–50; `q` longer than 50 chars is a 422.
- Only the owner can edit a profile (there is no endpoint for others);
  `PATCH` with an empty body is a 422.
- Duplicate follow and self-follow are rejected by constraints and reported
  as 409 `already_following` and 400 `self_follow`; unfollowing a user you
  do not follow is 404 `not_found`.
- Keep router/service separation; typed domain errors mapped by handlers.

**Required tests (backend, real PostgreSQL).**
- Directory: unauthenticated 401; pagination `total`/`limit`/`offset`
  semantics; ordering; search matches username and display name
  case-insensitively; clamping and 422 for bad parameters.
- Profile: own profile edit success (display name and bio independently and
  together), validation (lengths, empty body), another user's view of the
  edited profile; `PublicProfile` responses never contain `email`,
  `password_hash` or session fields (assert on the JSON keys).
- Follow: success updates counts and `viewer_follows`; duplicate → 409;
  self → 400; unknown user → 404; unfollow success and unfollow-not-following
  → 404; counts and `GET /me/following` stay consistent after a sequence of
  follow/unfollow operations; CSRF required on all three mutating endpoints.
- Integrity: inserting a duplicate or self follow directly through
  SQLAlchemy raises `IntegrityError` (constraints exist in the database, not
  only in code); deleting a user cascades its follows and sessions.

**Acceptance criteria.** All required tests pass; `make check` and `make
e2e` smoke pass; migrations up/down/check verified; handoff lists commands
and results; the API matches `API.md`.

**Non-goals.** Frontend work, blocking/muting, follower lists of other users
beyond counts, recommendations, activity feeds.

**Dependencies.** Stage 2 accepted (users, sessions, auth dependencies, CSRF).

**Human verification.** None required.

## Stage 4 — Angular Authentication and Profile UI

**Goal.** A person can register, sign in, see and edit their own profile and
sign out in the browser, with correct session handling, validation, loading
and error states, protected routes, accessibility and responsive layout.

**Scope.**
- Typed API client services (`AuthApi`, `UsersApi`) using relative
  `/api/v1` URLs, mapping the error envelope in `API.md` to a typed
  `ApiError`; HttpClient configured with XSRF cookie/header names
  `XSRF-TOKEN` / `X-XSRF-TOKEN`.
- `SessionService` (signal of `PrivateUser | null`) initialized once from
  `GET /auth/me` before routing; `authGuard` (redirect to `/login` with
  `returnUrl`) and `anonymousGuard`; an interceptor that resets the session
  and redirects on 401.
- Pages: `/register`, `/login`, `/me` (own profile: display name, username,
  bio, counts, member since), `/me/edit` (display name and bio with the
  validation rules in `API.md`), sign-out control in the shell; `/`
  redirects to `/me` when signed in and `/login` otherwise (Stage 5 changes
  the signed-in target to `/members`).
- Reactive typed forms with inline validation messages, server-side field
  errors shown next to the control, a general error banner for request
  failures, disabled submit and visible progress while a request is in
  flight, success feedback after saving.
- Accessibility: labelled inputs, error messages associated via
  `aria-describedby`, focus moved to the first error or to the page heading
  after navigation, keyboard operable, visible focus styles, colour contrast
  ≥ 4.5:1 for text.
- Responsive SCSS: usable at 360 px and 1280 px widths without horizontal
  scrolling.

**Expected deliverables.** The components, services, guards, interceptor,
routes, styles, Angular unit/component tests, Playwright scenarios, README
section on the UI, `.sparring/PROJECT.md` Baseline update.

**Relevant components.** `frontend/src/app/**`, `frontend/e2e/`.

**Technical constraints.** Standalone components, `inject()`, signals for
state, OnPush where practical, no third-party UI or state libraries,
strict TypeScript, eslint clean. Do not change backend behaviour; if the
contract is insufficient, report it in the handoff instead of working around
it.

**Required tests.**
- Angular component/unit tests: register and login form validation
  (required, lengths, username pattern), server field errors rendered,
  guards redirect correctly, `SessionService` initializes from `/auth/me`
  and clears on 401, profile editor pre-fills and submits only changed
  fields or both fields as the contract allows.
- Playwright (against the running stack, synthetic unique accounts per run):
  register a new member and land on `/me`; sign out and sign in again; a
  wrong password shows the server error; `/me/edit` saves a display name
  and bio and `/me` shows them; visiting `/me` signed out redirects to
  `/login`; the shell has no horizontal scroll at 360 px.

**Acceptance criteria.** `make check` passes (including the new Angular
tests); `make e2e` passes; the flows above work in Chromium; forms are
keyboard operable with visible focus; handoff lists commands and results.

**Non-goals.** Member directory, other members' profiles, follow controls,
avatars, password reset, theming beyond a clean default.

**Dependencies.** Stage 3 accepted (so `PublicProfile` counts are real and
the backend contract is complete); Stage 1's Angular skeleton and proxy.

**Human verification.** A visual check of the register, login, profile and
editor pages at desktop and mobile widths (layout, contrast, focus
visibility) is the kind of check only a person can judge. The reviewer
decides whether it must happen before acceptance or may be deferred to plan
completion; pass criteria: no overlapping or clipped content at 360 px and
1280 px, visible focus ring on every control, error text readable.

## Stage 5 — Member Directory and Social UI

**Goal.** Members can discover other members, open their profiles, follow and
unfollow them, and see consistent counts and lists, with empty states and
responsive layout.

**Scope.**
- `/members`: searchable, paginated directory (`GET /api/v1/users`) with a
  debounced search box, result count, previous/next paging, loading
  skeleton or indicator, an empty state for no matches and for a directory
  with only yourself, and a visible marker on your own entry.
- `/members/:id`: public profile detail (`GET /api/v1/users/{id}`) with
  display name, username, bio, follower and following counts, and a
  follow/unfollow control that is disabled while a request is in flight,
  reflects the server response (`viewer_follows`, counts) and shows errors
  from the envelope; no control on your own profile; 404 state for unknown
  ids.
- `/me` gains a "Following" list (`GET /api/v1/me/following`) with
  pagination and an empty state; `/` now redirects signed-in members to
  `/members`.
- Shell navigation links to Members and Profile with the current route
  indicated (`aria-current`).

**Expected deliverables.** Components, services, routes, styles, Angular
tests, Playwright scenarios, README update, `.sparring/PROJECT.md`
Baseline update.

**Relevant components.** `frontend/src/app/**`, `frontend/e2e/`.

**Technical constraints.** Same as Stage 4 (standalone, signals, strict TS,
no extra libraries, accessibility, responsive at 360 px and 1280 px). Counts
and follow state come from server responses, never from local arithmetic.
Do not change backend behaviour; report contract gaps in the handoff.

**Required tests.**
- Angular tests: directory renders items, empty states and paging; search
  debounces and sends `q`; detail page shows the follow control only for
  other members and toggles based on the response; errors are shown.
- Playwright (synthetic accounts created in the test): with Alice and Bob
  registered, Alice finds Bob by searching, opens his profile, follows
  (count and button change), sees Bob in her Following list, unfollows
  (count and button revert), and Bob's profile shows the correct follower
  count after Alice's actions; the directory shows an empty state for a
  search with no matches; the pages fit at 360 px.

**Acceptance criteria.** `make check` and `make e2e` pass; the flows above
work in Chromium; counts and lists are consistent with the backend; handoff
lists commands and results.

**Non-goals.** Follower lists of other users, recommendations, feeds,
blocking, infinite scroll.

**Dependencies.** Stage 4 accepted (session handling, shell, API clients).

**Human verification.** As in Stage 4, a visual check of the directory and
member detail pages at desktop and mobile widths may be requested; the
reviewer decides immediate versus deferred. Pass criteria: no clipped or
overlapping content, follow control state obvious, empty states readable.

## Stage 6 — End-to-End Verification and Demo Readiness

**Goal.** The whole system is verified end to end from an empty database,
reproducibly, and a developer can clone, start, reset, seed, test and
demonstrate the application from the documentation alone. No new product
scope.

**Scope.**
- Playwright journey test in `frontend/e2e/` that, from a reset database,
  registers Alice, registers Bob, signs in as Alice, completes Alice's
  profile, finds Bob in the directory, views Bob's profile, follows Bob,
  verifies the relationship (counts, Alice's Following list, Bob's follower
  count seen from Bob's session), unfollows Bob, signs out, and verifies that
  protected pages redirect and protected API calls return 401 (and that a
  state-changing call without the CSRF header returns 403).
- Synthetic demonstration data: a backend command (for example
  `uv run python -m socialcircle.seed`) that creates a small deterministic
  set of members with profiles and follow relationships, idempotent, with
  documented demo credentials that are clearly synthetic; `make seed` and
  `make reset-db` targets (reset drops and recreates the schema via Alembic
  and is refused unless `APP_ENV=development`).
- `docs/demo/demo-walkthrough.md`: a concise scripted demonstration (start,
  reset, seed, the journey above in the browser, where to look in the API)
  with expected observations.
- Documentation review: `README.md`, `docs/architecture/ARCHITECTURE.md` and
  `docs/architecture/API.md` match the implementation (fix drift in the docs,
  or report code drift as a finding); the "Before public deployment" list is
  complete and accurate.
- Security review pass against the invariants in `AGENTS.md`: cookies flags,
  CSRF coverage of every state-changing route, no private fields in public
  responses, constraints present in the migrations, no secrets in Git; add
  tests for anything found unprotected rather than only fixing silently.
- CI: make sure the workflow runs lint, typecheck, unit/integration tests
  and the E2E journey on a fresh checkout; record in the handoff whether a
  real CI run could be observed (it requires the remote) or is still owed.

**Expected deliverables.** Journey test, seed command and `make` targets,
`docs/demo/demo-walkthrough.md`, documentation fixes, security-review notes
in the handoff, `.sparring/PROJECT.md` Baseline update with the final
results.

**Relevant components.** `frontend/e2e/`, `backend/src/socialcircle/`,
`Makefile`, `docs/`, `README.md`, `.github/workflows/`.

**Technical constraints.** No feature additions. Tests use synthetic
accounts and isolated state; the journey must be rerunnable (`make
reset-db` then `make e2e`). Do not edit `docs/plans/` or
`docs/demo/sparring-showcase.md` (the latter is written by a person from the
engine's run artifacts after this run).

**Required tests.** The journey test above, the seed command's idempotency
test, and any new security tests; the full `make check` and `make e2e`.

**Acceptance criteria.** From a fresh clone with the documented commands:
`make setup`, `make up`, `make migrate`, `make seed`, `make check`, `make
reset-db`, `make e2e` all succeed; the demo walkthrough can be followed
verbatim; documentation matches the code; the handoff states exactly which
checks ran and which (such as the hosted CI run) are still owed.

**Non-goals.** Deployment, performance tuning, new features, changes to the
plan or showcase documents.

**Dependencies.** Stage 5 accepted (all product features complete).

**Human verification.** A person following `docs/demo/demo-walkthrough.md`
once in a browser and confirming each expected observation is a genuine
manual check; the reviewer may record it as a deferred check to be satisfied
before plan completion. Pass criteria: every step of the walkthrough produces
the documented observation.
