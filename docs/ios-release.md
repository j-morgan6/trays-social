# iOS release runbook

How Trays iOS builds get from `main` to TestFlight. The full runbook (CI upload flow, Beta vs Release builds, build numbers, retiring the manual Xcode archive) lands with the G45 docs task; this file covers the credential CI uses to talk to App Store Connect and the approval-gated Release upload.

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
| `testflight` | Beta-scheme TestFlight upload on push to `main`: the `testflight_beta` job in `.github/workflows/ios.yml` (W234) | Deployment branch: `main` only |
| `production` | Release-scheme upload to App Store Connect: the `testflight_release` job in `.github/workflows/ios.yml` (W235), and Fly `deploy_prod` | Required reviewers; deployment branch: `main` only |

In `.github/workflows/ios.yml` only the `testflight_beta` job declares `environment: testflight`, and only the `testflight_release` job declares `environment: production`; those two are the only jobs that read these secrets. `testflight_beta` runs after the `test` job passes, on a push to `main` or a plain `workflow_dispatch` on `main`. `testflight_release` runs after `test` passes, only on a `workflow_dispatch` on `main` with the `release` input set, and only once a reviewer approves. Neither runs on a pull request. The `test` job declares no environment and reads none of them.

Keep `production`'s required reviewers and its `main`-only deployment branch rule on: the reviewers are what stop the Release upload (and the prod deploy) from running without an approval, and the branch rule is what stops a dispatch from another branch, which runs that branch's own copy of the workflow, from reaching the environment at all. Both were confirmed on 2026-11-11 with `gh api repos/j-morgan6/trays-social/environments/production` (protection rules `required_reviewers` and `branch_policy`) and `gh api repos/j-morgan6/trays-social/environments/production/deployment-branch-policies` (one policy, `main`).

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
4. Confirm both environments list the three secrets (`gh secret list --env testflight`, `gh secret list --env production`). Then confirm one Beta upload succeeds with the new key before going on: either the next push to `main` that starts the iOS workflow (it watches `ios/**`, `scripts/regen-xcodeproj.sh`, `scripts/test-regen-xcodeproj.sh`, `scripts/test-ios-workflow.rb` and `.github/workflows/ios.yml`; its `testflight_beta` run uses the new key), or, when the newest `main` commit touched none of those paths and so has no upload at its build number yet, `gh workflow run ios.yml --ref main`. Dispatching on a commit whose build number is already in App Store Connect fails as a duplicate.
5. Revoke the old key in App Store Connect.
6. Update the table above.

---

## Release (App Store) upload

The App Store build is uploaded by CI, behind the same approval as the prod backend deploy. Submitting it for App Review stays a manual click in App Store Connect; nothing in CI submits.

1. Check the version first. App Store Connect refuses an upload to a version that is already approved or live, so after a version ships, bump `MARKETING_VERSION` in `ios/TraysSocial/project.yml` before the next Release upload (and update `InfoPlistTests.test_marketingVersionIs1_1_0`, which pins it). The job prints the marketing version in its "Assert archive" step.
2. Confirm the `production` environment has the three secrets: `gh secret list --env production`.
3. Start the run on `main`:
   ```
   gh workflow run ios.yml --ref main -f release=true
   ```
   (Actions → iOS → Run workflow, with "release" ticked, does the same.) A release run skips the Beta upload. Its `test` job has its own concurrency group, so it neither cancels nor is cancelled by a push's `test` run.
4. The `test` job runs first. Then `testflight_release` waits on the `production` environment. Approve it in the run's page to build. **Reject** it and no step runs: nothing is archived, nothing is uploaded, and the key is never written.
5. After approval the job archives the `TraysSocial` scheme with the Release configuration, asserts the archive talks to `https://trays.app`, carries the expected build number and is signed with its entitlements, then uploads it with `ios/TraysSocial/ExportOptions-AppStore.plist`.
6. In App Store Connect, attach the processed build to the App Store version and submit it for review by hand.

### Build numbers

| Upload | Build number (`CFBundleVersion`) | Made by |
|---|---|---|
| Beta (`testflight_beta`) | `N`, the commit count of `main` | `scripts/regen-xcodeproj.sh` |
| Release (`testflight_release`) | `N.1` | `scripts/regen-xcodeproj.sh 1` |

The push to `main` uploads Beta `N`; a Release run on the same commit uploads `N.1`, so the two never collide. App Store Connect compares build numbers component by component, so `N < N.1 < N+1`: a Release still sorts below the next commit's Beta. Approve a Release promptly; if a newer Beta has gone up in the meantime, dispatch again on the new `HEAD` rather than re-running the old run.

Re-running a Release on the same commit fails at the upload step as a duplicate `N.1`, exactly as re-running a Beta does. Push a new commit instead.

The suffix argument is validated (a positive integer, no leading zero), and with no argument the script does exactly what it always has. `scripts/test-regen-xcodeproj.sh` checks both without Xcode and runs in the `test` job. `scripts/test-ios-workflow.rb`, also run in the `test` job, pins the Release job's shape: dispatch-only on `main`, the `production` environment, its own non-cancelling concurrency group, the Release scheme and configuration, no job outside a gated environment that reads the key or builds prod, and nothing that submits for review. A suffixed build number is not an integer, so do not run `InfoPlistTests` after a suffixed regen; run the plain regen first.
