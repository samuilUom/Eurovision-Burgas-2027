# Restaurant reviews and shared photos — 0.11.0 (25)

## If the app shows a Wi-Fi warning while online

The original 0.11.0 warning also covered server setup errors. Direct checks on 7 October reached the server but returned PGRST202 (missing community function) and PGRST205 (missing tables). Version 0.11.1 (26) reports the cause separately.

If the SQL editor says “Restaurant community ready” but the app still fails, run **all of `check-restaurant-community.sql`** in project `shodinaimhixnudqqgck`. It refreshes the API schema cache and returns three existence checks. All should be `true`. A `false` means the full migration is still needed; the final success-message SELECT alone does not create anything. Apply the whole migration, including BEGIN and COMMIT, with no partial selection. Then tap Retry in the app. This backend activation also works for the installed 0.11.0 app without rebuilding.

## Enable it in Supabase

1. Open `Backend/restaurant-community.sql` and copy the entire file (Command+A, Command+C).
2. In the existing Supabase project, create a **new SQL query**, paste it and press **Run**.
3. The last result should say **Restaurant community ready**.
4. Run the **FindMyToilet** scheme in Xcode to install version **0.11.0 (25)**. Open a restaurant, then Reviews or Photos.

The script requires the existing category-place tables; those are already present in your live project. It adds restaurant tables, permissions and functions. It preserves existing restaurants, toilets, accounts, reviews and favorites. It can be run again safely. Supabase may display its destructive-operation warning because the script replaces only this feature's policies/triggers; it does not delete existing user data or tables.

**Status, 7 October 2026:** the shared project contains **76 restaurants**, and their optional hours column is available. The user applied the restaurant community setup and confirmed all three database existence checks. After the schema refresh, live anonymous reads returned **HTTP 200** for `restaurant_community`, including **Ореха**. The missing endpoint error is resolved; tap Retry in the installed app. Authenticated cross-phone uploads/reviews still need an on-device check. Dashboard control remained unavailable, so the user performed SQL execution. No secret keys were used.

## What changed

Restaurants now have a large photo header, title and star rating, directions/saved/website actions, Overview / Reviews / Photos tabs, opening hours, and an interactive neighborhood map. Toilet and other category detail screens retain their existing behavior.

Anyone can read restaurant reviews and browse photos. A signed-in visitor can publish one 1–5-star review per restaurant, edit or delete it, and upload up to 10 photos independently of the review. Review cards have a text preview; tapping opens the full review. Photos open on a normal page with uploader name, date and caption. Author names open existing public profiles. Restaurant contributions are shown on their restaurant page; existing profile review counters/collections still cover toilet reviews.

Photos/reviews are shared using the existing Supabase database. Reopening the page, pulling down to refresh, choosing Refresh or returning to the foreground fetches other visitors' contributions. There is no continuous realtime subscription. These are app-community contributions; no Google reviews, ratings or images are imported.

Apple Maps-only results can be added to the community with one explicit button. Registration reuses a nearby restaurant with the same normalized name and serializes simultaneous requests, so two phones do not create separate threads for the same matching result. Differently spelled names can still require administrator cleanup.

## Data and permissions

- `restaurant_reviews`: one row per restaurant/author, 1–5 stars, up to 2,000 Unicode scalars, server timestamp. Only the owner edits; owner/admin can delete.
- `restaurant_photos`: immutable attributed photo rows. Owner/admin can delete. Maximum 10 per author per restaurant, including protection against simultaneous uploads.
- Row-level security permits public reading and signed-in owner writes. Column grants prevent changing authors/place IDs/timestamps. Functions run as the caller and retain those permissions.
- The feed returns 20 reviews and 20 thumbnails per page, with average/count calculated over **all** reviews. Own review is returned separately, even if it is older than the first page. Stable ordering and client deduplication support paging; pull-to-refresh obtains a fresh page after concurrent changes.
- Uploads become JPEGs, at most 1,280 pixels / 500,000 bytes; thumbnails at most 500 pixels / 65,000 bytes. Re-encoding strips original EXIF/GPS metadata. Full photos are fetched only after opening a photo, never during app startup.
- Bounded base64 data uses the existing database approach; it consumes database storage. A larger public rollout should move photo binaries to object storage and add broader abuse controls.
- Deleting a restaurant/account also deletes its dependent restaurant contributions. This migration itself performs no data deletion.

## Verification

53 Swift regression tests and full-source iOS 17 type checking passed. Thirteen new tests cover rating validation, ownership decisions, date formats, true aggregate use, paginated deduplication, failed requests/retry, canceled and obsolete account responses, own reviews outside the first page, and bounded image conversion/metadata removal.

34 isolated PostgreSQL integration checks passed using PGlite 0.5.8 with production base migrations, roles and RLS. They cover repeatable setup, canonical registration, public reading, owner-only writes, admin moderation, invalid text/images, quota/idempotent upload retries, full aggregates, paging and cascades. The test script is `Backend/tests/restaurant-community.mjs`; run it with Node and `@electric-sql/pglite` available. It creates an in-memory test database and never connects to Supabase.

A full simulator build was attempted but stopped during asset/storyboard packaging because Xcode could not connect to CoreSimulatorService or locate a simulator runtime. Phone layout and live cross-phone sharing still need checking after the SQL setup and installation.

On two phones: sign in as different users; open the same restaurant; publish different ratings; pull to refresh and confirm both reviews/average; edit one review without increasing the count; upload/open a photo and confirm its author; confirm that ordinary users cannot delete each other's content. Also check guest access, offline retry, switching accounts, large text, light/dark appearance, and returning from the in-app route.

Implementation references: [Supabase database functions](https://supabase.com/docs/guides/database/functions) and [row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security).
