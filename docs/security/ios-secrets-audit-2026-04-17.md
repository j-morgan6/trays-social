# iOS Client Secrets Audit — 2026-04-17

Scope: `ios/TraysSocial/**` (Swift, Info.plist, entitlements, xcconfig, project.pbxproj, assets).
Purpose: confirm no API keys, tokens, or secrets are shipped inside the iOS binary (W97).

## Method

1. Regex scans across all `*.swift` files in the iOS tree.
2. Inventory of all `.plist`, `.xcconfig`, `.entitlements` files.
3. Review of `Configuration.swift`, `APIClient.swift`, `KeychainService.swift`, `PushNotificationService.swift`.
4. Cross-check backend `config/runtime.exs` and `fly.toml` to confirm secrets live server-side.
5. Grep for common shipped-key patterns: AWS (`AKIA...`), Stripe (`sk_live_...`), Google (`AIza...`), GitHub (`ghp_...`), Slack (`xox[baprs]-`).

## Results

### No shipped secrets found

- Regex `(secret|api[_-]?key|token|password|bearer)\s*=\s*["'][^"'$]` across all `*.swift`: **no matches**.
- Regex for known vendor key prefixes (AWS / Stripe / Google / GitHub / Slack): **no matches**.
- Regex for hardcoded long literal string constants (`static let X = "[20+ chars]"`): **no matches**.

### What lives in the iOS client (all non-sensitive)

| Location | Value | Risk |
|---|---|---|
| `Configuration.swift` | Reads `API_BASE_URL` from `Info.plist` | None — public URL |
| `Info.plist` → `API_BASE_URL` | `$(API_BASE_URL)` build variable | None |
| `project.pbxproj` build settings | `API_BASE_URL = "https://trays-social-review.fly.dev"` (Debug + Release) | None — public URL |
| Bundle id, version, etc. | Standard iOS metadata | None |
| `KeychainService` | Stores user auth **token** in iOS Keychain (runtime) | **Not a shipped secret** — per-user runtime token |
| `APIClient` | Sets `Authorization: Bearer \(token)` from Keychain | Uses runtime token; no hardcoded value |
| `PushNotificationService` | Registers APNs device token via backend | Device token is issued by APNs at runtime; APNs private key lives server-side |

### Backend secrets (correctly server-side)

All secrets in `config/runtime.exs` are read from env vars via `System.get_env/1`:

- `SECRET_KEY_BASE`
- `DATABASE_URL`
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_P8_KEY`
- S3 endpoint/base URL

`fly.toml` contains only public values (`PHX_HOST`, `PORT`, `UPLOAD_DIR`) — no secrets inlined.

## Findings

**No remediation required.** The iOS client ships only public configuration (`API_BASE_URL`) plus runtime-issued tokens in Keychain. All sensitive credentials correctly live in backend env vars.

## Recommendation (optional)

Consider adding a CI step that runs the vendor-key regex against the iOS tree on every PR so a future accidental commit is caught automatically. Command:

```bash
rg -nE '(AKIA[0-9A-Z]{16}|sk_live_|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36}|xox[baprs]-)' ios/
```

Non-zero exit (match) should fail the build.

## Verification commands used

```bash
# 1. Generic secret-like assignment
rg -niE '(secret|api[_-]?key|token|password|bearer)\s*=\s*["'"'"'][^"'"'"'$]' ios/TraysSocial --glob '*.swift'

# 2. Vendor key prefixes
rg -nE 'AKIA[0-9A-Z]{16}|sk_live_|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36}|xox[baprs]-' ios/

# 3. Long string literals
rg -nE 'static\s+(let|var)\s+\w+\s*(:|=)\s*["'"'"'][A-Za-z0-9_\-]{20,}' ios/ --glob '*.swift'

# 4. Config / entitlements inventory
find ios -name "*.plist" -o -name "*.xcconfig" -o -name "*.entitlements"
```

All commands returned no secrets.
