# W183 — Terms of Service section 17 (Trays Plus subscriptions and billing)

## STATUS: DRAFT REQUIRING HUMAN / LEGAL REVIEW

This memo accompanies the new section 17 added to `priv/legal/terms.md` in
v1.2. **The section was drafted by an agent, not by a lawyer.** It is written
to be accurate against primary sources checked on 2026-09-04, but the four
open questions in the last part of this memo are judgment calls that need a
Canadian/US consumer-law practitioner, not an engineer and not an agent.

Nothing here is legal advice.

---

## 1. What section 17 asserts, and the source for each assertion

| Assertion in section 17 | Source actually checked (2026-09-04) |
|---|---|
| Subscription period must be at least 7 days and work across all the user's devices; the app must provide ongoing value | Apple App Store Review Guidelines 3.1.2(a), read in full at <https://developer.apple.com/app-store/review/guidelines/> |
| Before asking a customer to subscribe, the app must clearly describe what the user gets for the price, and must meet Schedule 2 of the Apple Developer Program License Agreement | Apple App Store Review Guidelines 3.1.2(c), same page. 3.1.2(c) does **not** itself enumerate the disclosure list — it delegates to Schedule 2. |
| Sign-up screen must show subscription name and duration, the content or services provided, the full renewal price shown prominently and localized, and a way for existing subscribers to sign in or restore purchases; app and App Store metadata must link Terms of Use and Privacy Policy; free trials must state their length and the price billed afterwards | Apple, "Auto-renewable subscriptions", <https://developer.apple.com/app-store/subscriptions/> |
| Subscriptions auto-renew until cancelled in Manage Subscriptions; the payment method is charged no more than 24 hours before the start of each new subscription period | Apple Media Services Terms and Conditions (US), <https://www.apple.com/legal/internet-services/itunes/us/terms.html> |
| A free trial must be cancelled at least 24 hours before it ends to avoid being charged | Apple Support, "Cancel a subscription from Apple", <https://support.apple.com/en-us/118428> — Apple states this deadline explicitly for **free or discounted trials**. See open question 1. |
| Cancellation happens in Apple's subscription settings (device Settings > name > Subscriptions, or account.apple.com); the developer cannot cancel on the user's behalf | Apple Support, same page |
| Refunds for App Store purchases are handled by Apple, via reportaproblem.apple.com | Apple Media Services Terms and Conditions (US), same page |

## 2. Regulatory context that shaped the drafting (checked, not asserted in the document)

**California Automatic Renewal Law, as amended by AB 2863 — in force since
1 July 2025.** Applies to contracts entered into, amended, or extended on or
after that date. Key amendments: express affirmative consent to the
auto-renewal terms must be obtained and records of it retained for at least
three years (or one year after termination, whichever is longer); annual
reminders; clear and conspicuous notice of material price and service
changes; and "click to quit" — the consumer must be able to cancel through
the same medium they used to subscribe. Scope was expanded to cover free
trials and free-to-paid conversions.
Sources: <https://www.cooley.com/news/insight/2025/2025-06-04-california-automatic-renewal-law-amendments-take-effect-on-july-1-2025>,
<https://www.wsgr.com/en/insights/california-amends-automatic-renewal-law-again.html>,
bill text at <https://leginfo.legislature.ca.gov/faces/billTextClient.xhtml?bill_id=202320240AB2863>

**FTC Negative Option Rule ("click-to-cancel") — NOT in force.** The Eighth
Circuit vacated the rule in its entirety on 8 July 2025 on Magnuson-Moss
procedural grounds. The FTC issued an advance notice of proposed rulemaking
on 11 March 2026 restarting the effort, with comments due 13 April 2026; no
replacement rule is in effect. The FTC continues to bring negative-option
cases under Section 5 of the FTC Act and under ROSCA.
**Consequence for us: do not cite the click-to-cancel rule as a binding
requirement.** Section 17 does not.
Sources: <https://www.lw.com/en/insights/eighth-circuit-vacates-ftc-click-to-cancel-rule>,
<https://www.gibsondunn.com/ftc-restarts-negative-option-rulemaking-after-eighth-circuit-vacatur-enforcement-under-rosca-continues/>

**Ontario Consumer Protection Act, 2023 (Bill 142) — NOT yet in force.**
Royal Assent 6 December 2023; still awaiting proclamation and the supporting
regulations as of September 2026. When it does come into force it is expected
to require an active step by the consumer to accept a renewal or extension,
and a continuing right to cancel rather than a single closing window;
secondary commentary describes a written pre-renewal notice window of 30 to
90 days for automatically renewing contracts. **This matters directly: the
seller here is 1001366752 Ontario Inc.** Section 17 was drafted so that it
does not contradict these requirements, but it does not attempt to satisfy
them, because they are not yet law and the regulations that will define them
do not exist yet.
Sources: <https://www.osler.com/en/insights/updates/automatic-renewals-in-canadian-consumer-protection-law/>,
<https://www.blakes.com/insights/modernizing-consumer-protection-laws-in-ontario-the-new-consumer-protection-act-2023/>,
<https://www.ola.org/en/legislative-business/bills/parliament-43/session-1/bill-142>

## 3. Open questions for the reviewer

1. **The 24-hour cancellation deadline for ordinary renewals.** Apple states
   the 24-hour deadline explicitly for free and discounted **trials**, and
   separately says the payment method is charged no more than 24 hours before
   a new period starts. Section 17.3 states the deadline for ordinary renewals
   too, which follows from the billing timing and is the standard industry
   phrasing, but it is an inference rather than a quoted Apple rule. Confirm
   the wording you want.

2. **California "click to quit" versus Apple-only cancellation.** The amended
   ARL requires cancellation through the same medium used to subscribe. The
   user subscribes through Apple's purchase sheet and cancels through Apple's
   subscription settings, which is arguably the same medium — but we do not
   provide any in-app cancel control, and section 17.5 says so plainly. Does
   that position hold for a California subscriber, and does anything change
   if we add an in-app deep link to Apple's management sheet (StoreKit
   provides `showManageSubscriptions(in:)`)?

3. **Affirmative-consent record retention.** The ARL requires keeping proof
   of the consumer's express affirmative consent to the auto-renewal terms
   for at least three years. Today the backend stores only `is_subscriber`
   and `apple_original_transaction_id` on the user record — it does not store
   a consent record, the plan purchased, or the terms version displayed at
   purchase. If a consent record is required of us rather than of Apple, that
   is an engineering change, not a Terms change.

4. **Ontario CPA 2023 readiness.** Once proclaimed, does an App Store
   auto-renewing subscription sold by an Ontario corporation need the
   pre-renewal notice and active-acceptance step, given that Apple, not us,
   controls the renewal and the billing relationship? If yes, we need a plan,
   because we cannot send Apple's renewal notice for it.

## 4. Known gap outside this task's scope

**The Privacy Policy says nothing about subscriptions.** `priv/legal/privacy.md`
v1.2 contains no mention of payment, billing, subscription, or purchase data.
The backend does store two subscription-related fields on the user record
(`is_subscriber` and `apple_original_transaction_id`, set only from an
Apple-signed transaction). Section 17.3 describes this accurately, but the
Privacy Policy's collection inventory does not list it. That is a Privacy
Policy amendment, not a Terms amendment, and it was deliberately left out of
W183. It should be filed and done before Plus is sold.
