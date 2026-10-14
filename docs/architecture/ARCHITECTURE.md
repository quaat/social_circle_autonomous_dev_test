# SocialCircle architecture

A deliberately small system: one Angular single-page app, one FastAPI
service, one PostgreSQL database. Everything below is written as checkable
statements; where a statement is not yet true of the code, the staged plan
says which stage makes it true.

## 1. System context

```text
 Browser ──(same origin, cookies)──▶ Angular dev server :4200
                                         │  /api/* proxied
                                         ▼
                                  FastAPI :8010 ──▶ PostgreSQL :5440 (host port)
```

- Users interact only with the Angular app. The app calls `/api/v1/*` with
  relative URLs; in development `frontend/proxy.conf.json` forwards `/api` to
  the backend, so session cookies are first-party and `SameSite=Lax` works.
- There are no other external systems: no email, no identity providers, no
  object storage.
- Everything runs locally through `docker compose` (`compose.yaml`) or
  directly on the host with `uv` and `npm`. Default ports (overridable in
  `.env`): frontend 4200, backend 8010, Postgres 5440 — chosen to avoid the
  common 8000/5432/5433 collisions.

## 2. Component responsibilities

| Component | Responsibility | Must not |
| --- | --- | --- |
| `frontend/` (Angular 22, standalone components, Router, HttpClient, signals, typed reactive forms, SCSS) | Pages, forms, validation feedback, loading/empty/error states, session-aware navigation and route guards, follow controls | Hold secrets, implement authorization, duplicate server validation as the only validation |
| `backend/src/socialcircle/api/` (FastAPI routers) | Parse and validate requests, resolve the current user, call services, map results and errors to the contract in `API.md` | Contain business rules or SQL |
| `backend/src/socialcircle/services/` | Business logic: registration, authentication, sessions, profiles, search, follows. Pure functions over a `Session` and typed inputs; raise typed domain errors | Know about HTTP, cookies or Pydantic response models |
| `backend/src/socialcircle/db/` (SQLAlchemy 2.x models, session factory) | Persistence models, constraints, `get_db` dependency | Be returned from endpoints |
| `backend/alembic/` | Versioned schema migrations, one per change | Be auto-applied at app start |
| `backend/src/socialcircle/core/` | Settings (pydantic-settings from env), security primitives (Argon2id, token generation and hashing), error types and handlers | Read `.env` from inside containers (env vars only) |
| `compose.yaml` | `db` (postgres:17), `backend` (uvicorn, reload), `frontend` (ng serve with proxy); health checks for db and backend | Bake secrets into images |

The FastAPI app is built by `create_app(settings) -> FastAPI` so tests can
construct it with overridden settings and database dependencies.

## 3. Database entities

```text
users                        sessions                     follows
─────────────────────        ─────────────────────        ───────────────────────
id            uuid PK        id            uuid PK        follower_id uuid FK→users
email         text UQ        token_hash    text UQ        followed_id uuid FK→users
username      text UQ        user_id       uuid FK→users  created_at  timestamptz
display_name  text           created_at    timestamptz    PK (follower_id, followed_id)
password_hash text           expires_at    timestamptz    CHECK follower_id <> followed_id
bio           text           revoked_at    timestamptz NULL
created_at    timestamptz
updated_at    timestamptz
```

Invariants enforced **in the database** (and tested):

- `users.email` and `users.username` are unique; both are stored lower-cased
  so uniqueness is case-insensitive by construction.
- `sessions.token_hash` is unique; the raw token is never stored.
- `follows` has a composite primary key (no duplicate follows) and a check
  constraint (no self-follow). Both foreign keys cascade on user deletion.
- `sessions.user_id` cascades on user deletion.

Indexes: `sessions(user_id)`, `follows(followed_id)` (follower counts),
`users(username)` and `users(display_name)` support the directory search.

## 4. Authentication and session architecture

1. **Registration** validates input, lower-cases email and username, hashes
   the password with Argon2id (`argon2-cffi`, library defaults), inserts the
   user inside a transaction and relies on the unique constraints as the final
   arbiter (an `IntegrityError` becomes `409`).
2. **Login** looks up by email or username, verifies with Argon2 (constant
   response for unknown users and wrong passwords), then creates a session:
   32 random bytes (`secrets.token_urlsafe`), stored as `sha256(token)`, with
   `expires_at = now + SESSION_TTL_HOURS`. The raw token goes into cookie
   `socialcircle_session` (`HttpOnly`, `SameSite=Lax`, `Path=/`, `Secure` per
   settings). A CSRF token (`secrets.token_urlsafe(32)`) goes into cookie
   `XSRF-TOKEN` (readable by JS, `SameSite=Lax`).
