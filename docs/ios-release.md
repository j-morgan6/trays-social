# iOS release runbook

How Trays iOS builds get from `main` to TestFlight. The full runbook (CI upload flow, Beta vs Release builds, build numbers, retiring the manual Xcode archive) lands with the G45 docs task; this file starts with the credential CI uses to talk to App Store Connect.

---

## App Store Connect API key

CI signs and uploads builds with an App Store Connect **Team** API key, never an Apple ID or an app-specific password.

| | |
|---|---|
| Name | `Trays CI` |
| Type | Team key (App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys) |
| Role | Admin |
| Scope | The whole team, not just Trays: App Store Connect Team keys cannot be limited to one app |
| Created | 2026-11-09 |

**Why Admin:** cloud-managed signing (`xcodebuild -allowProvisioningUpdates -authenticationKeyPath ...`) creates and uses cloud-managed distribution certificates on the team's behalf, and Apple ties that to the Admin role. This has not yet been exercised by a real CI upload; if the first one shows a lower role is enough, rotate to a narrower key and update this table.

### Where the secrets live

The key lives only as **environment-scoped** GitHub Actions secrets, never at repository level, so a workflow job that does not declare one of these environments cannot read it.

| Secret | Contents |
|---|---|
| `ASC_KEY_ID` | The key's Key ID |
| `ASC_ISSUER_ID` | The team's Issuer ID |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_<KEY_ID>.p8` of the downloaded private key |

| GitHub environment | Will be used by | Gate |
|---|---|---|
| `testflight` | Beta-scheme TestFlight upload on push to `main` (G45, Beta upload task; not wired yet) | Deployment branch: `main` only |
| `production` | Release-scheme TestFlight upload (G45, Release upload task; not wired yet), and Fly `deploy_prod` (live today) | Required reviewers |

As of this commit `.github/workflows/ios.yml` only builds and tests: it declares no environment and reads none of these secrets.

Keep `production`'s required reviewers on: it is what stops the Release upload (and the prod deploy) from running without an approval.

**What the approval does not protect.** Both environments hold the same Admin key, and `testflight` has no reviewer (Beta uploads are meant to run unattended). So the `production` approval gates the Release *upload*, not the *key*: any job on `main` that declares `environment: testflight` can use it. `testflight` is restricted to the `main` deployment branch so pull requests and other branches cannot reach it.

This was accepted on 2026-11-09 because only the maintainer can push to `main`. Two things keep it that way:

- `.github/workflows/workflow-guard.yml` fails CI if any workflow subscribes to the pull-request-target event, the one trigger that runs fork code with the base repo's secrets.
- Never give anyone else push access to `main` without revisiting this. At that point either give `testflight` its own narrower key (which means manual signing for Beta builds) or add a required reviewer to it.

Check the secrets are present (values are never shown):

```
gh secret list --env testflight
gh secret list --env production
```

### Rules

- This repo is **public**. Key material never goes in a commit, an issue, a Stride field, a chat, or a workflow log.
- Apple lets you download the `.p8` once. It is kept in the password manager, not on disk. `.gitignore` blocks `*.p8` and `AuthKey_*` as a backstop, but download it outside the repo anyway.
- If the key is ever exposed, revoke it in App Store Connect first, then generate a replacement and re-set all three secrets in both environments.

### Rotating the key

1. Generate a new Team key in App Store Connect and download its `.p8` to `~/Downloads` (outside the repo).
2. Re-set the three secrets in both environments:
   ```
   gh secret set ASC_KEY_ID        --env testflight --body "<KEY_ID>"
   gh secret set ASC_ISSUER_ID     --env testflight --body "<ISSUER_ID>"
   base64 -i ~/Downloads/AuthKey_<KEY_ID>.p8 | gh secret set ASC_KEY_P8_BASE64 --env testflight
   ```
   Repeat with `--env production`.
3. Save the `.p8` in the password manager, then delete the local copy: `rm ~/Downloads/AuthKey_<KEY_ID>.p8`.
4. Confirm both environments list the three secrets (`gh secret list --env testflight`, `gh secret list --env production`). Until the G45 upload jobs exist that is the only check available; once they do, run one upload with the new key before going on.
5. Revoke the old key in App Store Connect.
6. Update the table above.
