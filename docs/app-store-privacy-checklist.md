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
| User Content | Photos or Videos | Yes | No | User-uploaded recipe photos |
| User Content | Other User Content | Yes | No | Posts, comments, recipes |
| Identifiers | User ID | Yes | No | Internal Trays user ID + Apple `sub` claim from Sign in with Apple — declared once under "User ID" |
| Identifiers | Device ID | Yes | No | APNs token only — used for push delivery, never for cross-app tracking |
| Diagnostics | Crash Data | No | No | Apple's standard crash reporting via Xcode Organizer |
| Diagnostics | Performance Data | No | No | Server-side latency / availability metrics |

## Excluded — explicitly considered and confirmed not collected

- Usage Data → Product Interaction (no analytics events anywhere; verified by `scripts/audit-no-tracking-sdks.sh`)
- Location (no `CoreLocation` import in the iOS app)
- Health & Fitness (no `HealthKit`)
- Financial Info (no payments)
- Browsing History / Search History (search queries are not stored server-side)

## When this changes

If the engineering team adds any new collection (analytics SDK, location, health, payments, etc.):

1. Update this file
2. Update `priv/legal/privacy.md` to match
3. Update App Store Connect's App Privacy section to match
4. Bump the policy version (`priv/legal/privacy.md` frontmatter `version`)
5. Add a CHANGELOG entry at `priv/legal/CHANGELOG.md`
