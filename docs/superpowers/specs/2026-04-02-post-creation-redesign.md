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

Selecting a type is handled via LiveView event (`phx-click`), which sets the type in assigns and re-renders the form. No query params or navigation — everything stays within the single LiveView at `/posts/new`. Back button on the form clears the type assign, returning to the picker.

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
| Difficulty | Cut entirely — not needed. Existing difficulty data is discarded. |

### Data Model Changes

**`posts` table:**

- Add `type` column: string, not null, default `"recipe"`. Allowed values: `"recipe"`, `"post"`.
- Remove `difficulty` column. Existing data in this column is intentionally discarded.

**Changeset changes:**

- Add `type` to cast fields
- Add `validate_inclusion(:type, ["recipe", "post"])`
- `photo_url`: remains required (set from first uploaded photo)
- `user_id`: remains required
- `caption`: remove from `validate_required`
- `cooking_time_minutes`: validate required only when `type == "recipe"`
- `ingredients` association: validate length >= 1 only when `type == "recipe"`
- `cooking_steps` association: validate length >= 1 only when `type == "recipe"`
- For `"post"` type, `change_post/2` should skip `cast_assoc` for ingredients, cooking_steps, and tools since these associations are irrelevant

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

**Feed cards:** The feed currently renders cooking time chips, difficulty chips, servings chips, and an ingredients preview snippet on every card. These must be conditionally rendered based on `post.type`:
- Recipe cards: show cooking time and servings chips, ingredients preview, "View full recipe" link (difficulty chip removed)
- Post cards: hide all recipe-specific chips and snippets, show only photo + caption + like count + tags

**`post_card` core component:** Currently renders cooking time and ingredient count. Must conditionally hide these for `"post"` type.

**Profile page:** Currently renders cooking time and difficulty on post overlays. Must conditionally hide recipe-specific info for `"post"` type, and remove difficulty rendering entirely.

### LiveView Changes

**`PostLive.New`** — split into three screens within one LiveView:

1. **Type picker**: default view at `/posts/new`, renders two cards. Type selection via `phx-click` event sets `@post_type` assign.
2. **Recipe form**: shown when `@post_type == "recipe"`, current form minus difficulty
3. **Post form**: shown when `@post_type == "post"`, minimal form (photo, caption, tags)

**`PostLive.Show`** — conditional rendering based on `post.type` to hide recipe-specific sections for post-type posts. Remove difficulty rendering.

### Router

No new routes needed. `/posts/new` stays the same — the type picker is the default view, and type selection is handled within the LiveView via assigns.

### Test Changes

Existing tests will need updates:

- **`new_test.exs`**: Tests asserting difficulty select, required ingredients/steps on initial form load, and form validation for cooking_time_minutes will need to account for the type picker step and type-conditional validation.
- **`show_test.exs`**: Tests asserting difficulty display will need removal. New tests should verify conditional rendering of recipe sections vs post sections.
- **Post schema tests**: Update to test conditional validations based on type. Add tests for type validation inclusion.
- **Posts context tests**: Update `create_post` tests for both types. Ensure "post" type can be created with only photo_url and user_id.
- **Feed/profile tests**: If any assert on difficulty or recipe-specific chips, update accordingly.

## Backwards Compatibility

- All existing posts get `type: "recipe"` from the column default
- Existing recipe display is unchanged (minus difficulty chip)
- Difficulty data is intentionally discarded (confirmed acceptable)
- No data migration required
