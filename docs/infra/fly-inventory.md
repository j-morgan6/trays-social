# Fly.io inventory (source of truth)

Every Fly resource this project owns, what it is for, and what it costs.
**If you create, resize, or destroy a Fly resource, update this file in the same
commit.** The September 2026 billing audit found two $42/mo Managed Postgres
clusters nobody could account for, because every prior infra change was made
directly against the Fly API with no record anywhere in git. The invoice was
the only place they were written down.

Run `scripts/fly-inventory-check.sh` to diff reality against this file.

---

## Expected inventory

### Apps

| App | Role | Machine | Notes |
| --- | --- | --- | --- |
| `trays-social` | **production** web (trays.app) | 1 × shared-cpu-1x, 1 GB, yyz | `min_machines_running = 1` (W161 — deliberate, keeps it warm) |
| `trays-social-review` | staging web (trays-social-review.fly.dev) | 1 × shared-cpu-1x, 1 GB, yyz | Backs iOS **Debug** and **TestFlight-beta** schemes — see `ios/TraysSocial/project.yml` |
| `trays-social-db` | **production** database | 1 × shared-cpu-1x, 256 MB, yyz | Unmanaged `postgres-flex`. Database `trays_social` |
| `trays-social-review-pg` | staging database | 1 × shared-cpu-1x, 256 MB, yyz | Unmanaged `postgres-flex:18.1`, `--autostart`. Database `trays_social_review` |

### Volumes

| Volume | App | Size |
| --- | --- | --- |
| `trays_social_uploads` | `trays-social` | 10 GB |
| `uploads_data` | `trays-social-review` | 1 GB |
| `pg_data` | `trays-social-db` | 10 GB |
| `pg_data` | `trays-social-review-pg` | 1 GB |

### Which app uses which database

| App | `DATABASE_URL` host | Database |
| --- | --- | --- |
| `trays-social` | `trays-social-db.flycast:5432` | `trays_social` |
| `trays-social-review` | `trays-social-review-pg.flycast:5432` | `trays_social_review` |

### Managed Postgres — being retired

| Cluster | Status |
| --- | --- |
| `nvwq9ozjv5403kl1` | **Drained 2026-09-17.** Was staging's database. Nothing points at it. Pending destroy |
| `3x9jv02x5g4o6qp7` | **Never used by any app.** Pending destroy |

Both are `basic` plan, 10 GB, yyz, **$42.16/mo each**. Neither serves anything
as of 2026-09-17.

---

## Do not trust `fly mpg list`

On this account the `ATTACHED APPS` column is **wrong**. It reported
`nvwq9ozjv5403kl1` as having no attached apps while staging was actively
connected to it, and reported `3x9jv02x5g4o6qp7` as attached to
`trays-social-review` when nothing pointed at it. Acting on that column would
have destroyed the live staging database.

The only trustworthy check is the running process's own environment:

```sh
fly ssh console -a <app> -C 'printenv DATABASE_URL' | sed -E 's#://[^@]*@#://REDACTED@#'
```

The MPG cluster id is embedded in the pgbouncer hostname.

---

## The CI coupling that makes staging load-bearing

`config/runtime.exs` raises when `DATABASE_URL` is missing, both fly configs run
`release_command = '/app/bin/migrate'`, and `.github/workflows/fly-deploy.yml`
declares `deploy_prod` with `needs: deploy_review`.

**Breaking staging's database blocks all production deploys.** Any change to
staging's database must be verified green before it is considered done.

---

## Change log

### 2026-09-17 — staging moved off Managed Postgres

Billing audit of invoice `D4CTAHXM-0011` (Aug 2026, $102.94) found $84.32/mo —
82% of the bill — going to two MPG clusters, neither serving production.

- Created `trays-social-review-pg` (unmanaged postgres-flex, 256 MB, 1 GB volume,
  autostart) — ~$2.70/mo.
- Backed up staging (`~/trays-review-staging-backup.dump`, 102 KB, 27 tables).
- Restored into `trays_social_review`, filtering MPG-only objects that
  postgres-flex does not have: `pg_stat_monitor`, `pgaudit`, and the `pgbouncer`
  schema. App-required extensions `citext` and `pg_trgm` carried over.
- Verified all 27 tables match row-for-row (9 users, 15 posts, 33 migrations).
- Repointed `trays-social-review`'s `DATABASE_URL`. Confirmed via
  `pg_stat_activity`: 11 pooled connections on the new database, zero app
  connections left on the old cluster.
- Old cluster left running and untouched as the rollback path.

Rollback (valid until `nvwq9ozjv5403kl1` is destroyed):

```sh
fly secrets set DATABASE_URL="$(cat ~/trays-review-OLD-database-url.txt)" -a trays-social-review
```

**Still open:** destroy both MPG clusters once a staging deploy has gone green.
Expected result: $102.94/mo → ~$20/mo.
