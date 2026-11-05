# Google restaurant reviews — published

Activated 13 October 2026 for native app **0.12.0 (27)**.

## Implemented

The restaurant Overview and Reviews tabs open a dedicated in-app Google reviews page. A hosted Google Places UI Kit component runs in WKWebView, compatible with the project's existing Xcode 15.2 toolchain. It searches by the restaurant's name/address and location. The visitor selects the correct Google listing; only its Place ID and confirmation date are remembered on that phone for up to 180 days. Changes to the restaurant identity/address/coordinates invalidate the match. The menu can clear a mistaken match. Reviews, ratings, photos and author data stay in Google's official component and are not copied to Supabase or included in the app's average.

Google requests start only after opening this page. There is no polling, automatic first-result selection, or automatic retry. Errors, empty results, timeouts and disabled configuration have distinct UI. The component never receives the Supabase session, password, email or user's live GPS location.

## Verified Google setup

Project: `burgas-eurovision-2027`.
The authenticated Console showed **Maps JavaScript API** and **Places UI Kit** enabled, a free trial active, and an existing credential named **Maps Platform API Key**. The user explicitly approved public component activation and using that key. Its restrictions were saved and verified: only the exact component HTTPS origin and the two services **Maps JavaScript API** / **Places UI Kit**. The restricted browser key was read through the authenticated Console and saved to `GoogleReviewsWidget/dist/config.json` without displaying its value in chat. Live verification made Google search/detail requests; subsequent visitors use this same Google project's allowance. Billing was not upgraded.

## Hosted component

Source: `../GoogleReviewsWidget/`; deploy only `dist/`.
Sites project: `appgprj_6acc784b7f5c8191a1e868634a362cef`.
Public origin: `https://burgas-restaurant-google-reviews.v7d7fqybzr.chatgpt.site`.
The Site is **published with public access**. Current version 2 was saved from pushed commit `70dec440c05c1b5833152cc78a6935d02645ebd4`; deployment `appgdep_6acdcdef91288191bbf8f615ef8f870d` succeeded. Its static archive hash is identical to the live-tested version 1; only the source README was updated. Reuse this Site ID on future updates; do not create another project. The earlier approval block was resolved after the user's permission change. A temporary hosting upload 503 also recovered on retry.

`GoogleReviewsWidgetURL` in `FindMyToilet/Info.plist` is now set to the public HTTPS origin. The original web app and the original iOS backup remain separate and unchanged.

## Verification and use

- Live browser verification: searched for Ореха at Алеко Богориди 51, selected the matching Google listing, and opened Google's Отзиви tab. Real review text, stars, reviewer identity/date and Google's attribution were visible. Screenshot: `../../work/google-reviews-live.jpg`.
- The first search hit a Google RPC network error; the manual retry recovered and loaded the correct result. The error/retry UI was exercised without changing the key or billing. An optional Google photo request also failed; the review text remained available.
- 66 native regression checks, full iOS source type checking and nine mocked Google component checks passed during implementation. Empty/no-review and stale-result handling have automated coverage, not separate live catalogue verification.
- The live browser viewport override did not take effect (the DOM stayed at 1280 px); do not claim a completed live iPhone-width layout check. Actual iPhone/WKWebView display, stored-match behavior across launches and external author/source links still need a device check. Current Xcode build status is recorded in `../TESTING.md`.
- Install build 0.12.0 (27), open a restaurant → Ревюта от Google → choose the correct address → Отзиви. Opening it again should reuse the confirmed Place ID. Use Избери друго съвпадение to correct it.
- Keep the key restricted to this exact origin and the two APIs. It is a browser key, visible to visitors by design; never replace it with a service-account credential, server secret, or Supabase service-role key. No new Supabase SQL is required.

## Why the official component

For new EEA integrations, Google's Places content restrictions cover content linked with a map. Google identifies Places UI Kit as supporting use with any map; the existing Apple Maps screens can remain. The current native Places Swift SDK setup requires a newer Xcode, so this implementation embeds the official JavaScript UI Kit rather than adding an incompatible native dependency.

Sources: [EEA guidance](https://developers.google.com/maps/comms/eea/places), [UI Kit setup](https://developers.google.com/maps/documentation/javascript/places-ui-kit/get-started), [place search](https://developers.google.com/maps/documentation/javascript/places-ui-kit/place-search), [place details](https://developers.google.com/maps/documentation/javascript/places-ui-kit/place-details), [iOS SDK setup](https://developers.google.com/maps/documentation/places/ios-sdk/config).
