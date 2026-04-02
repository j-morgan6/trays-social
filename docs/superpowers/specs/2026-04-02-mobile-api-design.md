# Mobile API Design — REST JSON API for iOS App

## Overview

A REST JSON API layer (`/api/v1/`) added to the existing Phoenix app to power a React Native iOS app for the Apple App Store. The API exposes core functionality — auth, feed, posts, profiles, follows, likes, and push notifications — as JSON endpoints alongside the existing LiveView web app.

## Decisions

- **iOS only** for initial App Store release, Android planned for later
- **React Native** for the mobile app (separate project, not covered by this spec)
- **REST JSON API** — simple, well-understood, maps cleanly to existing contexts
- **Core-first scope** — auth, feed, posts, profiles, likes, push notifications. Comments, explore/trending, settings come in a fast-follow phase.
- **Apple Developer Account** ($99/year) required for App Store submission, APNs, and Sign in with Apple

## Authentication

### Token Strategy

Bearer tokens stored in the existing `user_tokens` table with a new `"api"` context. The mobile app sends `Authorization: Bearer <token>` on every request. Tokens persist until the user logs out (no automatic expiry — standard for mobile apps to avoid constant re-authentication).

New functions added to `UserToken`: `build_api_token/1` and `verify_api_token_query/1`, following the existing `build_session_token/1` and `verify_session_token_query/1` patterns.

**Token revocation:**
- All API tokens are revoked when the user changes their password (existing `update_user_and_delete_all_tokens/1` handles this)
- All tokens are revoked on account deletion (existing `delete_account/1` handles this)
- Individual token revoked on logout via `DELETE /api/v1/auth/logout`

### Rate Limiting

Auth endpoints (`/register`, `/login`, `/apple`) are rate-limited to prevent brute force and credential stuffing attacks. Use the `hammer` library with a Plug-based rate limiter in the API pipeline.

- Login: 10 attempts per IP per minute
- Register: 5 attempts per IP per minute
- Apple auth: 10 attempts per IP per minute

Failed attempts return `429 Too Many Requests` with a `Retry-After` header.

### Email/Password

- `POST /api/v1/auth/register` — create account with email, username, password. Returns API token.
- `POST /api/v1/auth/login` — authenticate with email and password. Returns API token.
- `DELETE /api/v1/auth/logout` — revoke the current API token.

### Sign in with Apple

- `POST /api/v1/auth/apple` — receive Apple identity token (JWT) from the React Native app, verify server-side against Apple's public keys, create or find user, return API token.

**Flow:**
1. User taps "Sign in with Apple" in the React Native app
2. Apple SDK returns an identity token (JWT) and optionally name/email
3. React Native sends token to `POST /api/v1/auth/apple`
4. Phoenix verifies JWT against Apple's public keys using the `assent` library
5. Existing user with matching `apple_id` — log in, return API token
6. New user — create account, return API token with `"needs_username": true` flag

**Database changes:**
- Add `apple_id` (string, unique, nullable) to `users` table
- `hashed_password` is already nullable in the existing schema — no migration needed

**Changeset changes:**
- Add `apple_registration_changeset/2` to `User` that validates email and username but skips password validation (existing `registration_changeset/3` requires a password via `validate_required([:password])`)

**Edge cases:**
- Apple only sends user email/name on the first sign-in — capture and store immediately
- Apple private relay emails (`abc123@privaterelay.appleid.com`) are stored as-is
- Linking email/password account to Apple account is a future enhancement, not in v1

### Current User

- `GET /api/v1/auth/me` — returns current user profile. Used on app launch to check auth state and detect if username setup is needed (Apple Sign In users).
- `PUT /api/v1/auth/me` — update own profile (username, bio, profile photo).
- `DELETE /api/v1/auth/me` — delete account and all associated data. Required by Apple for App Store approval. Note: the existing `delete_account/1` only soft-deletes posts and removes tokens — implementation must also delete/anonymize the user record itself to meet Apple's data deletion requirement.

## API Structure & Conventions

