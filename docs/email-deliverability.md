# Email deliverability runbook

Email from this app passes through three layers that must each be configured. When any one of them is misconfigured or quietly broken, **some or all email silently disappears** — Resend's API returns `{:ok, ...}` regardless. The 2026-05-14 magic-link-to-privaterelay incident (D63/W106) was this exact failure mode.

This document is the source of truth for what those three layers are, how to configure each, and how to verify they're working without an incident.

## Layers

```
[Your app]  -->  [Resend]  -->  [Recipient inbox]
            (1)            (2)
                                ↑
                          (3) Apple privaterelay (Apple Sign In users only)
```

1. **Resend domain verification** — Resend will only deliver mail from a domain whose SPF + DKIM records resolve correctly. If the records are missing or stale, Resend silently drops sends.
2. **DMARC alignment** — Even if SPF + DKIM pass, Gmail / Outlook / Apple Mail will route to spam (or reject) if DMARC alignment fails. Required for inbox placement at any meaningful scale.
3. **Apple Sign in private relay registration** — Apple's relay (`*@privaterelay.appleid.com`) forwards mail to a user's real inbox only if the sender domain is registered as an authorized email source in the Apple Developer portal for this app. Without this, Apple's relay accepts the relay address but refuses to forward.

All three are configured outside the repo (DNS provider + Resend dashboard + Apple Developer portal). This document is the only place they're documented.

---

## Layer 1 — Resend domain verification

### Where it lives

- Resend dashboard → Domains → `trays.app`. Status must be **Verified**.
- The verification is per-environment but the domain is shared across prod and review (both deploys send `from: noreply@trays.app`).

### DNS records required

These TXT records must resolve for `trays.app`. The exact values come from the Resend dashboard's domain detail page — Resend rotates DKIM selectors periodically and the dashboard always shows the current expected values. Don't hardcode them here.

| Record type | Name | Purpose | Where to get the value |
|---|---|---|---|
| TXT | `send.trays.app` (or `trays.app`) | SPF — Resend's sending IPs | Resend dashboard → Domains → trays.app |
| TXT | `resend._domainkey.trays.app` | DKIM — Resend's signing key | Resend dashboard → Domains → trays.app |
| MX | `send.trays.app` | Return-path / bounce handling | Resend dashboard → Domains → trays.app |

### How to verify by hand

```bash
dig +short TXT trays.app | grep spf
dig +short TXT resend._domainkey.trays.app
dig +short MX send.trays.app
```

If any of these return empty, the record is missing or hasn't propagated yet (DNS propagation is up to ~48h in the worst case but usually <30 minutes for Cloudflare).

### What goes wrong

- **Records missing** → Resend returns 422 from the send API. Caught by D63's error_tracker entry (`/admin/errors`) since this fix landed.
- **Records present but Resend status is "Pending"** → Resend hasn't yet re-checked. Click "Verify" on the dashboard.
- **Records were valid, then DNS provider cleanup removed them** → Same as missing. Run `mix audit.deliverability` after any Cloudflare cleanup.

---

## Layer 2 — DMARC

DMARC tells receiving inboxes how to treat mail that fails SPF/DKIM alignment. Without a published DMARC record, Gmail (in particular) is aggressive about routing to spam.

### Record

A single TXT record at `_dmarc.trays.app`:

```
v=DMARC1; p=quarantine; rua=mailto:dmarc@trays.app; ruf=mailto:dmarc@trays.app; fo=1; aspf=r; adkim=r;
```

