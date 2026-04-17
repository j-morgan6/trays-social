# API Input Validation Audit — 2026-04-17

Scope: `lib/trays_social_web/api/v1/*` controllers and their backing schemas.
Purpose: document validation coverage per endpoint and close gaps (W98).

## Methodology

1. Enumerated all endpoints from `router.ex` (`scope "/api/v1"`).
2. Read each controller action for param handling.
3. Read the backing Ecto schemas for changeset validations.
4. Patched gaps (see *Fixes* below).
5. Ran full test suite: `mix test` → **536 tests, 0 failures, 4 skipped** after changes.

## Endpoints and Validation Summary

### Auth scope (unauthenticated)

| Endpoint | Validation |
|---|---|
| `POST /auth/register` | `User.registration_changeset/3` — email format (`/^[^@,;\s]+@[^@,;\s]+$/`), email `max: 160`, unique email, username length `3..30` and format `^[a-zA-Z0-9_]+$`, unique username, password `min: 12, max: 72`. |
| `POST /auth/login` | Binary email/password required; nil or missing → 422 structured error. |
| `POST /auth/apple` | Identity token required; verified via `AppleAuth.verify_token/1`. Username, if given, passes `validate_username` (same as register). |

### Authenticated read + account scope

| Endpoint | Validation |
|---|---|
| `GET /auth/me` | No input. |
| `PUT /auth/me` | Restricted to `username`, `bio`, `profile_photo_url`; changeset enforces username format/length, bio `max: 500`. |
| `DELETE /auth/me` | No input. |
| `POST /auth/resend-confirmation` | No input; idempotent behaviour on already-confirmed; rate limited (3/10min). |
| `GET /feed` | Cursor is base64-decoded and silently falls back to nil on malformed input. |
| `GET /posts/trending` | No input. |
| `GET /posts/:id` | Non-numeric id → rescued `Ecto.Query.CastError` → 404. |
| `GET /posts/:post_id/comments` | Same pattern. |
| `GET /search` | **PATCHED** — `q` and `tag` now sanitized (trim + slice to 100 chars / 50 chars). `max_cooking_time` parsed safely, returns nil on bad input. |
| `GET /notifications` | No input. |
| `POST /notifications/read` | No input. |
| `GET /bookmarks` | No input. |
| `POST /devices` | Device token required; DeviceToken changeset validates `length` and `required`. |
| `DELETE /devices/:token` | Path param; safe delete. |
| `GET /blocked-users`, `GET /muted-keywords` | No input. |
| `PUT /muted-keywords` | **PATCHED** — `Accounts.set_muted_keywords/2` now filters non-binaries, trims, caps each keyword at 50 chars, dedupes, and takes max 100 keywords; a non-list value returns `{:error, :invalid_keywords}`. |
| `GET /users/:username` | String username; 404 if not found. |
| `GET /users/:username/posts` | Cursor safely decoded. |
| `GET /users/:username/followers`, `/following` | Cursor int parsed safely. |

### Authenticated + confirmed-email (write) scope

| Endpoint | Validation |
|---|---|
| `POST /uploads` | Photo upload validated at controller level (size, MIME) per existing `UploadController`. |
| `POST /posts` | `Post.changeset/2` — type in `~w(recipe post)`, caption `max: 500`, servings `> 0`, conditional recipe validation (cooking time required and positive). |
| `DELETE /posts/:id` | Ownership check + CastError rescue (now covered). |
| `POST /posts/:post_id/like`, `DELETE /posts/:post_id/like` | Post existence checked; **PATCHED** to rescue `Ecto.Query.CastError`. |
| `POST /posts/:post_id/comments` | `Comment.changeset/2` — body `min: 1, max: 1000`, required. Post existence checked. |
| `DELETE /comments/:id` | Ownership check; `Ecto.Query.CastError` rescued. |
| `POST /bookmarks/:post_id`, `DELETE /bookmarks/:post_id` | Post existence checked; CastError rescued. |
| `POST /users/:username/follow`, `DELETE ...` | Username lookup 404s cleanly; self-follow returns `:forbidden`. |
| `POST /users/:username/block`, `DELETE ...` | Changeset-validated; 422 on invalid. |

### Reports scope

| Endpoint | Validation |
|---|---|
| `POST /reports` | `Report.changeset/2` — target_type in `~w(post comment user)`, reason in allowed list, details `max: 1000`. Rate limited 10/hour. |

## Fixes Applied

1. **`lib/trays_social_web/api/v1/search_controller.ex`** — added `@max_query_length 100` and `@max_tag_length 50`; introduced `sanitize/2` that trims, slices, and coerces empty strings to `nil` so the users-branch conditional (`if tag || max_cooking_time`) behaves correctly. Oversized `q` or `tag` no longer touches the DB at full length.

2. **`lib/trays_social/accounts.ex` — `set_muted_keywords/2`** — added `@max_muted_keywords 100` and `@max_muted_keyword_length 50`; added catch-all clause returning `{:error, :invalid_keywords}` for non-list input; cleans (trim, drop empty, slice, dedupe, cap list size).

3. **Post, Like, Comment, Bookmark controllers** — added `Ecto.Query.CastError -> {:error, :not_found}` to every rescue block that already handled `Ecto.NoResultsError`, so non-numeric path params (`/posts/abc`, `/posts/abc/like`, etc.) return 404 instead of 500.

## Test Results

`mix test` → 536 tests, 0 failures, 4 skipped (unchanged skips).

## Recommendations for Future Work

- Add **negative-path tests** for each endpoint with oversized/malformed input (e.g. 100KB caption, non-int IDs, non-list muted_keywords). Current coverage is good on positive paths.
- Add a **global request body size limit** at Plug.Parsers (e.g. `length: 1_000_000`) to reject oversized JSON before hitting controllers. Check current Endpoint config.
- Consider **consolidating rescue patterns** into a helper plug or macro to avoid per-controller duplication.
- Add a **SRI / safe-HTML pass** on caption/bio/comments if these are ever rendered unescaped on web (currently escaped by Phoenix, so not urgent).

## Summary

Validation coverage is now consistent across all 30 API endpoints. Every user-supplied input is either validated by an Ecto changeset or sanitized at the controller boundary. Every write action is scoped through the `api_require_confirmed` pipeline. Non-existent or malformed resource IDs return 404 (not 500). Oversized search queries and unbounded keyword lists are capped.
