# SocialCircle API contract — `/api/v1`

This is the contract the backend implements and the frontend consumes. A
stage that changes it must update this file in the same candidate. Schemas
are described as JSON; the backend defines them as Pydantic v2 models that
are separate from the SQLAlchemy persistence models.

## Conventions

- Base path `/api/v1`. JSON request and response bodies, `Content-Type:
  application/json`. Timestamps are ISO 8601 UTC strings. Identifiers are
  UUIDv4 strings.
- Same-origin only. In development the Angular dev server proxies `/api` to
  the backend so cookies are first-party.
- **Authentication** is a server-side session referenced by the `HttpOnly`,
  `SameSite=Lax` cookie `socialcircle_session` (raw opaque token; the server
  stores only its SHA-256 hash). Cookie `Secure` is set when
  `SESSION_COOKIE_SECURE=true`. Sessions expire after `SESSION_TTL_HOURS`
  (default 168) and are revoked on logout.
- **CSRF**: on register and login the server also sets a non-`HttpOnly`
  cookie `XSRF-TOKEN` (random, per session). Every `POST`, `PATCH` and
  `DELETE` that relies on the session cookie must send header `X-XSRF-TOKEN`
  equal to that cookie, otherwise `403 csrf_failed`. Angular's `HttpClient`
  does this automatically for relative URLs (`withXsrfConfiguration` defaults
  to these names). `POST /auth/register` and `POST /auth/login` do not
  require the header because no session exists yet.
- **Pagination** is `limit`/`offset`: `limit` 1–50 (default 20), `offset`
  ≥ 0 (default 0). List responses are `{"items": [...], "total": <int>,
  "limit": <int>, "offset": <int>}`.
- **Errors** always use one envelope:

  ```json
  {"error": {"code": "username_taken", "message": "That username is already in use.",
             "details": [{"field": "username", "message": "..."}]}}
  ```

  `details` is present only for validation errors (`422 validation_error`,
  one entry per invalid field). Unexpected server errors return
  `500 internal_error` with no stack trace. The FastAPI default `{"detail":
  ...}` shape is never returned.

| Status | `code` | When |
| --- | --- | --- |
| 400 | `self_follow` | following or unfollowing yourself |
| 401 | `unauthenticated` | no valid, unexpired, unrevoked session |
| 401 | `invalid_credentials` | login failed (same message for unknown identifier and wrong password) |
| 403 | `csrf_failed` | missing or mismatching CSRF token on a state-changing request |
| 404 | `not_found` | unknown user id, or unfollowing someone you do not follow |
| 409 | `email_taken` / `username_taken` | registration conflicts (checked in the app and enforced by DB unique constraints) |
| 409 | `already_following` | duplicate follow |
| 422 | `validation_error` | request body or query failed validation |

## Schemas

**PublicProfile** — safe to show to any authenticated member. Never contains
email, password hash or session data.

```json
{"id": "uuid", "username": "alice", "display_name": "Alice Ahmed",
 "bio": "…", "created_at": "2026-10-14T12:00:00Z",
 "follower_count": 3, "following_count": 1,
 "viewer_follows": false, "is_self": false}
```

**PrivateUser** — the authenticated user's own account. `PublicProfile` plus
`"email"` and `"updated_at"`. `viewer_follows` is `false` and `is_self` is
`true`.

**Validation rules** (enforced by Pydantic and mirrored in the Angular forms):

| Field | Rule |
| --- | --- |
| `email` | valid address, max 254 chars, stored and compared lower-cased |
| `username` | 3–30 chars, `^[a-z0-9_]+$`, stored lower-cased, unique |
| `display_name` | 1–80 chars after trimming |
| `password` | 8–128 chars (no other composition rules; length is the control) |
| `bio` | 0–500 chars, trimmed; `null`/absent means unchanged on PATCH |

## Endpoints

### Health

| Method & path | Auth | Response |
| --- | --- | --- |
| `GET /api/v1/health` | none | `200 {"status": "ok"}` — process is up |
| `GET /api/v1/ready` | none | `200 {"status": "ok", "database": "ok"}` after `SELECT 1` succeeds; `503 {"status": "unavailable", "database": "error"}` otherwise |

### Auth

| Method & path | Auth | Request | Response |
| --- | --- | --- | --- |
| `POST /api/v1/auth/register` | none | `{"email","username","display_name","password"}` | `201 PrivateUser`; sets session + XSRF cookies. `409 email_taken` / `username_taken`, `422` |
| `POST /api/v1/auth/login` | none | `{"identifier","password"}` — identifier is email or username | `200 PrivateUser`; sets cookies. `401 invalid_credentials`, `422` |
| `POST /api/v1/auth/logout` | session + CSRF | — | `204`; revokes the session row and clears both cookies. `401` |
| `GET /api/v1/auth/me` | session | — | `200 PrivateUser`; `401 unauthenticated` |

A login always issues a **new** session and CSRF token (no session fixation).
Logout is idempotent for a valid session; an already-revoked or expired
cookie yields `401`.

### Profiles and members

| Method & path | Auth | Request | Response |
| --- | --- | --- | --- |
| `GET /api/v1/users?q=&limit=&offset=` | session | `q` optional, max 50 chars, case-insensitive substring match on `username` or `display_name`; results ordered by `username` | `200 {"items": PublicProfile[], "total", "limit", "offset"}` (includes the viewer) |
| `GET /api/v1/users/{user_id}` | session | — | `200 PublicProfile`; `404 not_found`; `422` for a malformed UUID |
| `PATCH /api/v1/me/profile` | session + CSRF | `{"display_name"?, "bio"?}` (at least one) | `200 PrivateUser`; `422` |

Only the authenticated user can change their own profile; there is no
endpoint to edit another member.

### Social connections

| Method & path | Auth | Response |
| --- | --- | --- |
| `POST /api/v1/users/{user_id}/follow` | session + CSRF | `201 PublicProfile` of the followed user with updated counts and `viewer_follows: true`; `400 self_follow`, `404 not_found`, `409 already_following` |
| `DELETE /api/v1/users/{user_id}/follow` | session + CSRF | `200 PublicProfile` with `viewer_follows: false`; `400 self_follow`, `404 not_found` (unknown user **or** not currently following) |
| `GET /api/v1/me/following?limit=&offset=` | session | `200 {"items": PublicProfile[], "total", ...}` ordered by `username` |

Follower and following counts are computed from the `follows` table (no
denormalized counters), so they are always consistent with the list
endpoints.

## Deliberately absent

No password reset, email verification, OAuth, avatars, feeds, messaging,
notifications, blocking, admin or rate limiting. See `ARCHITECTURE.md`
"Deliberate non-goals" and "Before public deployment".
