# Demo seed (W111)

How to prepare the three demo accounts an Apple App Reviewer uses to
evaluate Trays Social. The seed is idempotent — re-running does not
create duplicates.

---

## What it creates

Three users:

| Username      | Email                   |
| ------------- | ----------------------- |
| `demo_alice`  | demo_alice@trays.app    |
| `demo_ben`    | demo_ben@trays.app      |
| `demo_chloe`  | demo_chloe@trays.app    |

Each cook gets 5 realistic recipe posts (ingredients, steps, tools,
tags, photo). All three mutually follow each other. The script then
seeds 12 cross-likes and 6 cross-comments so the feed has visible
engagement when a reviewer logs in.

All three accounts share the **same password** — whatever you set
`DEMO_USER_PASSWORD` to in step 1 below. Reviewers log in as
`demo_alice` (or any of the three) with that password.

---

## One-time setup

1. **Set a strong demo password** on the prod app's secrets:

   ```bash
   fly secrets set DEMO_USER_PASSWORD='<a strong 12+ char password>' --app trays-social
   ```

   The seed task refuses to run if `DEMO_USER_PASSWORD` is missing or
   shorter than 12 characters.

   Set the same secret on `trays-social-review` if you want the demo
   accounts available in the review env too.

2. **Paste this password into `docs/app-review-notes.md`** (the
   "Demo credentials" section, W112) before the App Store submission.

---

## Run it

Against prod (review env is the same with the `--app` flipped):

```bash
fly ssh console --app trays-social --command 'bin/trays_social eval "TraysSocial.Release.seed_demo()"'
```

Expected output:

```
[seed_demo] OK — demo_alice, demo_ben, demo_chloe ready
```

If `DEMO_USER_PASSWORD` is missing the task raises with a clear message
and the env you need to set.

---

## Verify

Log into the iOS app (TestFlight or sideloaded) as `demo_alice` with the
configured password. You should see:

- Feed pre-populated with posts from `demo_ben` and `demo_chloe`
- "Recipes" section in My Tray showing the 5 recipes by `demo_alice`
- Existing follows visible on the profile (Following 2, Followers 2)
- Comments on Alice's first post from Ben and Chloe

Re-running the seed is safe — no duplicate users, posts, follows, likes,
or comments are created. If you need to wipe and re-seed (rare), do it
through the normal SQL channel; `seed_demo` deliberately never deletes
existing data.

---

## When to re-run

- **After a destructive DB restore** that drops the demo accounts
- **When changing the demo password** (run after the new secret is set
  — existing users are not updated by the seed, which is intentional;
  delete the user row first via SQL if you need a fresh password)
- **Periodically as content drift insurance** — the seed is cheap and
  re-running on every release of a new app version is a reasonable
  habit, even if it's a no-op

---

## Operator notes

- The seed uses `TraysSocial.Accounts.register_user/1` so all the
  validation paths the real registration takes are exercised.
- Posts are created via `TraysSocial.Posts.create_post/2`, then their
  child records (ingredients, cooking steps, tools, tags, photo) are
  inserted via the standard changesets.
- Likes go through `TraysSocial.Posts.like_post/2` (already idempotent
  via `on_conflict: :nothing` per `post_likes` unique index).
- Follows are checked via `Repo.get_by(Follow, ...)` first to skip
  duplicates.
- Comments are matched by `(user_id, post_id, body)` so the seed copy
  itself is the dedupe key — change a comment string in the source and
  the next run creates the new one alongside any old.