### Base Path

All endpoints under `/api/v1/`. The version prefix allows breaking changes in future via `/api/v2/` without breaking existing app versions already installed on users' phones.

### Router Pipelines

```elixir
pipeline :api do
  plug :accepts, ["json"]
end

pipeline :api_auth do
  plug TraysSocialWeb.API.AuthPlug
end
```

Unauthenticated routes (register, login, apple) go through `:api` only. All other routes go through both `:api` and `:api_auth`.

### Response Format

Consistent JSON structure across all endpoints:

```json
// Success (single resource)
{"data": { ... }}

// Success (list)
{"data": [ ... ], "cursor": "abc123"}

// Error
{"errors": [{"field": "email", "message": "has already been taken"}]}
```

### Pagination

Cursor-based, matching the existing `list_posts` implementation. Responses include a `cursor` value the client passes as a query parameter to fetch the next page. Cursor-based pagination is more reliable than page numbers for feeds where new content is continuously added.

### Error Handling

A `FallbackController` handles all error responses consistently. Changeset errors are translated into the `{"errors": [...]}` format. Standard HTTP errors (401, 403, 404, 429) also use this format.

### Controller Namespace

All API controllers live under `TraysSocialWeb.API.V1` to keep them separate from existing web controllers. Example: `TraysSocialWeb.API.V1.PostController`.

## Endpoints

### Feed & Posts

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/v1/feed` | Yes | Personalized feed (followed users' posts, falls back to all posts). Supports `?cursor=` |
| `GET` | `/api/v1/posts/:id` | Yes | Single post with ingredients, steps, tools, tags, photos |
| `POST` | `/api/v1/posts` | Yes | Create a post (see Photo Upload Strategy below) |
| `DELETE` | `/api/v1/posts/:id` | Yes | Soft-delete own post |

### Profiles

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/v1/users/:username` | Yes | Public profile (bio, photo, post count, follower/following counts) |
| `GET` | `/api/v1/users/:username/posts` | Yes | User's posts, cursor-paginated |
| `POST` | `/api/v1/users/:username/follow` | Yes | Follow a user |
| `DELETE` | `/api/v1/users/:username/follow` | Yes | Unfollow a user |

### Likes

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/v1/posts/:id/like` | Yes | Like a post |
| `DELETE` | `/api/v1/posts/:id/like` | Yes | Unlike a post |

### Push Notifications (Device Registration)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/v1/devices` | Yes | Register APNs device token |
| `DELETE` | `/api/v1/devices/:token` | Yes | Unregister device token (on logout) |

