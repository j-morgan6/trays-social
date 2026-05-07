---
effective_date: 2026-05-07
version: 1.0
---

# Privacy Policy

## 1. Who we are and what this covers

Trays Social is a food-focused social platform where home cooks share photos of their food, document recipes (ingredients, steps, tools, cooking time), and follow other cooks. Trays Social is operated by **1001366752 Ontario Inc.** (Ontario, Canada). Contact: `support@trays.app`. This policy covers the iOS app, the trays.app website, and the API serving both.

## 2. Information you give us

We collect what you give us when using Trays:

- Email address (for sign-in and transactional notifications)
- Username
- Hashed password (we use bcrypt; we never see your plaintext password)
- Optional bio and profile photo
- Posts, photos, recipes, comments, reports you submit
- Blocking and muting choices

## 3. Information collected automatically

We log basic technical data needed to operate the service:

- IP address (for abuse prevention and request handling)
- Device type and OS version (for compatibility and bug triage)
- App version
- Server log timestamps
- Basic error events

We do not run third-party analytics, do not collect advertising IDs, and do not track you across other apps or websites.

## 4. Information from third parties — Sign in with Apple

Apple performs identity assertion when you sign in with Apple — Apple issues a signed JWT that we verify against Apple's public JWKs. Apple does not access your subsequent app data. Apple may return either your real email address or a private relay email (`*@privaterelay.appleid.com`) that forwards to your real address — that is your choice at sign-in. We treat the relay address the same as a regular email; it is the only address we have for you in that case. Apple-supplied data we store: your email (real or relay) and a stable Apple user ID (the `sub` claim).

## 5. How we use your information

Concrete examples:

- Operate the service (show your feed, store your recipes, deliver your comments to recipients)
- Authenticate you (compare your password against the stored bcrypt hash; verify your Sign in with Apple token)
- Send transactional email (confirmation links, password resets, magic-link login codes — never marketing)
- Enforce community rules (process reports, apply blocks, hide muted keywords)
- Prevent abuse (rate limit, IP-based abuse detection)
- Comply with law (respond to valid legal process)

**CASL (Canadian Anti-Spam Law) note:** we send transactional email only. We do not send marketing email. If marketing email is ever added to Trays, it will require an express opt-in.

## 6. Legal bases (for users in the EU/UK)

We rely on:

- **Performance of contract** — to operate the service for users who have agreed to the Terms of Service.
- **Legitimate interests** — to keep the service secure and prevent abuse (Article 6(1)(f) GDPR).
- **Consent** — where required (e.g., specific feature opt-ins).
- **Legal obligation** — when laws require us to retain or disclose information.

## 7. What's public, what's not

Posts, recipes, comments, profiles (username + bio + profile photo), and follow graphs (your followers and the accounts you follow) are public-by-default. There are no private accounts at this time. Public content is also accessible via the trays.app website at routes like `/explore` and `/@username`, which means **search engines can index your username, profile, and posts**. Email addresses, IP addresses, and server logs are never shown to other users.

## 8. Service providers (sub-processors)

| Provider | Role | Where data flows | Location |
|---|---|---|---|
| Fly.io | Compute and Postgres database | Account data, posts, comments, IP for request handling | Toronto, Canada (yyz region) |
| Tigris Data | Object storage for photos | Photos served at `https://trays-social-uploads.fly.storage.tigris.dev/...` | Distributed globally |
| Resend | Transactional email | Recipient email and email body | United States |
| Apple | Sign in with Apple | Identity assertion only; we receive `sub` claim and email | Global |

## 9. International data transfers

Tigris and Resend may move your data outside Canada (United States and other regions). We rely on Standard Contractual Clauses or equivalent safeguards for these transfers.

## 10. Data retention

- Active account data: kept while your account is active
- Account deletion: honored within 30 days of request
- Backups: purged within 90 days
- Server logs: rotated within 30 days

## 11. Your rights

Depending on where you live, you have specific rights over your data:

**Everyone:** access, correct, or delete your data. Email `support@trays.app` to exercise these rights. We will respond within 30 days. You can also delete your account directly in the iOS app's Settings.

**EU and UK users (GDPR):** right of access, rectification, erasure, portability (delivered as a single JSON file containing your user record plus your posts, comments, and photo URLs — machine-readable per Article 20), restriction, objection, and the right to lodge a complaint with your supervisory authority.

**California residents (CCPA / CPRA):** right to know, delete, and correct. **We do not sell your personal information** and **we do not share it for cross-context behavioral advertising**. The "[Do Not Sell or Share My Personal Information](#california-do-not-sell)" link below is required by CCPA — it is a no-op for us because there is nothing to opt out of, but it is here for transparency. You may use an authorized agent. **We do not collect Sensitive Personal Information as defined by CCPA/CPRA** (no precise geolocation, government IDs, financial account data, racial or ethnic origin, religious beliefs, biometric data, health data, sexual orientation data, or contents of mail, email, or text messages).

<a id="california-do-not-sell"></a>

### California — Do Not Sell or Share My Personal Information

Trays does not sell or share your personal information for cross-context behavioral advertising. Nothing for you to opt out of.

**Quebec residents (Law 25):** privacy officer contact (the sole Director of 1001366752 Ontario Inc., reachable via `support@trays.app`), automated decisions disclosure (we do not make automated decisions about you), and portability (same JSON format as GDPR).

**Canadian users (PIPEDA):** the right to challenge accuracy and the right to complain to the Office of the Privacy Commissioner of Canada.

## 12. Children under 13

The service is not directed at children under 13 and we do not knowingly collect data from them. If a parent or guardian discovers a child has used Trays without authorization, they may contact `support@trays.app` and we will delete the account.

## 13. Security

We hash passwords with bcrypt, transport everything over TLS, and rate-limit endpoints to prevent abuse. No system is perfectly secure — if you believe your account was compromised, contact us immediately.

## 14. Cookies and similar technologies

The trays.app website sets a session cookie when you log in. We do not set advertising or analytics cookies.

## 15. Push notifications

Trays may send push notifications via Apple's Push Notification service (APNs) for events like likes, comments, and follows once enabled. You can disable notifications at any time in iOS Settings.

## 16. Changes to this policy

If we make material changes, we will notify you via in-app notice and/or email. Non-material changes are reflected by an updated effective date at the top of this page.

## 17. Contact

- General privacy questions: `support@trays.app`
- Mailing address: available on written request to `support@trays.app`
- Quebec residents: contact our privacy officer (the sole Director of 1001366752 Ontario Inc.) via `support@trays.app`
- **EU and UK users (GDPR Article 27 representative):** `[EU REP NAME — TBD]`, `[EU REP ADDRESS — TBD]`, `[EU REP EMAIL — TBD]`. *(Operator action: appoint via Prighter / DataGuidance / EuRep before policy ships, or geofence EU traffic at the Phoenix layer.)*
