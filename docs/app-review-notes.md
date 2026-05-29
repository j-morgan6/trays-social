# App Store Connect — App Review Information notes

This is the canonical text the operator pastes into App Store Connect
**App Review Information → Notes** at submission time. It mirrors the
structure and tone of `docs/app-store-privacy-checklist.md`. Update
this file when a major flow changes; do not edit App Store Connect
directly without back-porting the change here.

---

## What this app does

Trays is a recipe-sharing social network for home cooks. Users sign in
with email + password or Sign in with Apple, post recipes (caption,
ingredients, cooking steps, tools, photo), and follow other cooks to
see their recipes in a personalized Feed. Other interactions include
liking, commenting, bookmarking ("Your tray"), reporting posts, and
blocking users. There is no payment, no in-app purchase, no advertising,
and no cross-app tracking.

---

## Demo credentials

The three demo accounts below are seeded by
`TraysSocial.Release.seed_demo/0` (see `docs/demo-seed.md`). They share
the same password — the value of the `DEMO_USER_PASSWORD` secret on
prod. **Set this secret before submitting**:

```
fly secrets set DEMO_USER_PASSWORD='<the password you'll paste below>' --app trays-social
fly ssh console --app trays-social --command 'bin/trays_social eval "TraysSocial.Release.seed_demo()"'
```

Then paste the credentials block into App Store Connect:

```
Username: demo_alice
Password: <DEMO_USER_PASSWORD value>

Alternates (same password):
  demo_ben
  demo_chloe
```

Sign in with Apple cannot be demoed with a fixed account because Apple
issues a new `sub` claim per Apple ID. To exercise the Apple Sign In
path, the reviewer uses their own Apple ID (or a Hide My Email alias).
The flow is documented in scenario 2 below.

---

## Test scenarios

Numbered for the reviewer's convenience. Each scenario is self-contained;
the reviewer can run them in any order.

### 1. Sign in (email / password)

1. Launch the app. On the Welcome screen tap **Sign in**.
2. Enter `demo_alice` (or any demo username) and the password above.
3. Tap **Sign in**.

**Expected:** Tab bar appears. Feed populates with recipes from
demo_ben and demo_chloe (the accounts demo_alice follows).

### 2. Sign in with Apple (with Hide My Email)

1. Tap **Sign out** (gear icon on the profile → Sign out) if currently
   signed in.
2. On Welcome, tap **Sign in with Apple**.
3. Authenticate with the reviewer's Apple ID. Choose **Hide My Email**.
4. Pick a username (3–30 chars, letters/numbers/underscores) when
   prompted.

**Expected:** Account created and signed in. The user's email shown
in Settings is the Apple-relay address (`@privaterelay.appleid.com`).

### 3. Browse Feed

1. Sign in as `demo_alice` (or via Apple Sign In).
2. Pull down on the Feed to refresh.
3. Scroll the feed.

**Expected:** Recipes from cooks the user follows (plus the user's own
recipes if any) appear, newest first. Each card shows the cook's
avatar, username, recipe photo, title, and like/comment counts.

### 4. View a post (recipe detail)

1. From the Feed, tap any recipe card.

**Expected:** Detail screen renders hero photo, recipe title, byline
with cook avatar, metadata strip (cooking time, servings, ingredient
count), ingredients list, numbered method, and a comments section.

### 5. Post a new recipe

1. Tap the **+** (Create) button in the bottom pill.
2. Fill in caption, cooking time, servings, ingredients, cooking steps,
   tools, tags. Attach a photo from the library.
3. Tap **Publish**.

**Expected:** The new recipe appears at the top of the user's own
profile and in **My Tray → Recipes**. Other users who follow this
account will see it in their Feed.

### 6. Comment on a post

1. Open any recipe in the Feed.
2. Scroll to the Comments section. Type a comment and tap send.

**Expected:** Comment posts and shows the user's username and avatar
above the comment body.

### 7. Like a post

1. From the Feed or recipe detail, tap the heart icon.

**Expected:** Heart fills in. Like count increments. Tapping again
unlikes (heart hollow, count decrements). The optimistic UI flips
immediately; a network blip rolls it back with a brief toast.

### 8. Follow a user

1. Open any post by a user the current account doesn't follow (or open
   their profile via the byline).
2. Tap **Follow @username**.

**Expected:** Button flips to **Following**. The user's recipes appear
in the Feed on next refresh.

### 9. Unfollow a user

1. On the profile of a user the current account follows, tap
   **Following**.

**Expected:** Button flips back to **Follow @username**. Their recipes
stop appearing in the Feed.

### 10. Report a post

1. Open any post that is NOT authored by the current user.
2. Tap the ellipsis (•••) in the top-right toolbar of the recipe
   detail screen.
3. Tap **Report Post**, pick a reason, optionally add a note, submit.

**Expected:** Confirmation that the report was filed. The post is not
removed for other users — moderation happens server-side.

### 11. Block a user

1. Open the profile of any user that is NOT the current user.
2. Tap the ellipsis (•••), then **Block User**, confirm.

**Expected:** The blocked user disappears from the Feed and from
comments on existing posts. Open the same profile again to confirm
the user is unblockable from **Settings → Content Filters → Blocked
Users**.

### 12. Delete account

1. Open the gear icon on the profile.
2. Scroll to **Delete account** at the bottom of Settings.
3. Confirm in the alert.

**Expected:** Account deleted. The app returns to the Welcome screen.
The user's posts and profile are removed from the public feed
immediately (soft-delete on the backend; data is fully purged on the
next scheduled retention sweep).

---

## Known quirks

- **Universal Links (D35).** Tapping a `trays.app/posts/:id` link from
  Safari or Messages opens the app and navigates to the right post on
  fresh installs. On rare devices the AASA registration takes a few
  minutes to propagate after install — if the link opens Safari
  instead, force-quit and reopen the app, then tap the link again.
- **Apple Sign In with Hide My Email.** The first time a user signs in
  with Hide My Email, transactional emails (e.g. email verification)
  route through Apple's relay. The relay strips message bodies that
  look like marketing — Trays only sends plain transactional copy, so
  this has not caused delivery failures, but reviewers should expect
  a 30–60 second relay delay.
- **Demo content is shared.** All three demo accounts mutually follow
  each other and have pre-seeded likes / comments. The reviewer's own
  activity (new posts, follows, comments) adds to this baseline; it
  is not reset between review sessions.

---

## Support contact

For App Review questions or login issues:

- Email: support@trays.app
- Response time: within 24 hours on business days

For privacy or account-deletion follow-ups, the operator can also
provide direct write access to the prod admin dashboard at
`https://trays.app/admin` (operator only — not bundled with the
demo accounts).
