# Post Creation Redesign

## Problem

The current post creation form treats every post as a recipe — requiring ingredients, cooking steps, and cooking time. This creates unnecessary friction for users who just want to share a photo of food they ate at a restaurant, a friend's house, or anywhere else. The form needs to support both structured recipe posts and casual food photos.

## Design

### Post Types

Two post types, selected before the form is shown:

- **Recipe** — structured post for sharing how you made something
- **Post** — casual photo share for any food context

### Type Picker

Full-page screen at `/posts/new`. Two large tappable cards:

- "Recipe" with subtitle "Share how you made it"
- "Post" with subtitle "Share what you're eating"
- Cancel link returns to previous page

Selecting a type navigates to the form with the type set (e.g., `/posts/new?type=recipe` or `/posts/new?type=post`). Back button on the form returns to the type picker.

### Form Fields by Type

**Shared (both types):**

| Field | Required | Notes |
|-------|----------|-------|
| Photo(s) | Yes (at least 1) | Up to 5, drag/drop, jpg/jpeg/png/heic, 10MB max |
| Caption | No | Textarea, 500 char limit |
| Tags | No | Comma-separated, normalized to lowercase |

**Recipe-only fields:**

| Field | Required | Notes |
|-------|----------|-------|
| Ingredients | Yes (at least 1) | Dynamic rows: name (required), quantity, unit |
| Cooking Steps | Yes (at least 1) | Dynamic rows: description (300 char max), ordered |
| Cooking Time | Yes | Integer, minutes, > 0 |
| Servings | No | Integer |
| Tools | No | Dynamic rows: name |

**Removed fields:**

| Field | Reason |
|-------|--------|
| Difficulty | Cut entirely — not needed |

### Data Model Changes

**`posts` table:**

- Add `type` column: string, not null, default `"recipe"`. Allowed values: `"recipe"`, `"post"`.
- Remove `difficulty` column.

**Changeset changes:**

- `caption`: remove from `validate_required`
- `cooking_time_minutes`: validate required only when `type == "recipe"`
- `ingredients` association: validate length >= 1 only when `type == "recipe"`
- `cooking_steps` association: validate length >= 1 only when `type == "recipe"`

**Migration:**

1. Add `type` column with default `"recipe"` — all existing posts become recipes automatically.
2. Remove `difficulty` column.
3. No data migration needed.

### Post Display

The show page conditionally renders sections based on `post.type`:

**Recipe display:**
- Photo carousel
- Caption (if present)
- Cooking time and servings chips (difficulty chip removed)
- Like button
- Ingredients list
- Tools list (if any)
- Cooking steps
- Tags (if any)
- Comments

**Post display:**
- Photo carousel
- Caption (if present)
- Like button
- Tags (if any)
- Comments

Sections for ingredients, steps, cooking time, servings, and tools are not rendered for post-type posts.

**Feed cards:** No change needed. Already show photo + caption + like count, which works for both types.

### LiveView Changes

**`PostLive.New`** — split into three screens:

1. **Type picker**: default view at `/posts/new`, renders two cards
2. **Recipe form**: shown when `type == "recipe"`, current form minus difficulty
3. **Post form**: shown when `type == "post"`, minimal form (photo, caption, tags)

The LiveView can use a single module with the type stored in assigns, conditionally rendering the appropriate form template. Or it can use separate function components for each form. The implementation plan will determine the best approach.

**`PostLive.Show`** — conditional rendering based on `post.type` to hide recipe-specific sections for post-type posts.

### Router

No new routes needed. `/posts/new` stays the same — the type picker is the default view, and type selection is handled within the LiveView (either via query param or LiveView event).

## Backwards Compatibility

- All existing posts get `type: "recipe"` from the column default
- Existing recipe display is unchanged (minus difficulty chip)
- Feed rendering works without changes
- No data migration required
