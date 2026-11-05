# Embedded Google restaurant reviews

For a fresh Git checkout, copy `dist/config.example.json` to `dist/config.json` and configure your restricted Google browser key before publishing this component. The local `config.json` and hosting metadata are excluded from Git; the existing deployed component and the iPhone app's endpoint are unchanged.

This static component is displayed by the iPhone app in WKWebView. `dist/` is the publication root; no build is required. `config.json` has the user-approved Google browser key and `enabled: true`. The component is public at `https://burgas-restaurant-google-reviews.v7d7fqybzr.chatgpt.site/`, and native build 0.12.0 (27) uses that endpoint. Live search, explicit matching and Google review text were verified for Ореха. Only a Google browser key restricted to the exact published origin and the Maps JavaScript API / Places UI Kit services belongs here. The key is client-visible; no private/server credentials belong in this folder.

Activation status and reserved Sites identity: [../Backend/GOOGLE-REVIEWS.md](../Backend/GOOGLE-REVIEWS.md).

The app supplies `name`, `address`, `lat`, `lng`, and optionally a previously selected `place` ID in the URL fragment. No user location, login token, or email is sent. The page uses official Google search and detail elements and preserves their built-in attribution. It never assumes the first search result is the correct restaurant. The `restaurantReviews` WKWebView message handler accepts `ready`, `match` (only Place ID), and `clearMatch` from the configured origin; no review text or Google user data crosses that bridge.

Tests: install the development dependency and run `npm test` with a Node version supported by jsdom. These are DOM/event tests with Google stubbed, not live API tests. Run locally with a static HTTP server serving `dist/`; production requires HTTPS and a correctly restricted key. The full unsigned iPhone build passed. Actual WKWebView rendering, remembered matches and source/profile links still require an on-device check.
