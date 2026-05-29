# App Store Connect — App Store listing metadata

This is the source of truth for the text the operator pastes into App Store
Connect's **App Information** and **App Store** (version) fields. Keep wording
changes here so they have history and the operator never has to re-discover
"wait, what was the keyword list again?"

Character counts below are the live values for the text as written; recount
after any edit. Apple's limit is shown next to each field.

**Resubmission rules (read before editing):**

| Field | Update freely? | Notes |
|---|---|---|
| App name | No | Changing requires a new build/version submission. |
| Subtitle | No | Tied to a version — changes ship with a new build. |
| Promotional text | **Yes** | Can be changed any time without resubmitting a build. Use it for timely messaging. |
| Description | No | Changes ship with a new version submission. |
| Keywords | No | Tied to a version — changes ship with a new build. |
| What's New | No | Per-version; written fresh for each release. |
| Support URL | **Yes** | Editable without resubmission. |
| Marketing URL | **Yes** | Editable without resubmission. |
| Categories | No | Set in App Information; effectively a version change. |

---

## App Information (set once, app-level)

### App name — limit 30
```
Trays
```
(5 / 30)

### Subtitle — limit 30
```
Recipes from cooks you follow
```
(29 / 30)

### Primary category
```
Food & Drink
```

### Secondary category
```
Social Networking
```

### Copyright
```
2026 1001366752 Ontario Inc.
```

### Support URL
```
https://trays.app/faq
```

### Marketing URL
```
https://trays.app/
```

---

## App Store (version 1.0 fields)

### Promotional text — limit 170 (updatable without resubmission)
```
Trays is where home cooks share what they actually make. Follow the people whose food you love, save recipes to your tray, and cook more. No ads, no algorithm.
```
(159 / 170)

### Description — limit 4000

The first three lines are what the App Store shows above the fold, so they
carry the value prop on their own. No emojis (project rule + Apple rejects
inconsistently); avoid "iOS app for…" phrasing (Apple's automated check flags
redundant platform phrasing).

```
Cook more. Scroll less.

Trays is a recipe-sharing community for home cooks. Follow the people whose food you love, see what they are actually making, and save what you want to cook next.

This is a feed without the noise. Posts appear in the order they were made — no ads, no algorithm deciding what you see, no endless suggestions. Just the cooks you chose to follow and the recipes they share.

Post a recipe in a few taps: a photo, the ingredients, the steps, and the tools you used. Your followers see it in their feed, and you see theirs in yours.

Found something you want to make? Save it to your tray — your own running cookbook of recipes to come back to. Like the dishes that inspire you, leave a comment, and follow new cooks as you find them.

Three simple spaces:
- Feed — what the cooks you follow are making, newest first.
- Find — search by ingredient, time, or cuisine to discover something to cook.
- My Tray — every recipe you have saved, in one place.

Sign in with email or with your Apple ID. There are no payments, no in-app purchases, and no cross-app tracking — your kitchen, your recipes, your community.

Start following the cooks whose food you love, and cook more this week.
```
(1204 / 4000)

### Keywords — limit 100 (comma-separated, NO spaces around commas)

No spaces around commas (Apple counts them against the 100). No trademarked
terms (Instagram, TikTok, Pinterest — Apple rejects). Singular stems only — do
not spend characters on both a word and its plural.

```
recipe,cooking,cook,home,meal,food,share,cookbook,follow,community,kitchen,dinner,ingredient,baking
```
(99 / 100)

### What's New in This Version — limit 4000 (version 1.0)
```
Welcome to Trays — our first release.

Trays is a recipe-sharing community for home cooks: follow the cooks whose food you love, share what you are making, save recipes to your tray, and skip the ads and the algorithm.

This is version 1.0, so we are just getting started. If something feels off or you have an idea, tell us at support@trays.app — we read every message.
```
(370 / 4000)

---

## When this changes

- Wording change to any field → edit it here first, recount characters, then
  paste into App Store Connect.
- Promotional text, Support URL, and Marketing URL can be updated in ASC
  without resubmitting a build — but still back-port the change here.
- A new app version → write a fresh **What's New** block above (keep prior
  versions in git history) and recount the description/keywords if they changed.
- Categories or app name change → coordinate with a build submission; they are
  not free-text edits.
