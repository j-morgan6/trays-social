# iOS release runbook

How Trays iOS builds get from `main` to TestFlight and the App Store. CI
(`.github/workflows/ios.yml`) builds, tests and uploads every build; the only
manual steps are approving a Release upload and submitting it for App Review
in App Store Connect. The manual Xcode archive is now a fallback for when CI
cannot upload, not the normal path.

---

## 1. The flow at a glance

| Trigger | Jobs | Scheme / configuration | Backend | Build number | Ends in |
|---|---|---|---|---|---|
| Push to `main` touching an iOS path | `test`, then `testflight_beta` | `TraysSocial Beta` / Beta | review (`trays-social-review.fly.dev`) | `N` | TestFlight, unattended |
| `gh workflow run ios.yml --ref main` | `test`, then `testflight_beta` | `TraysSocial Beta` / Beta | review | `N` | TestFlight, unattended |
| `gh workflow run ios.yml --ref main -f release=true` | `test`, then `testflight_release` after a `production` approval | `TraysSocial` / Release | prod (`trays.app`) | `N.1` | App Store Connect; submit for review by hand |
| Pull request touching an iOS path | `test` only | `TraysSocial` / Debug (simulator) | none | none | Nothing uploaded |

`N` is the commit count of `main` (`git rev-list --count HEAD`); see
[Build numbers](#4-build-numbers). The iOS paths are `ios/**`,
`scripts/regen-xcodeproj.sh`, `scripts/test-regen-xcodeproj.sh`,
`scripts/test-ios-workflow.rb` and `.github/workflows/ios.yml`; a
backend-only push never starts the workflow, so it uploads nothing.

**Nothing in CI submits for App Review.** That stays a manual click in App
Store Connect, for both the first build of a version and every later one.

## 2. Beta builds (push to `main`)

Every push to `main` that touches an iOS path uploads a Beta build. There is
nothing to start and nothing to approve.

1. The `test` job regenerates the Xcode project, builds the `TraysSocial`
   scheme and runs `TraysSocialTests` on a simulator. A red test stops the run
   and nothing is uploaded.
2. `testflight_beta` then runs in the `testflight` environment. It archives
   the `TraysSocial Beta` scheme with the Beta configuration, asserts the
   archive talks to `https://trays-social-review.fly.dev`, carries build `N`
   and is signed with its entitlements, and uploads it with
   `ios/TraysSocial/ExportOptions-AppStore.plist`.
3. App Store Connect processes the build (usually around 10 minutes) and it
   appears in TestFlight.

Watch a run:

```bash
gh run list --workflow ios.yml --limit 5
gh run watch <RUN_ID>
```

To upload a Beta without a new push (for example after a failed upload), run
the workflow by hand on `main`. It only works when `main`'s newest commit has
no upload yet at its build number; otherwise the upload fails as a duplicate,
and the fix is a new commit.

```bash
gh workflow run ios.yml --ref main
```

A Beta build talks to the **review** backend. It is for exercising a change
before the prod deploy is approved, and is never submitted to the App Store.

## 3. Release builds (App Store)

The App Store build is uploaded by CI, behind the same approval as the prod
backend deploy. Ship the backend first: a new iOS build calling an old backend
breaks, the reverse usually does not.

1. Check the version first. App Store Connect refuses an upload to a version
   that is already approved or live, so after a version ships, bump
   `MARKETING_VERSION` in `ios/TraysSocial/project.yml` before the next Release
   upload (and update `InfoPlistTests.test_marketingVersionIs1_1_0`, which pins
   it). The job prints the marketing version in its "Assert archive" step.
2. Confirm the `production` environment has the three secrets:
   ```bash
   gh secret list --env production
   ```
3. Start the run on `main`:
   ```bash
   gh workflow run ios.yml --ref main -f release=true
   ```
   (Actions → iOS → Run workflow, with "release" ticked, does the same.) A
   release run skips the Beta upload. Its `test` job has its own concurrency
   group, so it neither cancels nor is cancelled by a push's `test` run.
4. The `test` job runs first. Then `testflight_release` waits on the
   `production` environment. Approve it in the run's page to build. **Reject**
   it and no step runs: nothing is archived, nothing is uploaded, and the key
   is never written.
5. After approval the job archives the `TraysSocial` scheme with the Release
   configuration, asserts the archive talks to `https://trays.app`, carries
   build `N.1` and is signed with its entitlements, then uploads it with
   `ios/TraysSocial/ExportOptions-AppStore.plist`.
6. In App Store Connect, attach the processed build to the App Store version
   and submit it for review by hand.

## 4. Build numbers

| Upload | Build number (`CFBundleVersion`) | Made by |
|---|---|---|
| Beta (`testflight_beta`) | `N`, the commit count of `main` | `scripts/regen-xcodeproj.sh` |
| Release (`testflight_release`) | `N.1` | `scripts/regen-xcodeproj.sh 1` |
| Manual fallback | `N.2` | `scripts/regen-xcodeproj.sh 2` ([section 7](#7-manual-fallback-archive-in-xcode)) |

The push to `main` uploads Beta `N`; a Release run on the same commit uploads
`N.1`, so the two never collide. App Store Connect compares build numbers
component by component, so `N < N.1 < N+1`: a Release still sorts below the
next commit's Beta. Approve a Release promptly; if a newer Beta has gone up in
the meantime, dispatch again on the new `HEAD` rather than re-running the old
run.

Re-running a Release on the same commit fails at the upload step as a
duplicate `N.1`, exactly as re-running a Beta does. Push a new commit instead.

Both upload jobs also refuse a build number below `MIN_BUILD_NUMBER` (383, one
above the last manual upload) and need the full git history, because a shallow
clone makes the commit count 1. `ExportOptions-AppStore.plist` sets
`manageAppVersionAndBuildNumber` to `false` so Apple never rewrites the number.

**Never run a bare `xcodegen generate`.** `project.yml` still carries
`CURRENT_PROJECT_VERSION: 12`, so a bare generate resets the build number to
12. Always regenerate with `scripts/regen-xcodeproj.sh`, locally as in CI.

The suffix argument is validated (a positive integer, no leading zero), and
with no argument the script does exactly what it always has.
`scripts/test-regen-xcodeproj.sh` checks both without Xcode and runs in the
`test` job. `scripts/test-ios-workflow.rb`, also run in the `test` job, pins
the Release job's shape: dispatch-only on `main`, the `production`
environment, its own non-cancelling concurrency group, the Release scheme and
configuration, no job outside a gated environment that reads the key or
builds prod, and nothing that submits for review. A suffixed build number is
not an integer, so do not run `InfoPlistTests` after a suffixed regen; run the
plain regen first.

## 5. Which scheme talks to which backend

| Scheme | Action | Configuration | Backend |
|---|---|---|---|
| `TraysSocial` | Run (Cmd+R), Test | Debug | review |
| `TraysSocial` | Archive | Release | prod (`trays.app`) |
| `TraysSocial Beta` | Run (Cmd+R), Test | Debug | review |
| `TraysSocial Beta` | Archive | Beta | review (`trays-social-review.fly.dev`) |

The source of truth is `ios/TraysSocial/project.yml`: the `configs` block and
its comment, the per-configuration `API_BASE_URL` values under the
`TraysSocial` target, and the two `schemes` entries with their comments. Read
it there rather than copying it here. The app reads the value through
`API_BASE_URL` in `Info.plist` (`Configuration.apiBaseURL`).

Both CI upload jobs check the archived `API_BASE_URL` before uploading, so a
scheme that drifts to the wrong configuration fails the run instead of
shipping. A local archive has no such check: before uploading one by hand,
confirm the scheme's Archive configuration (Product → Scheme → Edit Scheme →
Archive → Build Configuration) is Release for the App Store and Beta for
TestFlight staging.

## 6. App Store Connect API key

CI signs and uploads builds with an App Store Connect **Team** API key, never
an Apple ID or an app-specific password.

| | |
|---|---|
| Name | `Trays CI` |
| Type | Team key (App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys) |
| Role | Admin |
| Scope | The whole team, not just Trays: App Store Connect Team keys cannot be limited to one app |
| Created | 2026-11-09 |

**Why Admin:** cloud-managed signing (`xcodebuild -allowProvisioningUpdates
-authenticationKeyPath ...`) creates and uses cloud-managed distribution
certificates on the team's behalf, and Apple ties that to the Admin role. This
had not been exercised by a real CI upload when the key was created; if one
shows a lower role is enough, rotate to a narrower key and update this table.

### Where the secrets live

The key lives only as **environment-scoped** GitHub Actions secrets, never at
repository level, so a workflow job that does not declare one of these
environments cannot read it.

| Secret | Contents |
|---|---|
| `ASC_KEY_ID` | The key's Key ID |
| `ASC_ISSUER_ID` | The team's Issuer ID |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_<KEY_ID>.p8` of the downloaded private key |

| GitHub environment | Used by | Gate |
|---|---|---|
| `testflight` | Beta-scheme TestFlight upload on push to `main`: the `testflight_beta` job in `.github/workflows/ios.yml` (W234) | Deployment branch: `main` only |
| `production` | Release-scheme upload to App Store Connect: the `testflight_release` job in `.github/workflows/ios.yml` (W235), and Fly `deploy_prod` | Required reviewers; deployment branch: `main` only |

In `.github/workflows/ios.yml` only the `testflight_beta` job declares
`environment: testflight`, and only the `testflight_release` job declares
`environment: production`; those two are the only jobs that read these
secrets. `testflight_beta` runs after the `test` job passes, on a push to
`main` or a plain `workflow_dispatch` on `main`. `testflight_release` runs
after `test` passes, only on a `workflow_dispatch` on `main` with the
`release` input set, and only once a reviewer approves. Neither runs on a pull
request. The `test` job declares no environment and reads none of them. Each
upload job writes the key to the runner's temp directory and deletes it in a
final step that runs even when the job fails.

Keep `production`'s required reviewers and its `main`-only deployment branch
rule on: the reviewers are what stop the Release upload (and the prod deploy)
from running without an approval, and the branch rule is what stops a
dispatch from another branch, which runs that branch's own copy of the
workflow, from reaching the environment at all. Both were confirmed on
2026-11-11 with `gh api repos/j-morgan6/trays-social/environments/production`
(protection rules `required_reviewers` and `branch_policy`) and
`gh api repos/j-morgan6/trays-social/environments/production/deployment-branch-policies`
(one policy, `main`).

**What the approval does not protect.** Both environments hold the same Admin
key, and `testflight` has no reviewer (Beta uploads are meant to run
unattended). So the `production` approval gates the Release *upload*, not the
*key*: any job on `main` that declares `environment: testflight` can use it.
`testflight` is restricted to the `main` deployment branch so pull requests
and other branches cannot reach it.

This was accepted on 2026-11-09 because only the maintainer can push to
`main`. Two things keep it that way:

- `.github/workflows/workflow-guard.yml` fails CI if any workflow subscribes
  to the pull-request-target event, the one trigger that runs fork code with
  the base repo's secrets.
- Never give anyone else push access to `main` without revisiting this. At
  that point either give `testflight` its own narrower key (which means manual
  signing for Beta builds) or add a required reviewer to it.

Check the secrets are present (values are never shown):

```bash
gh secret list --env testflight
gh secret list --env production
```

### Rules

- This repo is **public**. Key material never goes in a commit, an issue, a
  Stride field, a chat, or a workflow log.
- Apple lets you download the `.p8` once. It is kept in the password manager,
  not on disk. `.gitignore` blocks `*.p8` and `AuthKey_*` as a backstop, but
  download it outside the repo anyway.
- If the key is ever exposed, revoke it in App Store Connect first, then
  generate a replacement and re-set all three secrets in both environments.

### Rotating the key

1. Generate a new Team key in App Store Connect and download its `.p8` to
   `~/Downloads` (outside the repo).
2. Re-set the three secrets in both environments:
   ```bash
   gh secret set ASC_KEY_ID        --env testflight --body "<KEY_ID>"
   gh secret set ASC_ISSUER_ID     --env testflight --body "<ISSUER_ID>"
   base64 -i ~/Downloads/AuthKey_<KEY_ID>.p8 | gh secret set ASC_KEY_P8_BASE64 --env testflight
   ```
   Repeat with `--env production`.
3. Save the `.p8` in the password manager, then delete the local copy:
   `rm ~/Downloads/AuthKey_<KEY_ID>.p8`.
4. Confirm both environments list the three secrets
   (`gh secret list --env testflight`, `gh secret list --env production`).
   Then confirm one Beta upload succeeds with the new key before going on:
   either the next push to `main` that starts the iOS workflow (its
   `testflight_beta` run uses the new key), or, when the newest `main` commit
   touched no iOS path and so has no upload at its build number yet,
   `gh workflow run ios.yml --ref main`. Dispatching on a commit whose build
   number is already in App Store Connect fails as a duplicate.
5. Revoke the old key in App Store Connect.
6. Update the table above.

## 7. Manual fallback: archive in Xcode

Use this only when CI cannot upload a build you need now: the runner image
has dropped the pinned Xcode (`XCODE_APP` in the workflow), GitHub Actions is
down, or cloud signing fails. Fix the workflow afterwards; the manual path has
none of CI's checks on backend, build number or entitlements.

It signs with the Apple ID signed in to Xcode (Settings → Accounts), not with
the CI key, so it needs no secret on your machine.

1. Start from a clean, up-to-date `main`:
   ```bash
   git switch main && git pull
   ```
2. Regenerate the project with the manual suffix, so the build number is
   `N.2` and cannot collide with CI's `N` or `N.1` for the same commit:
   ```bash
   scripts/regen-xcodeproj.sh 2
   ```
   Never a bare `xcodegen generate` ([section 4](#4-build-numbers)).
3. Open `ios/TraysSocial/TraysSocial.xcodeproj` and pick the scheme: `TraysSocial
   Beta` for a TestFlight build against review, `TraysSocial` for an App Store
   build against prod. Check Product → Scheme → Edit Scheme → Archive → Build
   Configuration reads Beta or Release to match
   ([section 5](#5-which-scheme-talks-to-which-backend)).
4. Destination "Any iOS Device (arm64)", then Product → Archive.
5. In the Organizer: Distribute App → **App Store Connect** (not Internal
   Distribution) → Upload. If Xcode offers to manage the version and build
   number, turn it off, so the uploaded number stays `N.2`.
6. Wait for App Store Connect to process the build. For an App Store build,
   attach it to the version and submit for review by hand, as in
   [section 3](#3-release-builds-app-store).
7. Discard the regenerated project rather than committing a suffixed build
   number; CI regenerates it on every run and never reads the committed
   value:
   ```bash
   git checkout -- ios/TraysSocial/TraysSocial.xcodeproj
   ```

The command-line equivalent of steps 3 to 5 is the workflow's own archive and
export steps (`xcodebuild archive` then `xcodebuild -exportArchive` with
`ios/TraysSocial/ExportOptions-AppStore.plist`), run without the
`-authenticationKey*` flags so Xcode uses the signed-in account.

### What this replaces

Before W234 every TestFlight and App Store build was a manual Xcode Archive +
Upload: regenerate with `scripts/regen-xcodeproj.sh` (which already took the
build number from the commit count), check the scheme's Archive
configuration by hand, archive, upload from the Organizer, and restore the
regenerated build number in the committed `.xcodeproj` by hand. That routine
is retired: Beta uploads happen on every iOS push to `main`, Release uploads
are a dispatch plus an approval, and section 7 above is now only a fallback.
The "iOS-only feature" and "Cross-stack feature" flows in
`APP_STORE_LAUNCH_TODO.md` point here.