3. **Request authentication** (`get_current_user` dependency) hashes the
   cookie value, loads the session, and rejects it if missing, expired or
   revoked. There is no sliding expiry in the MVP.
4. **CSRF** (`require_csrf` dependency on every cookie-authenticated `POST`,
   `PATCH`, `DELETE`): header `X-XSRF-TOKEN` must equal cookie `XSRF-TOKEN`
   (constant-time compare), otherwise `403` before any handler runs. Combined
   with `SameSite=Lax` this blocks cross-site state changes.
5. **Logout** sets `revoked_at` and clears both cookies.
6. Password hashes and session tokens never appear in logs or responses.

## 5. API conventions

See `API.md` for the full contract. In short: `/api/v1`, JSON, uniform error
envelope `{"error": {"code", "message", "details?"}}`, `limit`/`offset`
pagination, UUID ids, ISO 8601 timestamps, separate `PublicProfile` and
`PrivateUser` response schemas.

## 6. Frontend data flow

- `ApiService`-style typed HTTP services per resource (`AuthApi`, `UsersApi`),
  all relative URLs, errors mapped from the envelope to an `ApiError` type.
- `SessionService` holds the current `PrivateUser | null` as a signal,
  bootstrapped once by `GET /auth/me` on app start (an `APP_INITIALIZER`-style
  provider or a resolver); `authGuard` redirects anonymous users to `/login`
  with a `returnUrl`, and `anonymousGuard` keeps signed-in users off
  `/login` and `/register`.
- Pages: `/register`, `/login`, `/me` (own profile), `/me/edit`, `/members`
  (directory with search and pagination), `/members/:id` (detail with follow
  control). `/` redirects to `/members` when signed in, else `/login`.
- Every page renders explicit loading, empty, validation-error, request-error
  and success states; follow/unfollow updates counts from the server response
  rather than guessing.

## 7. Error handling

- Services raise typed exceptions (`EmailTaken`, `UsernameTaken`,
  `InvalidCredentials`, `NotFound`, `AlreadyFollowing`, `SelfFollow`, …).
- One FastAPI exception-handler layer maps them, plus `RequestValidationError`
  and unhandled exceptions, to the envelope in `API.md`. Unhandled exceptions
  are logged server-side with a correlation id and returned as `500
  internal_error` without internals.
- The frontend never shows raw HTTP errors: an interceptor turns `401` into a
  session reset and redirect to `/login`, and components show the server's
  `message` or field `details` next to the relevant form control.

## 8. Security assumptions and limits

Assumed: a single trusted deployment behind one origin, synthetic accounts,
no untrusted admin. Provided: Argon2id, server-side sessions, HttpOnly +
SameSite cookies, CSRF double-submit check, server-side authorization, DB
constraints, bound-parameter queries, explicit validation.

**Before public deployment** the following would additionally be required
and are out of scope here: HTTPS with `Secure` cookies and HSTS, rate limiting
on login and registration, account lockout or CAPTCHA, email verification and
password reset, audit logging, a content-security policy and other hardening
headers, dependency and container vulnerability scanning, secret management
(no `.env` files), backups, and a privacy review of stored personal data.

## 9. Testing strategy

| Layer | Tool | What it proves |
| --- | --- | --- |
| Backend unit | pytest | password hashing, token hashing, schema validation, service rules with an in-memory fake only where no DB behavior matters |
| Backend integration | pytest + real PostgreSQL (`TEST_DATABASE_URL`), migrations applied, per-test transaction rollback or truncation | constraints (uniqueness, self-follow), auth flows, CSRF, authorization, error envelope, pagination |
| Frontend unit/component | Angular test runner (headless Chromium) | form validation, guards, services, state rendering |
| End-to-end | Playwright against the running compose stack | the documented journey from an empty database: register Alice and Bob, sign in, edit profile, find and follow Bob, unfollow, sign out, verify protected operations fail |
| Static | ruff, mypy (strict for `src/`), eslint, tsc strict | code quality and type safety |

`make check` (lint + typecheck + unit/integration tests) must pass on every
accepted stage; `make e2e` must pass from Stage 1 (smoke) onward and cover
the full journey by Stage 6. CI runs both on a fresh checkout with a Postgres
service.

## 10. Deliberate non-goals

Messaging, feeds, recommendations, image upload, notifications, OAuth, email,
admin dashboards, follower graphs beyond direct follow/unfollow, horizontal
scaling, caching layers, and any production deployment tooling.