### Uploads

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/v1/uploads` | Yes | Upload a single photo, returns URL (see Photo Upload Strategy below) |

**Total: 19 endpoints** (6 auth + 4 feed/posts + 4 profiles + 2 likes + 2 devices + 1 uploads)

### Response Shapes

**Post (feed item / detail):**
```json
{
  "id": 1,
  "type": "recipe",
  "caption": "Best pasta ever",
  "cooking_time_minutes": 30,
  "servings": 4,
  "like_count": 12,
  "comment_count": 3,
  "liked_by_current_user": true,
  "inserted_at": "2026-04-01T12:00:00Z",
  "user": {
    "id": 1,
    "username": "jose",
    "profile_photo_url": "https://..."
  },
  "photos": [
    {"url": "https://...", "thumb_url": "https://...", "medium_url": "https://...", "position": 0}
  ],
  "ingredients": [{"name": "Pasta", "quantity": "500g"}],
  "cooking_steps": [{"position": 1, "instruction": "Boil water"}],
  "tools": [{"name": "Large pot"}],
  "tags": ["italian", "pasta"]
}
```

**User profile:**
```json
{
  "id": 1,
  "username": "jose",
  "bio": "Food lover",
  "profile_photo_url": "https://...",
  "post_count": 15,
  "follower_count": 120,
  "following_count": 45,
  "followed_by_current_user": true
}
```

**Feed cursor:** Encodes `cursor_id` and `cursor_time` as a Base64-encoded string (e.g., `Base.url_encode64("#{id}:#{inserted_at}")`). Opaque to the client — they just pass it back as `?cursor=`.

### Photo Upload Strategy

Post creation uses a **two-step approach** to avoid the complexity of multipart requests with deeply nested JSON:

1. `POST /api/v1/uploads` — upload a single photo, returns the URL. Can be called multiple times for multiple photos.
2. `POST /api/v1/posts` — create the post with JSON body, referencing the uploaded photo URLs.

This keeps the post creation endpoint as a clean JSON request and avoids multipart encoding of nested fields (ingredients, steps, tags). The uploads endpoint handles multipart.

The uploads endpoint is included in the endpoint tables above.

### Context Function Changes

- `Posts.list_posts_by_user/1` needs to be extended to support cursor-based pagination options (currently returns all posts for a user without pagination)

## Image Uploads & Cloud Storage

### Problem

Current local file storage (`priv/static/uploads`) doesn't work for production:
- Fly.io containers can restart/redeploy, wiping local files
- Mobile apps need absolute URLs to display images
- Multiple server instances can't share local filesystem

### Solution

Switch to Amazon S3 (or S3-compatible service like Tigris, which Fly.io offers natively).

### Upload Flow (Mobile)

1. Mobile app uploads photo(s) via `POST /api/v1/uploads` (multipart)
2. Phoenix receives file, validates (size ≤ 10MB, allowed extensions: jpg, jpeg, png, heic)
3. Generates size variants using existing `ImageProcessor` (thumb 300x300, medium 800px, large 1200px)
4. Uploads all variants to S3
5. Returns the S3 URL to the client
6. Client includes photo URLs when creating the post via `POST /api/v1/posts`

### Implementation

- `Uploads.Photo` module gets an S3 adapter alongside existing local adapter
- Config switches between local (dev) and S3 (prod) via application config
- Photo URLs in API responses are full URLs (`https://bucket.s3.amazonaws.com/...`) instead of relative paths
- The existing web app also benefits from this change — fixes the same local storage problem on Fly.io

## Push Notifications

### Architecture

1. React Native app requests push permission from iOS on launch, receives APNs device token
2. App sends token to `POST /api/v1/devices` — stored in new `device_tokens` table
3. When a notification-worthy event occurs (like, follow), the existing `Notifications` context creates the in-app notification and additionally sends a push via APNs
4. On logout, app calls `DELETE /api/v1/devices/:token` to stop receiving pushes

### Database Table

```
device_tokens
  - id (bigint, primary key)
  - user_id (references users, not null)
  - token (string, not null, unique)
  - platform (string, not null, default "ios") — ready for Android later
  - inserted_at (utc_datetime)
  - updated_at (utc_datetime)
```

### Server-Side

- `Pigeon` library for sending pushes to APNs
- Requires APNs key (`.p8` file) from Apple Developer account
- Pushes sent asynchronously (e.g., via `Task.Supervisor`) so they don't slow down API responses
- Invalid device tokens (APNs returns error) are automatically removed from `device_tokens` table

### Triggers (v1)

- Someone likes your post
- Someone follows you

Comments and other notification types come in the fast-follow phase.

## New Dependencies

| Library | Purpose |
|---------|---------|
| `assent` | Apple Sign In JWT verification |
| `pigeon` | APNs push notification delivery |
| `ex_aws` + `ex_aws_s3` | S3 cloud storage for image uploads |
| `hammer` | Rate limiting for auth endpoints |

## Database Changes

### New table: `device_tokens`
- `id`, `user_id`, `token`, `platform`, `inserted_at`, `updated_at`

### Modified table: `users`
- Add `apple_id` (string, unique, nullable)
- Note: `hashed_password` is already nullable — no migration needed for this

## Out of Scope (Fast-Follow)

- Comments API endpoints
- Explore/trending endpoints
- Settings/password change API endpoints
- Email/Apple account linking
- Android push notifications (FCM)
- The React Native app itself (separate project)
