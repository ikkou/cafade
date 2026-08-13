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

The iOS source lives under `app/`. The app is generated from `app/project.yml` with XcodeGen.
The catalog and calculation layers are kept separate from SwiftUI screens so US and future market data can be added without changing the model or paywall flow.

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

The planned RevenueCat configuration is:

```text
Offering: default
Entitlement: pro
Packages: monthly, yearly
```

Secret RevenueCat credentials and Apple private keys must never be committed to this repository.

For local purchase configuration, create `app/Config/RevenueCat.local.xcconfig` and add:

```text
REVENUECAT_API_KEY = your_public_sdk_key
```

The local file is ignored by Git. The app remains usable without it; purchase and restore become active after the RevenueCat offering is connected.
