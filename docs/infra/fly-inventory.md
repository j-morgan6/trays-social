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
| `trays-social-review-pg` | staging database | 1 × shared-cpu-1x, 512 MB, yyz | Unmanaged `postgres-flex:18.1`, `--autostart`. Database `trays_social_review` |

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

### Managed Postgres — none

**Both MPG clusters were destroyed on 2026-09-17** (`nvwq9ozjv5403kl1`, which
had been staging's database, and `3x9jv02x5g4o6qp7`, which nothing ever used).
They cost $42.16/mo each.

This project uses **no Managed Postgres**. `scripts/fly-inventory-check.sh`
treats any MPG cluster as a finding — if one appears, someone created it and it
is billing $42.16/mo.

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

## Rate limits

Every rate limit in the app runs on Hammer 6.2.1 with `Hammer.Backend.ETS`
(`config/config.exs`, `config :hammer`). ETS lives inside one BEAM node, so
**every limit is per machine**:

- On N machines each limit is N times its stated value. A client whose requests
  are spread across two machines gets twice the stated attempts.
- Every restart or deploy starts with empty buckets, so any window in progress
  resets.
- All limiters are skipped when `:disable_rate_limiting` is true, which it is
  only in `config/test.exs`.

This section is the one place that states the per-machine caveat; the limiter
moduledocs say "per hour" without it.

### Callers

Every `Hammer.check_rate/3` call in `lib/` (`grep -rn "Hammer.check_rate" lib/`
lists 16 calls in 5 files).

| Caller | Bucket | Limit (per machine) | Call site |
| --- | --- | --- | --- |
| `TraysSocial.Feedback.Notifier` (feedback email cap) | `feedback_notify:global` | 30 per hour **overall**, so 30 per machine | `lib/trays_social/feedback/notifier.ex:74` |
| `TraysSocial.Feedback.Notifier` (cap-reached log line) | `feedback_notify:cap_logged` | 1 per hour, so the line logs once per machine | `lib/trays_social/feedback/notifier.ex:93` |
| `TraysSocialWeb.FeedbackRateLimit` | `feedback:user:<id>` | 5 per user per hour | `lib/trays_social_web/feedback_rate_limit.ex:38` |
| `TraysSocialWeb.FeedbackRateLimit` | `feedback:ip:<address>` | 20 per address per hour | `lib/trays_social_web/feedback_rate_limit.ex:55` |
| `TraysSocialWeb.AuthRateLimit.check_password_login/2` | email | 5 per email per 15 min | `lib/trays_social_web/auth_rate_limit.ex:74` |
| `TraysSocialWeb.AuthRateLimit.check_password_login/2` | IP | 20 per IP per 15 min | `lib/trays_social_web/auth_rate_limit.ex:76` |
| `TraysSocialWeb.AuthRateLimit.check_magic_link_request/2` | email | 1 per email per 60 s | `lib/trays_social_web/auth_rate_limit.ex:92` |
| `TraysSocialWeb.AuthRateLimit.check_magic_link_request/2` | IP | 5 per IP per hour | `lib/trays_social_web/auth_rate_limit.ex:94` |
| `TraysSocialWeb.AuthRateLimit.check_password_reset_request/2` | email | 1 per email per 60 s | `lib/trays_social_web/auth_rate_limit.ex:110` |
| `TraysSocialWeb.AuthRateLimit.check_password_reset_request/2` | IP | 5 per IP per hour | `lib/trays_social_web/auth_rate_limit.ex:112` |
| `TraysSocialWeb.AuthRateLimit.check_registration/1` | IP | 5 per IP per hour | `lib/trays_social_web/auth_rate_limit.ex:125` |
| `TraysSocialWeb.AuthRateLimit.check_existing_account_notice/1` (used by `lib/trays_social_web/existing_account_notice.ex:43`) | email | 1 per email per hour | `lib/trays_social_web/auth_rate_limit.ex:143` |
| `TraysSocialWeb.AuthRateLimit.check_email_change/1` | user | 5 per user per hour | `lib/trays_social_web/auth_rate_limit.ex:161` |
| `TraysSocialWeb.API.RateLimitPlug` | `api_rate_limit:<path>:<user or IP>` | per router pipeline, below | `lib/trays_social_web/api/rate_limit_plug.ex:40` |
| `TraysSocialWeb.UserConfirmationController` (resend) | `confirm_resend:user:<id>`, or one shared `confirm_resend:anon` bucket when no account matches | 1 per user per 60 s (the anon bucket is 1 per 60 s for all unmatched requests on the machine) | `lib/trays_social_web/controllers/user_confirmation_controller.ex:96` |
| `TraysSocialWeb.UserConfirmationController` (resend) | raw `remote_ip` (not the /64 the others use) | 5 per IP per hour | `lib/trays_social_web/controllers/user_confirmation_controller.ex:97` |

`RateLimitPlug` limits, set per pipeline in `lib/trays_social_web/router.ex`
(the plug's own default is 10 per 60 s):

| Pipeline | Limit (per machine) |
| --- | --- |
| `:api_rate_limit_login` | 10 per 60 s |
| `:api_rate_limit_register` | 5 per 60 s |
| `:api_rate_limit_reports` | 10 per hour |
| `:api_rate_limit_read` | 300 per 60 s |
| `:api_rate_limit_write` | 60 per 60 s |
| `:api_rate_limit_resend` | 3 per 10 min |
| `:api_rate_limit_diagnostics` | 1 per 60 s |

### Current topology

Production runs one machine (the `trays-social` row above, W161;
`docs/superpowers/specs/2026-04-25-prod-environment-setup-design.md:41`), so
today every limit is enforced exactly as stated. Uploads moved to Tigris and the
volume stays mounted as a fallback (same spec, line 35), but `fly.toml` and
`fly.prod.toml` both still declare `[mounts]`, and each machine of an app with
`[mounts]` needs its own volume, so scaling out is already a deliberate step.
DNSCluster is configured (`lib/trays_social/application.ex`,
`rel/env.sh.eex:4`), so a second machine joins the cluster on its own.

`TraysSocial.RateLimitClusterGuard` (started before DNSCluster) logs a warning
whenever another node joins: `rate limits are per machine: connected_nodes=N
...`, naming this section. It logs the count only, never a node name, because
node names embed the machine's private IP (`rel/env.sh.eex:5`). It changes no
limit.

### Options

| Option | How | Gains | Costs |
| --- | --- | --- | --- |
| **A. Per-machine ETS (current)** | Keep `Hammer.Backend.ETS`, keep production at one machine, warn when a node joins | No new infrastructure, no per-check cost | Limits multiply silently if the warning is ignored; buckets reset on every deploy |
| **B. Postgres-backed counter** | A rate-limit table with an atomic upsert-and-increment, or a custom `Hammer.Backend` | Cluster-wide; survives deploys | A database write per check, including every API request through `RateLimitPlug`, on the single-node `trays-social-db` |
| **C. Redis** | A Hammer Redis backend against a hosted Redis (for example Upstash on Fly) | Cluster-wide and fast | A paid service, a new secret, and a network dependency on every auth request |
| **D. One owning node** | Route every check through one cluster node (a `:global` process or a Mnesia backend) | No new service | Limits break during netsplits and deploys; every check pays cross-node latency |

**Chosen default: A**, because production runs one machine and its volume keeps
it there. **The choice is adjustable**: moving to B is a follow-up task that
keeps the guard as a tripwire. Open question for the owner: whether to move to
B before App Store traffic grows.

### Before running a second machine

1. Decide between A and B. Staying on A means accepting that every limit above
   doubles (and the feedback email cap becomes 30 per machine); otherwise build
   B first.
2. Create a volume for the new machine, since both apps declare `[mounts]`.
3. Update the Apps and Volumes tables in this file in the same commit.
4. After it joins, check `fly logs` for one `rate limits are per machine:
   connected_nodes=1` warning per machine (both machines see the other join,
   so a two-machine app logs two such lines), and confirm none carries a node
   name.
5. Expect every deploy to reset the buckets on every machine.

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

Verified green in CI run `35290535562`: `mix test`, `deploy_review` (which ran
`release_command = '/app/bin/migrate'` against the new database), and
`deploy_prod` all succeeded.

Both MPG clusters were then destroyed. **The secret-swap rollback path is now
closed** — the only remaining copy of the pre-migration staging data is the
local dump at `~/trays-review-staging-backup.dump` (102 KB, 27 tables).

Result: **$102.94/mo → ~$21/mo** (~$985/yr). Remaining spend is prod web $6.57,
prod db $2.24, staging web $6.57, staging db $2.24, and $3.42 of volumes.

### 2026-10-13 — staging database resized to 512 MB (W202)

At 256 MB, `trays-social-review-pg` reset connections repeatedly while the
recipe-first goal (G42) was being tested on review: its `vm` health check went
critical and the app logged `DBConnection.ConnectionError tcp recv (idle):
closed`, which crashed in-flight LiveViews and made Browse and What I have look
broken. The prod database `trays-social-db` was not touched.

- `fly machine update 841e0dcde30e18 --vm-memory 512 -a trays-social-review-pg`
  (same machine and volume; about a minute of downtime).
- Afterwards: `shared-cpu-1x:512MB`, all three health checks (`pg`, `role`,
  `vm`) passing.
- Adds roughly $2-3/mo to the staging database line above.
- If resets return at 512 MB, check the idle/autostop settings before resizing
  again.

### 2026-11-14 — Rate limits recorded as per machine (W265)

- Added the Rate limits section: every Hammer caller, per-machine and
  reset-on-deploy semantics, options A to D, and A as the adjustable default.
- Added `TraysSocial.RateLimitClusterGuard`, which warns when a node joins.
- No Fly resource and no limit value changed.