- `p=quarantine` is the right starting policy (not `p=reject` until you've watched the aggregated reports for a few weeks).
- `rua` / `ruf` should point at a mailbox you actually monitor. If you don't have one, leave them out — Gmail still processes the record; you just lose visibility.

### How to verify

```bash
dig +short TXT _dmarc.trays.app
```

Should print the `v=DMARC1; ...` record.

### What goes wrong

- **Record present but receiving inbox flags as spam anyway** → DMARC alignment is failing. Run `mxtoolbox.com/dmarc.aspx` against a recent message; will show which check (SPF vs DKIM) is misaligned.
- **`p=reject` set too early** → Legitimate mail bounces hard. Roll back to `p=quarantine` (or `p=none` for diagnostics) until alignment is stable.

---

## Layer 3 — Apple Sign in email source registration

This is the one that surprised us (D63). The Sign in with Apple feature gives users an `@privaterelay.appleid.com` email by default ("Hide my email"). Apple's relay is a strict forwarding service: it forwards mail to the user's real inbox **only if** the sender's domain is registered as an authorized email source in the Apple Developer portal for the Sign in with Apple configuration of this App ID.

Without this registration, every send to an Apple privaterelay address fails silently: Apple's relay accepts the mail at the SMTP layer but never forwards. The first bounce often gets the recipient onto Resend's suppression list, after which no further sends to that user ever land — even after the registration is fixed.

### Where it lives

Apple Developer portal → Certificates, Identifiers & Profiles → Identifiers → tap `com.trays.social` → Sign in with Apple section → **Configure** button → **Email Sources** subsection.

### How to register

1. Click "+" next to Email Sources.
2. Add `noreply@trays.app` (the exact `from` address used by `TraysSocial.Accounts.UserNotifier`) AND/OR `trays.app` (registers the whole domain).
3. Apple will give you SPF + DKIM TXT records specifically for the Apple relay (separate from Resend's). Add them to DNS for `trays.app`.
4. Wait ~15 min, then come back and click "Verify". Status must be **Verified**.

The DNS records for Apple are typically combinable with Resend's SPF via `include:` (one composite SPF record listing both `_spf.resend.com` and `_spf.email.apple.com`, for example) — don't add two separate SPF records; that's invalid per the SPF spec and breaks both.

### Resend suppression cleanup

If Apple's relay rejected sends before the registration was added, the recipient is on Resend's suppression list. Even after Apple is fixed, Resend won't retry until the suppression is manually removed.

- Resend dashboard → Suppressed Recipients → find the privaterelay address → Remove.

Without this step, the registration fix appears to do nothing.

### How to verify

```bash
mix audit.deliverability
```

This task's Apple section will show PASS once both the Apple email source is Verified and the DNS records resolve.

---

## The `mix audit.deliverability` task

`mix audit.deliverability` is a CLI alternative to clicking through three dashboards. It performs DNS lookups for the records each layer requires and prints PASS / FAIL per check, exiting 0 if all pass and 1 otherwise.

```
$ mix audit.deliverability
RESEND  SPF (send.trays.app TXT)              PASS
RESEND  DKIM (resend._domainkey.trays.app)    PASS
RESEND  MX (send.trays.app)                   PASS
DMARC   _dmarc.trays.app                      PASS
APPLE   Sign in with Apple SPF include        FAIL  (no v=spf1 record including _spf.email.apple.com)

Summary: 4 PASS, 1 FAIL
```

The task does not call the Resend API or the Apple Developer portal — those have their own authoritative dashboards. The task's value is "in 5 seconds I can confirm DNS is correct on this domain without bouncing between three tabs."

### CI integration

Run `mix audit.deliverability` from a CI job on a schedule (daily is reasonable — DNS doesn't change often, but when it does the failure window matters). Don't add it to `mix precommit` — DNS lookups are slow and brittle across networks.

---

## Troubleshooting flowchart

**Symptom: "I sent a magic link but the user never received it."**

1. `/admin/errors` shows an error_tracker entry for `email_delivery_failed`? → Resend rejected the send. Check the reason in the entry; common causes: suppression, invalid API key, sender domain not verified. Fix the underlying issue.
2. `/admin/email-events` shows a `sent` event but no follow-up `delivered` after ~5 min? → Resend handed the mail off but the receiving inbox dropped it or accepted-but-never-forwarded (the Apple-relay case).
3. `/admin/email-events` shows a `bounced` event? → Click through to Resend dashboard for the full bounce reason. If recipient is `@privaterelay.appleid.com`, the most likely cause is missing Layer 3 (Apple email source registration).
4. No event at all in `/admin/email-events`? → Webhook delivery from Resend is failing, OR `RESEND_WEBHOOK_SIGNING_SECRET` is missing on this env, OR the webhook URL is misconfigured in the Resend dashboard. Verify with `fly secrets list -a <app>` and the Resend webhook endpoint detail page.
5. Recipient is an Apple privaterelay address and you've fixed Layer 3 but mail still doesn't arrive? → Check Resend suppressions; that address is likely suppressed from earlier bounces.

**Symptom: "Email arrives but lands in Gmail spam."**

1. Run `mix audit.deliverability` — confirm Layers 1 + 2 pass.
2. Send to a Gmail account, then check the message → Show original → look at the Authentication-Results header. SPF=pass, DKIM=pass, DMARC=pass should all be present.
3. If DMARC=fail with `aspf` or `adkim` listed, the alignment is wrong (the From header's domain doesn't match the SPF or DKIM signing domain). Most common cause: sending `from: noreply@trays.app` while DKIM was signed by `*.resend.com` without `resend._domainkey.trays.app` being set up.
