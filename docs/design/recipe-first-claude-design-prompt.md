# Recipe-first Trays: Claude Design prompt (W206)

**Status:** run by the user; designs returned 2026-11-11 as https://claude.ai/artifact/KCHRFDF1t35vQMahutG2Fi
**Implementation:** Stride goal G46 (W238-W253), a dependency of G43 (iOS 1.1.0)
**Source spec:** `docs/superpowers/specs/2026-10-08-recipe-first-trays-design.md`
**Theme sources:** `ios/TraysSocial/TraysSocial/App/Theme.swift`, `color_theme.md` ("Modern Kitchen")

How to use it: copy everything inside the fence below into a new Claude Design project, then
bring the result (link or screenshots) back to the session. Implementation tasks for G42 are filed
from the returned designs, not from this prompt.

Notes for the session that picks this up:

- Search reflects W205 (shipped 2026-10-23): one search box, no Recipes / What I have switch.
- Custom visuals stay placeholders (`[LOGO]`, `[ICON: name]`, `[PHOTO]`); the user makes those.

````text
Design the three main screens of Trays, a recipe app for home cooks, for both iOS (iPhone) and
the web (desktop plus a narrow mobile-web width). Produce one self-contained interactive artifact
(a React app is fine) that shows every screen and state listed below, with a toggle for iOS / web
and for light / dark mode, so I can click through and judge the polish before anything is built.

WHAT THE APP IS FOR
People open Trays to find a recipe. They look in three places: their own tray (recipes they posted
or saved), a friend's tray (recipes from someone they follow), and everyone on Trays (by name, dish
or the ingredients they have). There is no endless social feed. Nothing scrolls forever; the
"new from people you follow" row ends with a "You're caught up" card. The current screens were
built function-first and look weak; I want intentional, warm, cookbook-like visual design.

HARD RULES
- No emojis anywhere: not in UI, labels, placeholders or sample content. Use words or icons.
- Do not draw logos, illustrations or custom icons. Use labelled placeholders such as [LOGO],
  [ICON: bell], [ICON: plus], [PHOTO], [AVATAR]. SF Symbols (iOS) and Heroicons (web) names are fine
  for standard icons; write the name, e.g. "magnifyingglass" / "hero-magnifying-glass".
- Recipe photos are [PHOTO] blocks with a warm neutral fill; vary aspect ratios realistically.
- Use only the tokens below. Do not introduce new brand colours.

THEME TOKENS (from the iOS Theme and the "Modern Kitchen" palette; web mirrors them)
Brand:  primary #1B5E20 (emerald), primaryLight #2E7D32, secondary #A5D6A7 (mint),
        accent #FFB300 (amber, canonical accent), cream #F4EFE2, gold #FFC65A
Light:  background #FAFAF6, surface #FFFFFF, lift #F2EFE6, text #1A1A1A, muted #6A6A66,
        subtle #9B9B95, hairline rgba(26,26,26,0.05), hairline-strong rgba(26,26,26,0.10),
        border rgba(26,26,26,0.08)
Dark:   background #161614, surface #1F1F1D, lift #2A2A27, text #EDEDE7, muted #9A9A93,
        subtle #6A6A65, hairline rgba(237,237,231,0.06), hairline-strong rgba(237,237,231,0.12),
        border rgba(237,237,231,0.10)
Amber family: accent-ink light #FF8F00 / dark #FFC246, accent-muted rgba(255,179,0,0.25)
        (selected chips), accent-pressed 0.40, accent-border 0.32, ink-on-accent #1A1A1A
Floating pills (tab bar, bottom bar): light rgba(255,255,255,0.78), dark rgba(32,32,30,0.72),
        backdrop blur 20
Type:   headings in Instrument Serif (display 44, H1 40, H2 32, H3 28, H4 24, H5 20, H6 18,
        italic allowed for editorial empty-state lines); everything else the system sans
        (SF Pro on iOS, the system UI stack on web). Section labels are small, bold, uppercase,
        tracked, in muted.

APP SHELL (both platforms)
- Top: floating pill tabs "Home · My Tray · Search"; Home is the default. A bell [ICON: bell] for
  notifications sits at the top.
- iOS bottom: a floating pill with a Create button [ICON: plus] and the profile [AVATAR].
- Web: the same three destinations in a top navigation bar with Create and the avatar; the
  content column is wide on desktop (multi-column grids) and collapses cleanly at phone width.
