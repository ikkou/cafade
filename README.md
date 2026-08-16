# Cafade

Cafade is a calm caffeine tracker for iPhone.

It helps people log coffee, tea, soda, energy drinks, and custom entries, then see an estimate of how much caffeine remains over time.

The product promise is:

> Know what you drank. See what remains.

## Repository layout

- `PRODUCT_SPEC_v0.1.md`: product and release specification.
- `site/`: dependency-free public website for Cafade.
- `site/support/`: support information.
- `site/privacy/`: privacy policy.
- `site/terms/`: app terms and Apple subscription links.
- `app/Cafade/Resources/CaffeineCatalog.json`: versioned US drink catalog.
- `app/Cafade/Resources/PrivacyInfo.xcprivacy`: app privacy manifest.

The iOS source lives under `app/`. The app is generated from `app/project.yml` with XcodeGen.
The catalog and calculation layers are kept separate from SwiftUI screens so US and future market data can be added without changing the model or paywall flow.

Each active catalog item must include a stable identifier, market code,
verified caffeine value or range, source URL, and verification date. Add or
update products in the JSON file; do not hard-code product rows in SwiftUI.

## Local verification

Regenerate the Xcode project after changing `app/project.yml`:

```text
cd app
xcodegen generate
```

The `Cafade` scheme runs calculation/persistence tests and UI tests. The UI
suite verifies the Settings shortcut/tab state, the one-tap Suggested logging
path with Undo, access to the estimate explanation, and share-card saving to
Photos.

## Website

The public site is intended for Cloudflare Pages with the GitHub `main` branch as the production source.

```text
Root directory: repository root
Build command: none
Output directory: site
Production URL: https://cafade.oneshotstar.com
```

The site does not require a database, server-side runtime, analytics script, or account.

## Subscription

Cafade uses Apple in-app purchases with RevenueCat for purchase state, entitlements, offers, and restore-purchases handling.

The configured RevenueCat setup is:

```text
Offering: default
Entitlement: pro
Packages: monthly, yearly
```

The Apple App Store products are `cafade_pro_monthly` and
`cafade_pro_yearly`. The local build reads the public iOS SDK key from
`app/Config/RevenueCat.local.xcconfig`; the ignored file is intentionally not
part of the repository. Apple Sandbox/TestFlight purchase verification and
the App Store submission remain release checks rather than repository
configuration.

Secret RevenueCat credentials and Apple private keys must never be committed to this repository.

For local purchase configuration, create `app/Config/RevenueCat.local.xcconfig` and add:

```text
REVENUECAT_API_KEY = your_public_sdk_key
```

The local file is ignored by Git. The app remains usable without it; purchase
and restore become active after the RevenueCat offering is connected.

Loading plans in a development build does not complete commerce verification.
Purchase, cancellation, renewal, expiry, billing retry, and restore must still
be exercised with Apple Sandbox or TestFlight before submission.
