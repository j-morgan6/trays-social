# App Store Connect — Privacy Nutrition Labels checklist

This is the source of truth for what gets entered into App Store Connect's
**App Privacy** section. Every change to actual data collection in the app or
backend MUST be reflected here AND in `priv/legal/privacy.md` so the App Store
listing matches the policy.

App Tracking question: **No** (no cross-app tracking — no ATT prompt)
Age rating: **13+**

## Data declared

| Category | Sub-category | Linked to user? | Used for tracking? | Notes |
|---|---|---|---|---|
| Contact Info | Email Address | Yes | No | Sign-in identifier and transactional notifications |
| Contact Info | Name | Yes | No | Sign in with Apple requests the full name; the iOS app sends the given name, lowercased, as the suggested username, which the server stores as the username if it passes validation; no name field exists |
| User Content | Photos or Videos | Yes | No | User-uploaded recipe photos |
| User Content | Other User Content | Yes | No | Posts, comments, recipes |
| User Content | Customer Support | Yes | No | In-app feedback (subject, body, app/OS version, device model) posted to `/api/v1/feedback` and stored with the user |
| Identifiers | User ID | Yes | No | Internal Trays user ID + Apple `sub` claim from Sign in with Apple — declared once under "User ID" |
| Identifiers | Device ID | Yes | No | APNs token only — used for push delivery, never for cross-app tracking |
| Usage Data | Product Interaction | Yes | No | Recipe opens (`POST /api/v1/posts/:id/open`, stored in `recipe_opens`) power Home's "Jump back in" (W189); no analytics events |
| Diagnostics | Crash Data | Yes | No | MetricKit diagnostic payloads posted to `/api/v1/ios_diagnostics`, stored with the signed-in user's ID (W117) |
| Diagnostics | Performance Data | Yes | No | MetricKit metric payloads via the same endpoint, stored with the user's ID; plus server-side latency / availability metrics |

All ten types are declared for the purpose **App Functionality** only.

## iOS privacy manifest

`ios/TraysSocial/TraysSocial/PrivacyInfo.xcprivacy` (W213, 1.1.0) declares the
same ten types in `NSPrivacyCollectedDataTypes`, with the same linked and
tracking answers, `NSPrivacyTracking` false, no tracking domains, and one
required-reason API: `UserDefaults` with reason `CA92.1`. `PrivacyManifestTests`
pins the bundled manifest to a hand-kept copy of the table above; it does not
read this file. When the table changes, update the manifest and the test's
`expectedCollectedTypes` in the same commit.
Purchase history is not declared yet; it arrives with the Plus release.
The 1.1.0 binary already contains the StoreKit code, so `FeatureFlags` keeps
`paid_tier` off in any build whose bundled manifest does not declare
`NSPrivacyCollectedDataTypePurchaseHistory`, whatever `FEATURES_PAID_TIER`
says. Turning the server flag on therefore cannot make an installed build's
declaration false; the Plus release adds the type to the manifest, which
lifts the guard.

`priv/legal/privacy.md` v1.3 (W215) describes all ten types. Retention, for
reading "Linked: Yes" on diagnostics: since D120, `ios_diagnostic_payloads.user_id`
is `on_delete: :delete_all` and `Accounts.delete_account/1` deletes the rows, so
diagnostics stay linked while the account exists and are deleted with it. There
is no age-based purge. Reports sent while signed out have no `user_id`. Section
10 of the policy says this.

## App Store Connect answer sheet (iOS 1.1.0)

Enter these under **App Store Connect > your app > App Privacy > Edit**, then
publish. Entering them is a manual step: nothing in this repo changes the live
label, so it is unchanged until someone does this. Do it before submitting 1.1.0.

"Do you or your third-party partners collect data from this app?" **Yes**.

On the data types screen select exactly the ten rows below and nothing else. For
each one, answer the same three questions the same way:

- Purpose: **App Functionality** only
- Linked to the user's identity: **Yes**
- Used for tracking: **No**

| # | Category | Data type | Linked | Tracking | Purpose | Manifest key (`NSPrivacyCollectedDataType...`) |
|---|---|---|---|---|---|---|
| 1 | Contact Info | Email Address | Yes | No | App Functionality | `NSPrivacyCollectedDataTypeEmailAddress` |
| 2 | Contact Info | Name | Yes | No | App Functionality | `NSPrivacyCollectedDataTypeName` |
| 3 | User Content | Photos or Videos | Yes | No | App Functionality | `NSPrivacyCollectedDataTypePhotosorVideos` |
| 4 | User Content | Other User Content | Yes | No | App Functionality | `NSPrivacyCollectedDataTypeOtherUserContent` |
| 5 | User Content | Customer Support | Yes | No | App Functionality | `NSPrivacyCollectedDataTypeCustomerSupport` |
| 6 | Identifiers | User ID | Yes | No | App Functionality | `NSPrivacyCollectedDataTypeUserID` |
| 7 | Identifiers | Device ID | Yes | No | App Functionality | `NSPrivacyCollectedDataTypeDeviceID` |
| 8 | Usage Data | Product Interaction | Yes | No | App Functionality | `NSPrivacyCollectedDataTypeProductInteraction` |
| 9 | Diagnostics | Crash Data | Yes | No | App Functionality | `NSPrivacyCollectedDataTypeCrashData` |
| 10 | Diagnostics | Performance Data | Yes | No | App Functionality | `NSPrivacyCollectedDataTypePerformanceData` |

Do not select **Purchases** or anything under **Financial Info** for 1.1.0: purchase
history arrives with the Plus release, with its manifest declaration. Do not select
the other Usage Data or Diagnostics types; see "Excluded" below.

The App Privacy Policy URL field should point at the `/privacy` page, which must
already show v1.3 when the label goes live.

## Excluded — explicitly considered and confirmed not collected

- Usage Data → analytics and advertising data (no analytics or ad SDKs; verified by `scripts/audit-no-tracking-sdks.sh`). Product Interaction is declared above for recipe opens only.
- Location (no `CoreLocation` import in the iOS app)
- Health & Fitness (no `HealthKit`)
- Financial Info (no payments)
- Browsing History / Search History (search queries are not stored server-side)
- Diagnostics → Other Diagnostic Data (the app sends only MetricKit crash and performance payloads). Server-side ErrorTracker records are disclosed in the policy (section 3); this sheet does not add a type for them

## When this changes

If the engineering team adds any new collection (analytics SDK, location, health, payments, etc.):

1. Update this file
2. Update `priv/legal/privacy.md` to match
3. Update App Store Connect's App Privacy section to match
4. Bump the policy version (`priv/legal/privacy.md` frontmatter `version`)
5. Add a CHANGELOG entry at `priv/legal/CHANGELOG.md`