- Ads never appear on Home or My Tray. Search may show a "Sponsored" tile (mark it clearly as
  [SPONSORED TILE]) about one per 8 items in "Most saved this week" and in "Everyone" results.

SCREEN 1: HOME (no search bar on Home)
Sections, top to bottom, each appearing only when it has content:
1. Jump back in: a grid of up to 6 of the user's own or saved recipes, most recently opened first.
   This should feel like the heart of the screen: one tap from launch to a recipe.
2. Tonight: a single slim strip, "Tonight: <recipe name> · Week >", linking to the meal planner.
   Only shown when today has a planned meal.
3. Friends' trays: a row of up to 10 avatars with names (people the user follows, ordered by
   their latest recipe), plus "See all". Tapping one opens that person's tray.
4. New from people you follow: a horizontal row of recipe cards from the last 7 days, newest
   first, at most 20, ending with a "You're caught up" card.
States to design:
- Full state (all four sections).
- No Tonight (most users).
- Follows people but nothing new this week: the row is only the end card, reading
  "Nothing new this week".
- Brand-new user (empty tray, follows no one): one welcome block with "Post your first recipe",
  "Find recipes in Search", and up to 5 suggested cooks with Follow buttons.
- Loading: skeletons that mirror each section's shape.

SCREEN 2: SEARCH (one search box, no mode switch)
- One search field: "Search recipes, ingredients, cooks". Typing searches as you go. Pressing
  return/Enter turns the typed text into an ingredient chip shown under the field (chips have a
  remove "x"; at most 10, with an "Up to 10 ingredients" note when full).
- A quiet hint under the field while the user has 0-1 chips and is typing: "Press return to add
  an ingredient. Add two or more to see what you can make."
- "Recently used" ingredient chips (with a "+") appear under the field when the box is empty.
Result states to design:
a. Before typing (Browse): category tiles (Quick dinners, Chicken, Pasta, Breakfast, Baking,
   Soups) in a grid, then "Most saved this week" recipe grid.
b. One term (typed or one chip): grouped results in this order, each group with "See all":
   Cooks (avatar rows), In your tray (up to 5), From people you follow (up to 5), Everyone
   (grid, continues on scroll).
c. Two or more ingredients: "You have everything" then "Almost there". Each row shows the recipe
   photo, title, @cook and, for Almost there, a "missing: soy sauce, ginger" line. This is the
   "what can I make with what I have?" moment; make it feel useful and calm, not like a filter.
d. No matches: "No results yet. Try a different recipe, ingredient, or cook." (one term) and
   "No matches yet. Try removing an ingredient." (ingredients).
e. Loading for b and c.
Show how the switch from (b) to (c) reads when the second chip is added, so it feels natural.

SCREEN 3: MY TRAY
Top to bottom: "Plan your week" (meal planner entry point; a Plus-subscriber feature, show it
both as an active weekly planner preview and as a locked teaser), Collections (horizontal row of
collection cards, plus "New collection"), then two lists switchable by a segmented control or
tabs: "My recipes" and "Saved".
States: full; new user with nothing posted or saved (encouraging empty states for each list);
a legacy photo-only post in My recipes, shown at its position with a small "Photo" label.
Also design a Friend's tray (someone else's profile): header with [AVATAR], name, bio,
"Recipes / Followers / Following" counts and a Follow button, then their recipe grid. Their
Saved list and collections are never shown.

DELIVERABLE
- One interactive artifact with: iOS and web variants of Home, Search (states a-e) and My Tray
  (plus Friend's tray), light and dark mode, and the empty and loading states above.
- A short component inventory at the end: card styles (grid card, row card, end card, tile),
  chips, section headers, empty-state block, skeletons, with the token each uses, so the design
  can be implemented in SwiftUI and Phoenix LiveView with Tailwind/daisyUI.
````

## After the designs come back

Done on 2026-11-11:

1. The designs were reconciled with the spec as decisions D13-D16 and section 12. The canvas covers more than this prompt asked for: sign-in, recipe detail, Cook mode, the editor, planner, Plus, notifications and the logo. Headings use a rounded sans in place of Instrument Serif. The logo is C Handles (SVGs in this folder). Behaviours the canvas draws that the app lacks are recorded as ideas, not scope.
2. Implementation is filed as G46: brand assets (W238), iOS and web foundations (W239, W240), then one restyle task per screen group and platform (W241-W253).
