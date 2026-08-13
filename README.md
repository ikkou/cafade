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

The iOS source will be added to this repository under `app/` once the Xcode project is created.

## Website

The public site is intended for Cloudflare Pages with the GitHub `main` branch as the production source.

```text
Root directory: site
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
