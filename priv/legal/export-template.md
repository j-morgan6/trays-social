# Manual data export response template

When a user requests their data under GDPR Article 20, Quebec Law 25, or
PIPEDA, respond using this template. Deliver as `export-<user_id>.json`
attached to an email reply within 30 days of the request.

## JSON shape

```json
{
  "exported_at": "2026-05-07T22:00:00Z",
  "user": {
    "id": 123,
    "email": "user@example.com",
    "username": "exampleuser",
    "bio": "...",
    "profile_photo_url": "https://trays-social-uploads.fly.storage.tigris.dev/...",
    "inserted_at": "2026-04-15T12:34:56Z",
    "confirmed_at": "2026-04-15T12:36:01Z"
  },
  "posts": [
    {
      "id": 456,
      "type": "recipe",
      "caption": "...",
      "photos": ["https://trays-social-uploads.fly.storage.tigris.dev/abc.jpg"],
      "ingredients": [{"name": "flour", "quantity": "2", "unit": "cups"}],
      "steps": ["Mix dry ingredients...", "Bake at 350F..."],
      "created_at": "2026-04-20T18:00:00Z"
    }
  ],
  "comments": [
    {
      "id": 789,
      "post_id": 1011,
      "body": "Looks delicious!",
      "created_at": "2026-04-21T09:00:00Z"
    }
  ],
  "follows": {
    "following": ["alice", "bob"],
    "followers": ["carol"]
  },
  "likes": [{"post_id": 1234, "created_at": "2026-04-22T10:00:00Z"}],
  "bookmarks": [{"post_id": 5678, "created_at": "2026-04-23T11:00:00Z"}],
  "blocked_users": [],
  "muted_keywords": []
}
```

## Email response template

```
Subject: Your Trays data export

Hi <name>,

Attached is your data export from Trays Social, requested on <request_date>.
The file is JSON formatted per GDPR Article 20 and Quebec Law 25 portability
requirements.

If you also want your account deleted, reply to this email to confirm —
deletion is final and not reversible.

If you have questions, reach me at support@trays.app.

— The Trays team
1001366752 Ontario Inc.
```

## Producing the JSON

1. Connect to prod via `fly ssh console -a trays-social`
2. Run an Elixir one-liner that gathers the user record, posts, comments, follows, likes, bookmarks, blocked users, and muted keywords for the user id, then `Jason.encode!` it
3. Write the result to `/tmp/export-<id>.json`, scp it back, attach to the reply

(A future improvement: a `mix tasks/export_user_data.exs` script that takes a user_id and writes the JSON. Out of scope for v1.)
