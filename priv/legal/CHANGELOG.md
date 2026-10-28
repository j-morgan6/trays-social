# Legal documents changelog

Tracks material changes to the Privacy Policy, Terms of Service,
Community Guidelines, and FAQ. Effective dates in the corresponding
`priv/legal/*.md` frontmatter must match the latest entry below for
each document.

**Convention:** entries scoped to a single document are prefixed with
the document name (e.g. `## Community Guidelines v1.0 — …`). Entries
that span multiple documents are unprefixed and the body lists which
documents changed.

## FAQ v1.2 — 2026-10-28

FAQ only. Privacy Policy unchanged at v1.2, Terms of Service unchanged at
v1.2, Community Guidelines unchanged at v1.0.

- Trays Plus is not on sale yet (it ships in a later iOS release), so the
  FAQ no longer reads as if it can be bought today (W211)
- "What does Trays Plus cost?": removed the US$3.99/month and US$29.99/year
  prices and the 7-day trial; the answer now says Plus is not available to buy
  yet and that the App Store shows the price before purchase. The price
  returns when Plus launches
- "Is it free?", "Do you have ads?" and "What is Trays Plus?": Plus is
  described as coming in a future update rather than as a current subscription
- "How do I restore a purchase?" and "How do I cancel Trays Plus?": prefixed
  with "Once Trays Plus is available"; the steps are unchanged
- Terms of Service §17 is unchanged and still describes the subscription terms
  that will apply at launch

## Terms of Service v1.2 — 2026-09-04

Terms of Service only. Privacy Policy unchanged at v1.2, Community Guidelines
unchanged at v1.0, FAQ unchanged at v1.1.

**DRAFT PENDING LEGAL REVIEW** — the new section was drafted against primary
sources by an agent, not by a lawyer. The sources checked, the regulatory
context, and four open questions for a reviewer are in
`docs/legal/w183-subscriptions-billing-review.md`.

- Added §17 "Trays Plus subscriptions and billing" (17.1-17.9): what Plus is
  and that it gates utility rather than recipe content; the two plans and
  their prices, with the App Store's displayed local price stated as the
  price that governs; auto-renewal and Apple's billing timing; the 7-day free
  trial and its conversion; cancellation through Apple's subscription
  settings, with an explicit statement that the Trays app cannot cancel or
  modify a subscription; what survives when a subscription lapses; refunds
  being Apple's to handle, without limiting non-waivable provincial or state
  consumer rights; price and feature-change notice; and the Canada + US
  territory limit
- Renumbered "Changes to these Terms" §17 -> §18 and "Contact" §18 -> §19.
  Nothing renumbered below §17 — §5, §6, §7 and §8 are cross-referenced from
  the Community Guidelines and from within the Terms, and the Apple addendum
  stays at §16
- Before this change the only payment-related wording in the entire document
  was Apple's warranty-refund boilerplate at §16.4

## FAQ v1.1 — 2026-09-04

FAQ only. Privacy Policy unchanged at v1.2, Terms of Service unchanged at
v1.1, Community Guidelines unchanged at v1.0.

- "Is it free?": replaced "There are no payments, no subscriptions, and no
  in-app purchases" with an accurate answer — the app and its recipes stay
  free, and Trays Plus is an optional subscription on top
- "Do you have ads?": replaced "No. Trays has no advertising" with a
  description of clearly labeled sponsored placements, where they can and
  cannot appear, and the fact that they never reorder the feed. This answer
  had contradicted the shipped Privacy Policy v1.2 (which has described
  advertising and the `/privacy/ads-choices` opt-out since 2026-07-23)
- Added "What is Trays Plus?" (custom collections, weekly meal planner,
  automatic grocery list, ad-free) with an explicit statement that Plus
  never gates recipe content
- Added "What does Trays Plus cost?" — US$3.99/month, US$29.99/year, 7-day
  free trial, with the App Store's displayed local-currency price as the
  binding one
- Added "How do I restore a purchase?" and "How do I cancel Trays Plus?",
  the latter directing cancellation to Apple's subscription settings rather
  than implying an in-app cancel control, and describing what survives when
  a subscription lapses
- "How do I delete my account?": noted that deleting an account does not
  cancel a subscription

## Privacy Policy v1.2 — 2026-07-23

Privacy Policy only. Terms of Service unchanged at v1.1, Community Guidelines unchanged at v1.0.

- §11 California / Do-Not-Sell section: replaced the "no-op, nothing to opt
  out of" phrasing with the functional preference control now available at
  `/privacy/ads-choices` (first-party opt-out cookie honored by the website)
  and the automatically honored Global Privacy Control browser signal; the
  no-sale / no-sharing statements are unchanged and remain true
- §14 Cookies: appended a disclosure of the single first-party preference
  cookie `trays_ads_opt_out` (no identifier, not used for tracking, set only
  if the user opts out); the "We do not set advertising or analytics
  cookies" statement is unchanged
- §14: added an "Advertising on the trays.app website" subsection — clearly
  labeled sponsored placements on public recipe pages are first-party house
  content today, with no third-party ad partners and no ad tracking; any
  future third-party partner requires a policy update first, and the opt-out
  and GPC handling will apply to it

## Privacy Policy v1.1 — 2026-05-29

Privacy Policy only. Terms of Service unchanged at v1.1, Community Guidelines unchanged at v1.0.

- Resolved the pending GDPR Article 27 representative placeholder by stating
  the actual launch territory: Trays is offered only in Canada and the United
  States and does not target EU/EEA/UK residents, so no Article 27
  representative is required (App Store availability restricted to CA + US).
  - §1: added the Canada + US territory statement
  - §17: replaced the `[EU REP — TBD]` placeholders with the territory-based
    explanation; if availability expands to the EU/EEA/UK, a representative
    will be appointed before launching there

## Community Guidelines v1.0 — 2026-05-25

Initial publication.

- Standalone Community Guidelines page at `/community-guidelines`
  (W110, sibling to /privacy and /terms)
- Plain-language expansion of Terms of Service §5 acceptable-use rules
  with food-specific examples (allergen disclosure, cultural attribution,
  diet-style coexistence)
- Linked from iOS Settings → Legal section alongside Privacy and Terms

## v1.1 — 2026-05-11

Terms of Service only. Privacy Policy unchanged at v1.0.

- Terms of Service v1.1: DMCA designated agent filled in (USCO #DMCA-1072608)
  - §7 placeholders replaced with registered agent name, organization,
    address, email, and phone
  - Removed operator note about pending registration

## v1.0 — 2026-05-07

Initial publication.

- Privacy Policy v1.0
- Terms of Service v1.0
- Apple Schedule 1 (TOS §16) included for App Store distribution
- Binding individual arbitration with Quebec / EU / UK carve-outs (TOS §15)
- DMCA takedown procedure (TOS §7) — designated agent placeholders pending
  registration at dmca.copyright.gov
- GDPR Article 27 representative — placeholder pending appointment
