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
2026 Joser Labs Inc.
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

## App Store (version 1.1.0 fields)

Version 1.1.0 is the recipe-first redesign: the tabs are Home, My Tray and
Search, every new post is a recipe, and Search matches recipes to the
ingredients a cook already has. The 1.0 copy (which described the old
chronological home screen) is in git history.

Copy rules for this version, so the text survives the next two releases:

- Lead with finding a recipe: your tray, a friend's tray, search by what you
  have.
- No Trays Plus, prices, subscriptions or trials. Plus is hidden in 1.1.0 and
  ships in 1.2.0.
- No promises about advertising either way, so the copy does not need a
  rewrite when sponsored results ship in Search.
- No emojis.

### Promotional text — limit 170 (updatable without resubmission)
```
Find what to cook tonight. Open your tray, see what your friends are making, or search by the ingredients you already have.
```
(123 / 170)

### Description — limit 4000

The first three lines are what the App Store shows above the fold, so they
carry the value prop on their own. No emojis (project rule + Apple rejects
inconsistently); avoid "iOS app for…" phrasing (Apple's automated check flags
redundant platform phrasing).

```
Find something to cook tonight.

Trays is a recipe app for home cooks. Pick up a recipe from your own tray, borrow one from a friend's tray, or search by the ingredients you already have.

Three tabs, each a way to find a recipe:
- Home: jump back into recipes you opened recently, browse your friends' trays, and see what is new this week from the cooks you follow.
- My Tray: the recipes you have posted and the ones you have saved, in one place.
- Search: look up a dish, a cook, or the ingredients in your kitchen. Add a few ingredients and Trays shows the recipes you can make with what you have, and the ones you are only an item or two away from.

Every post on Trays is a recipe: a photo, the ingredients, the steps, and the tools you used. Share your own in a few taps, and follow new cooks as you find them.

Open any recipe for the full ingredient list and method, or switch to Cook mode to follow it one step at a time. Save the dishes you want to make, like the ones that inspire you, and leave a comment for the cook.

Sign in with email or with your Apple ID.

Start with what is in your kitchen, and cook something good this week.
```
(1146 / 4000)

### Keywords — limit 100 (comma-separated, NO spaces around commas)

No spaces around commas (Apple counts them against the 100). No trademarked
terms (Instagram, TikTok, Pinterest — Apple rejects). Singular stems only — do
not spend characters on both a word and its plural. "planner" is left out on
purpose: the meal planner is part of Plus.

```
recipe,cooking,cook,ingredient,pantry,fridge,meal,dinner,cookbook,kitchen,baking,leftover,friend
```
(96 / 100)

### What's New in This Version — limit 4000 (version 1.1.0)
```
Trays 1.1 is rebuilt around one question: what should I cook?

- A new Home: jump back into recipes you opened, browse your friends' trays, and see what is new from the cooks you follow.
- Search by ingredient: add what you have and see the recipes you can make now, and the ones you are almost ready to make.
- My Tray brings your own recipes and the ones you saved together.
- Every new post is a recipe, so everything you find is something you can cook.
- A fresh look across the app, from the recipe page to Cook mode.

Questions or ideas? Write to support@trays.app. We read every message.
```
(594 / 4000)

The subtitle ("Recipes from cooks you follow") still describes 1.1.0. If you
want it to lead with finding a recipe too, it ships with this build; keep it
at 30 characters or fewer.

---

## Screenshots (version 1.1.0)

Trays is iPhone only (`TARGETED_DEVICE_FAMILY` is `1` in
`ios/TraysSocial/project.yml`), so there is no iPad set.

**Size.** One 6.9-inch iPhone set, portrait: 1320 x 2868 px (1290 x 2796 px is
also accepted). App Store Connect scales it down for smaller iPhones. Upload a
separate 6.5-inch set (1284 x 2778 px) only if App Store Connect asks for one.
Confirm both sizes in App Store Connect's Media Manager before shooting; Apple
changes the required set from time to time.

**How to capture.** Use the 1.1.0 build in the iPhone Pro Max simulator, signed
in as demo_alice on the same day `seed_demo` ran (see `docs/demo-seed.md`), so
Home's sections are full. App Store screenshots must show the app in use, so
take them from the build, not from the design canvas. The W206 redesign canvas
("Trays App Screens") sets what each shot shows and how it is framed; the
artboard is named next to each shot.

| # | Screen | What it shows | W206 artboard | Caption (optional) |
|---|---|---|---|---|
| 1 | Home | Jump back in, Friends' trays, New from people you follow | Trays · interactive screens | Find what to cook tonight |
| 2 | Search, by ingredient | Three or four ingredient chips, with "You have everything" and "Almost there" results | Trays · interactive screens | Cook with what you have |
| 3 | My Tray | My recipes and Saved | Trays · interactive screens | Your recipes in one place |
| 4 | Recipe detail | Hero photo, ingredients and method | Recipe detail and Cook mode | Every post is a recipe |
| 5 | Cook mode | One step on screen | Recipe detail and Cook mode | Cook one step at a time |
| 6 | A friend's tray | demo_ben's or demo_chloe's profile and recipes | Planner, Plus, notifications, collections, friends, profile (the friends and profile part only) | See what your friends are making |
| 7 | Create a recipe | The Post recipe editor with a photo, ingredients and steps filled in | Create a recipe | Share a recipe in a few taps |

Never shoot: the meal planner, the Plus screens, the Tonight row, sponsored
results, anything with a price, the welcome and sign-in screens, or the
"Component inventory", "Logo directions" and "Web sign-in" artboards. The demo
cooks' handles (demo_alice, demo_ben, demo_chloe) appear in the shots; that is
expected.

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
