# Error reports: filtering and retention (D120)

ErrorTracker stores every unhandled exception in `error_tracker_errors` and
`error_tracker_occurrences`, viewable at `/admin/errors` (admins only). The
Privacy Policy promises that server logs are kept for no more than 30 days and
that account deletion removes the account's data, so three things keep the
stored reports in line with it.

---

## 1. What is stripped before a report is stored

`TraysSocial.ErrorReports.Filter` is configured as ErrorTracker's filter
(`config :error_tracker, filter: ...` in `config/config.exs`). It runs inside
`ErrorTracker.report/3`, before the occurrence is written, and:

- replaces the value of any key whose name contains `password`, `token` or
  `secret`, or is one of `jws`, `signedPayload`, `signedTransactionInfo`,
  `signedRenewalInfo`, `identity_token`, `authorization_code`, `api_key`,
  `email` or `recipient` (or listed in `:phoenix, :filter_parameters`), with
  `[REDACTED]`, at any depth, in any case
- drops the `Authorization`, `Cookie` and `Set-Cookie` request headers
- redacts sensitive pairs in the raw query string, and the token segment of
  `/users/confirm/:token`, `/users/log-in/:token`,
  `/users/settings/confirm-email/:token` and `/api/v1/devices/:token`

ErrorTracker never passes the exception message (`reason`, stored on both the
error and the occurrence) to the filter, and messages such as KeyError's print
the map they failed on. A Postgres `BEFORE INSERT OR UPDATE OF reason` trigger
(`trays_redact_error_reason`, migration `20261104120100`) rewrites `reason`
before the row is written, so the plaintext is never committed:
sensitive-looking `key => "value"` / `key: "value"` pairs, Bearer/Basic
credentials and email addresses become `[REDACTED]`. Values that are not
double-quoted strings (charlists, raw binaries, atoms) are not matched.

The Logger line in `UserNotifier` still prints the recipient on a delivery
failure; Fly rotates those logs.

## 2. Retention: 30 days

`TraysSocial.ErrorReports.prune/1` deletes every occurrence older than
`retention_days` (resolved or not; ErrorTracker's own pruner only handles
resolved ones), in batches of 1000, then deletes errors that have no
occurrences left and whose last occurrence is also outside the window.

`TraysSocial.ErrorReports.Pruner` runs it 5 minutes after boot and then every
24 hours on each machine. The deletes are idempotent, so two machines running
it at once is harmless. It logs
`error_reports prune: occurrences=N errors=M cutoff=... retention_days=30` at
`:info`, never the stored context.

```elixir
config :trays_social, :error_reports,
  retention_days: 30,
  prune_interval: :timer.hours(24),
  prune_enabled: true
```

`prune_enabled: false` in `config/test.exs` keeps it out of the test suite.

On demand:

```bash
fly ssh console --app trays-social --command 'bin/trays_social eval "TraysSocial.Release.prune_error_reports()"'
```

## 3. One-off scrub of reports stored before the filter

Occurrences stored before D120 can hold plaintext request params and
exception messages. The scrub re-applies the filter to every stored context
(rewriting only the rows that change) and re-fires the reason trigger on every
stored message, on occurrences and errors. It is safe to re-run, but it
**rewrites production data**, so run it only when the operator decides to:

```bash
fly ssh console --app trays-social --command 'bin/trays_social eval "TraysSocial.Release.scrub_error_reports()"'
```

It prints `[scrub_error_reports] OK — scanned N occurrences, scrubbed M; re-checked R stored error messages.`

Waiting is **not** a substitute. The pruner removes pre-D120 occurrences after
30 days, but an error that keeps recurring is never pruned, and ErrorTracker's
upsert never rewrites an existing error's first-seen message, so
`error_tracker_errors.reason` can keep a pre-D120 secret indefinitely until the
scrub runs.

## Account deletion

`Accounts.delete_account/1` deletes the user's `ios_diagnostic_payloads` rows,
and the foreign key is `on_delete: :delete_all` (migration
`20261104120000`). Signed-out reports (no `user_id`) are kept.
