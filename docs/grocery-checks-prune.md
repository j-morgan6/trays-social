# Grocery checks prune (W181)

`grocery_checks` is written on every grocery-list checkbox tap. Rows are
never cleaned up by the write path (see the trade-off note on
`TraysSocial.MealPlans.set_check/4`), so this prune keeps the table bounded
by age.

---

## What it deletes

Every `grocery_checks` row whose `week_start` is earlier than:

    Monday of the current week (UTC) - retention_weeks * 7 days

`week_start` is always Monday-normalized, so the cutoff is a Monday too and
the boundary is exact. With the default `retention_weeks: 8`, the current
week plus the 8 previous weeks are kept.

Guarantees:

- The current week's rows are **never** deleted, under any setting, so a
  user mid-shop never sees their checkboxes clear. Future weeks (a user
  planning ahead) are never deleted either.
- Re-running is a harmless no-op — the second run deletes nothing.
- It is a global maintenance operation. It takes no user id and is exposed
  on no API or web route.

Deleting an old check is invisible to users: the grocery list for a week
outside the window simply renders unchecked.

## Configuration

`config/config.exs`:

```elixir
config :trays_social, :grocery_checks, retention_weeks: 8
```

Must be a positive integer; anything else makes the prune raise
`ArgumentError` rather than guess.

## Running it

There is no in-app scheduler (no Oban or periodic process), so the prune is
an operator task run from a release shell:

```bash
fly ssh console --app trays-social --command 'bin/trays_social eval "TraysSocial.Release.prune_grocery_checks()"'
```

It prints `[prune_grocery_checks] OK — deleted N grocery_checks rows.` and
logs `grocery_checks prune: deleted=N cutoff=YYYY-MM-DD retention_weeks=W`
at `:info`.

Suggested cadence: monthly. The table only grows with active checklist use,
so an occasional run is enough; adding a scheduling dependency for this one
low-priority job is deliberately avoided. If a scheduler is introduced later,
call `TraysSocial.MealPlans.prune_grocery_checks/1` from it.

## Index note

The existing `grocery_checks` indexes lead with `user_id`, so this global
`week_start < cutoff` delete is a sequential scan. That is acceptable for an
infrequent maintenance run on a table the prune itself keeps bounded. Add an
index on `week_start` only if a query plan on production-sized data shows the
scan has become a problem.
