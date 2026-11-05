# Eurovision Burgas 2027 — iPhone app, version 0.14.1

## Version 0.14.1 — dedicated petrol-station and EV-charging sections

Build **31** shows **Бензиностанции** and **Зарядни станции** as separate, directly visible categories on the start page, map and favourites. They retain their existing icons, discovery, details, directions, 24/7 badges and add/edit support. Здраве still groups hospitals and pharmacies. No further database change is required beyond the previously supplied fuel/charging SQL.

## Version 0.14.0 — stable health discovery, 24/7 pins, fuel and charging

Build **30** keeps just **Болници / Аптеки** in Здраве; regular and round-the-clock pharmacies are shown together. Known 24-hour schedules get a **24/7 map-pin badge**, also shown on the place's detail map. Names alone never supply this badge.

**Гориво и ток** is a new combined navigation slot with **Бензиностанции / Зарядни станции**, using Apple Maps discovery, existing place details, adding/editing, directions and favourites. Fuel/charging opening schedules can also supply a 24/7 badge. The app does not claim live charger availability or fuel prices.

Health/fuel discovery now makes one request per type instead of nine repeated district queries. Category/query/area caches keep results separate, refreshing retains visible pins until replacement, and stale requests cannot overwrite the selected type. Footer space remains stable while health types change.

**Manual database step:** run the entire [fuel-charging-categories.sql](Backend/fuel-charging-categories.sql) yourself to enable shared additions and synced favourites for the new types. It was prepared locally and has **not been applied**. Apple Maps browsing and directions do not require this SQL.

## Version 0.13.1 — one healthcare slot

**Здраве** combines hospitals and pharmacies in the start page, map category strip and favourites. Use **Болници / Аптеки / Аптеки 24/7 / Аптеки с график** inside this section. The existing place details, category-specific pins, directions and add/edit forms are retained. Stored hospital/pharmacy categories and favourite identities remain unchanged; **no new Supabase SQL is needed**. Build **29**.

## Version 0.13.0 — hospitals and pharmacies

Build **28** adds **Болници** and **Аптеки** using the existing map, cards, details, add/edit and favourites UI. Pharmacies distinguish 24/7, regular and unknown schedules, with an open-pharmacy nearest action. Three hospitals and two pharmacies are included as initial source-linked entries, alongside Apple Maps discovery. Shared category saving is enabled in Supabase. See [sources, database setup and verification](Backend/HEALTHCARE.md).

## Version 0.12.0 — in-app Google reviews

Restaurant pages now have a separate in-app Google reviews destination, backed by the official Google Places UI Kit. The visitor chooses the matching restaurant by name/address; that Place ID is remembered on the phone and can be changed. Google ratings remain separate from app-community ratings. **The component is published and the native endpoint is configured.** Live search, correct-address selection and Google review text were verified for Ореха. Install native build **0.12.0 (27)**, open a restaurant, choose **Ревюта от Google**, select the matching address, then open Google's **Отзиви** tab. No new Supabase migration is needed. See [Google setup and verification](Backend/GOOGLE-REVIEWS.md) for the remaining device checks.

## Version 0.11.1 — explain restaurant service errors correctly

The Wi-Fi warning was misleading: a direct request reached Supabase but returned **HTTP 404 / PGRST202**, indicating that `restaurant_community` is missing from the API schema. The new restaurant tables also returned PGRST205. The app now distinguishes missing setup, offline/timeout, expired login, denied access, rate limits, service errors and unreadable responses. Database setup errors show a setup notice instead of a Wi-Fi icon.

**Live setup is now verified:** after the database check/schema refresh, the API returned **HTTP 200** with the expected restaurant community response. The screenshot restaurant **Ореха** was checked successfully. Tap Retry in the installed app to load the shared review/photo sections. Build **0.11.1 (26)** adds the clearer error messages; activating sharing does not require installing it. The troubleshooting check remains available at [Backend/check-restaurant-community.sql](Backend/check-restaurant-community.sql).

**60 regression tests and full-source iOS type checking passed**, including the exact missing-function response and recovery after setup without restarting the app. Phone installation remains unverified because of the previously reported Xcode simulator issue.

## Version 0.11.0 — restaurant pages, shared reviews and photos

Restaurants now have a Maps-style page with a photo header, star ratings, Overview / Reviews / Photos tabs, quick directions/save/website actions, opening hours and an interactive map. Visitors can publish one editable star review per restaurant and upload photos independently. Review previews open the complete text; photos open a page with uploader/date/caption. Owners can remove their own contributions; admins can moderate them. Existing toilet screens are unchanged.

**One database step remains:** copy all of [Backend/restaurant-community.sql](Backend/restaurant-community.sql) into a new Supabase SQL query and run it. It preserves existing data. Then install build **0.11.0 (25)** through the existing **FindMyToilet** Xcode scheme. [Setup, behavior and verification](Backend/RESTAURANT-COMMUNITY.md).

On **7 October**, a read-only live check confirmed **76 restaurants** and the hours column. The user applied the restaurant community migration on 7 October; after a schema refresh, live API reads were verified successfully. Reopen/pull-to-refresh to see contributions from another phone.

**53 app tests, 34 local PostgreSQL checks and full iOS source type checking passed.** A full simulator build remains blocked by Xcode's CoreSimulator/runtime issue; device appearance and live cross-phone writes have not been verified. The original backup remains unchanged.

Earlier version notes follow.

## Restaurant catalogue — prepared 6 October 2026

[76 restaurant records and their sources](Backend/RESTAURANTS.md) are now prepared for permanent shared storage, with selected Google Maps cross-checks and corrected conflicting coordinates. Run [Backend/add-burgas-restaurants.sql](Backend/add-burgas-restaurants.sql) once in a new Supabase SQL query, then refresh Restaurants in the app. This includes the opening-hours setup and preserves existing records. The import was initially pending on 6 October; a read-only check on **7 October confirmed all 76 shared restaurant records**. No new native build is needed for this import on version 0.10.0. The directory is not claimed to include every restaurant.

## Version 0.10.0 — simpler discovery and more Burgas restaurants

The toilet filter buttons are removed. Cards show price and clearly labelled amenities instead. Discovery automatically includes places that are open or opening within 60 minutes, using Burgas local time. Known-closed places are hidden; unknown hours stay visible with an explicit label. Transport stops and saved favorites remain accessible independently of opening hours. Shops retain a single Nonstop discovery toggle.

Restaurants now search nine areas across Burgas, including outer districts, with progressive results, deduplication, a ten-minute in-memory cache, cancellation guards and partial-result retry. Searching after panning uses the selected area and does not recenter the map. Results come from Apple Maps and community contributions; this is not a complete restaurant import. Google integration is deferred as requested. Live Apple Maps requests failed on this Mac, so restaurant coverage still needs an iPhone check.

Community restaurants, ATMs and shops now support optional weekly hours, with a selected-day editor, 24-hour shortcuts, copying a day across the week and overnight/split periods. **One database step remains:** run [Backend/place-opening-hours.sql](Backend/place-opening-hours.sql) in a new Supabase SQL query. A read-only check on 6 October confirmed the column is missing; dashboard automation failed, so this migration is prepared but not applied. Existing records and permissions are preserved. See [setup and discovery rules](Backend/OPENING-HOURS.md).

**40 regression tests and full iOS source type checking passed.** Project/plist validation passed; the original backup checksum is unchanged. Build **0.10.0 (24)** is saved in the existing **FindMyToilet** project. It has not been installed on a phone here. Full packaging and device layout remain unverified because of the previously reported Xcode platform/CoreSimulator issue. Server hosting remains deferred in [the saved setup notes](Backend/burgasbus/server/SETUP.md).

Earlier version notes follow.

## Version 0.9.0 — add places by category and prepare official transport

The **+** button now adds places to Restaurants, ATMs, **Супермаркети и магазини**, and Transport. The category form includes a confirmed map point, name, address, website and notes. Shops offer **Нонстоп: Не знам / Не / Да**. Saved places are combined with Apple Maps results, appear in **Added by me**, support favorites, and can be edited or deleted by an admin. The toilet editor is unchanged. Refresh remains in the map menu.

**Database action required:** run [Backend/category-places-and-transit.sql](Backend/category-places-and-transit.sql) once in the existing Supabase project. It is prepared but **not applied**; dashboard automation failed. New shared-place saves require this setup. See [setup and transport status](Backend/CATEGORY-PLACES-AND-TRANSIT.md).

The native transport reader, stale-position handling, separate bus markers, official planner panel and server importer are implemented, but **official Burgasbus stops/live locations are not connected**. The user must obtain provider data access first. Current transport search results remain clearly attributed to Apple Maps/community. No fake bus positions or invented stops were added; no server importer was deployed.

28 Swift regression tests, 7 Python normalization tests and full iOS source type checking passed. SQL execution, real feed decoding, phone rendering and cross-phone saves remain unverified. The prior Xcode iOS 17.2/CoreSimulator build problem remains unresolved. Version **0.9.0 (build 23)** uses the existing **FindMyToilet** scheme. The original backup is unchanged.

Earlier version notes follow.

## Version 0.8.0 — event welcome, steady map and music launch

The app now opens on **Събитие**, an event welcome page with original purple/pink stage artwork, a heart/waveform identity, direct category shortcuts, favorites, programme and pre-show preparation. The programme remains explicitly unconfirmed; no event dates or venues have been invented. Five bottom tabs expose Event, Map, Favorites, Profile and More. The initial loading presentation lasts about 0.8 seconds after app code starts, then fades into the local event page while shared data continues downloading. The map is constructed only when first opened.

The map explorer now keeps one native MKMapView while switching categories and updates only changed markers. Category changes and empty/late search results cannot issue camera commands. The camera moves programmatically only for explicit Burgas/location recenter actions; user pan/zoom and returning from list mode preserve the visible region. The category controls keep a consistent height, avoiding the previous category-dependent map resizing. Generation-guarded search behavior and the Nonstop filter remain in place. The user's reported flicker/zoom is addressed by these changes, but a live iPhone check remains necessary.

Both the system launch screen and animated loader share the same new bundled stage backdrop, heart, ring, text and sound bars. Runtime motion uses Core Animation: an orbiting note, subtle heart pulse and five sound bars. Reduce Motion/inactive scenes keep the static artwork. The system's initial launch image remains static by iOS design. Original artwork is generated by `Design/render-event-stage.swift` after the base branding generator; no network download is needed at launch.

Run **FindMyToilet** in Xcode for **0.8.0 (build 22)**. Swift source type checking and 19 regression tests passed. The complete unsigned device build was attempted but could not compile the launch storyboard because Xcode reported “iOS 17.2 Platform Not Installed” and could not connect to CoreSimulatorService. No additional SQL is required. The original backup remains unchanged.


## Version 0.7.0 — simpler categories and refreshed navigation

The app has five map categories: toilets, food, ATMs, shops and transport. Shops includes **All shops / Nonstop** filters, also available in Favorites. Nonstop results are shops with an explicit nonstop/24-hour label in their name; MapKit's supported SDK does not supply structured opening hours. The app asks users to check the hours and does not claim that all convenience stores are open 24/7.

The leaderboard tab, screen and ranking calculations have been removed. The bottom navigation now has four larger, labeled destinations: Map, Favorites, Profile and More, with a rounded material surface and clear selection highlights. Category colors carry through the map controls, markers, result cards, place details and walking routes. Favorites has a new collection header and matching category chips; Profile and More use the Eurovision purple theme. Category text colors adapt to light/dark appearance. Existing toilet detail, review and editing screens retain their layout.

Previously saved Nonstop places now appear under Shops. Duplicate legacy/shop records for the same place display once, and removing that favorite queues removal of both stored records. Existing database IDs and pending edits are preserved. **No additional SQL migration is needed for this update.** Cross-phone city favorites still require the version 0.6.1 SQL setup if it has not yet been run.

Run the existing **FindMyToilet** scheme in Xcode to install **0.7.0 (build 21)**. Source type checking, project validation and 15 favorites/search regression tests passed. Device layout and live MapKit coverage remain unverified. The original backup is unchanged.


## Version 0.6.1 — favorites for every category

Favorites now has an All view and separate filters/counts for toilets, restaurants, ATMs, convenience stores, shopping and transport. City place pages have save/remove buttons; saved places reopen with their name, address, map and walking directions. The profile's favorites collection and total include every category. Existing toilet favorites keep their current records and behavior.

New category favorites are stored on the phone under the signed-in account, with pending additions/removals preserved across restarts. **To enable syncing between phones, run `Backend/city-place-favorites.sql` once in your Supabase SQL Editor.** This additive migration has been prepared but not applied: dashboard automation was unavailable. See [the setup instructions](Backend/CITY-FAVORITES.md). Other users cannot access your private favorites through the new table's policies.

Run the existing **FindMyToilet** Xcode scheme to install version **0.6.1 (build 20)**. Eleven favorites/search regression tests and the complete iOS source type check passed; live cross-phone syncing and device rendering still need verification. The original backup remains unchanged.


## Version 0.6.0 — Eurovision Burgas 2027

The app opens directly on a Burgas map with six category chips: toilets, restaurants, ATMs, convenience/24-hour shops, shopping and transport stops. It includes search, map/list switching, location/recenter controls and a “search this area” action after panning. The toilet category uses the existing shared database, filters, details, reviews, editing, favorites and leaderboard. Other categories use MapKit point-of-interest searches; they are not written to the toilet database and do not yet have community reviews. Version 0.6.1 adds private favorites as described above. Programme previews and the saved pre-show checklist are available from the music menu.

Searches are restricted to their requested map area, deduplicated and protected from old/cancelled responses. They time out with a visible retry option. New place details have an interactive map and in-app walking directions. Transport means stops/stations and walking directions to them; live timetables and tickets are not implemented. Convenience-store results do not establish 24-hour opening and the UI explicitly says so. Real coverage depends on Apple Maps and has not been verified on a phone in this update.

The app's display name is **Eurovision Burgas 2027**, with a new heart/waveform icon and violet/pink branding. The static launch screen and runtime loader share `LaunchScreenEurovision.storyboard`; a music note makes a five-second orbit once app code runs. Reduce Motion and inactive scenes use the matching static frame. New artwork is generated from native drawing code in `Design/render-event-brand.swift`. The project/scheme and bundle identifier remain unchanged to preserve installation identity and user data. The guide's name is project branding; no official event schedule or venues are claimed.

Continue editing this project. Keep `/Users/samuilivanov/Documents/Codex/Backups/FindMyToilet-iOS-2026-10-03_10-53-02.zip` unchanged; its checksum has been reverified. Version 0.6.0 introduced the category map; use the current version shown above.

Earlier implementation notes follow; this section describes the current interface.

Startup update: database/configuration and Keychain reads now happen after the first view is created, away from the main thread. Core Location is initialized only on request. Loading, empty-catalogue and retry states are explicit; an empty catalogue no longer removes the map. Startup errors use one non-modal banner rather than alerts on multiple tabs. These changes pass the iOS type check, but the reported blank screen has not been reproduced or verified fixed on a device in this session.

SwiftUI app for iOS 17+, with a Bulgarian interface, MapKit, an on-device SQLite demo and a Supabase shared-backend integration. No third-party iOS packages are required.

## New in this version

- **User profiles:** email/password registration and sign-in, public name, persistent Keychain session, automatic token refresh and sign-out.
- **Shared contributions:** signed-in users can add toilets, publish one review per toilet with seven rating criteria and up to three photos, and edit/delete their own review. All users can read shared toilets/reviews; averages include all reviews for a place.
- **Administrator profile:** admins can edit a toilet’s name, address, map position, type, price/currency, schedule, amenities, access conditions and verification date. They can delete toilets after confirmation and see reports from users.
- **Server-controlled permissions:** regular accounts cannot edit/delete toilet records, edit other people’s reviews or grant themselves admin access. The SQL setup contains RLS policies, column privileges, input checks and a signup trigger that always creates regular users.
- **Routes stay inside the app:** a map with the walking route, distance, estimated time and written directions replaces the Apple Maps redirect. “До най-близката тоалетна” selects the nearest filtered place by straight-line distance. Refresh obtains a new position and route; there is no voice guidance or automatic rerouting.
- **Shared favorites and reports:** favorites are private to their owner; reports are readable by the author and admins. Other devices update on foreground activation, every 30 seconds while active, or on manual refresh.

## What still needs your setup

**Your Supabase project is now configured as the app's default:** `https://shodinaimhixnudqqgck.supabase.co`. The supplied publishable key is bundled in Info.plist. The public toilets, profiles and reviews endpoints returned HTTP 200; anonymous requests for private favorites and reports were denied. The toilet catalogue was empty when checked. Rebuild the app and use **Профил → Регистрация** to create your account. Existing manually saved server settings, if any, take precedence over the bundled default.

The first admin is assigned privately through the Supabase SQL Editor after registering. There is no default admin password, selectable admin signup role or service-role key in the app. Until a backend is configured, the app shows the previous local demonstration; new shared contributions require a connected backend and sign-in.

Existing SQLite data is kept intact and never automatically uploaded. The six demo locations are fictional examples, not a verified directory. A new cloud database starts empty; users add actual locations.

## Run the updated app

1. Open **FindMyToilet.xcodeproj** in this folder using Xcode 15.2 or another compatible version with an iOS 17+ SDK.
2. Select **FindMyToilet** and an iPhone simulator, then press **⌘R**. The existing project’s signing settings were preserved when adding the new files.
3. For a physical iPhone, select the phone, choose your Team under **Signing & Capabilities**, enable automatic signing, then Run. Complete device trust/Developer Mode prompts as needed. [Apple’s device instructions](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
4. Follow **Backend/SETUP.md** to activate shared profiles. Use the same Project URL and public key on the phones taking part in the pilot.
5. Create two regular accounts to check cross-phone contributions. Assign your own account the admin role using the SQL instructions, then refresh the profile.

## Checks completed

- All 14 app Swift files pass the iOS compiler’s type check for arm64 iOS 17.0 using the iOS 17.2 SDK.
- **14 XCTest core tests passed on macOS, zero failures**, using the same model/database/configuration source files and test file. These cover opening hours, filters, ratings, SQLite persistence/rollback, legacy review decoding, nearest-place selection, input validation and rejecting secret/insecure backend configuration.
- Project references and plist files validated. The app no longer contains an Apple Maps redirect.

The new UI, MapKit route requests and signed-in sharing/permissions have **not** been exercised end to end on two phones. Read-only checks against the live Supabase API succeeded as described above. The backend policy test script is included but has not been run against PostgreSQL here. See [TESTING.md](TESTING.md).

## Files

| File | Purpose |
|---|---|
| `CloudClient.swift` | Supabase REST/Auth, session renewal, Keychain, backend configuration |
| `AppStore.swift` | Profiles, shared reads/writes, ratings, ownership checks and sync state |
| `ProfileView.swift` | Connection, registration, login, profile name and admin status |
| `ToiletEditor.swift` | Add toilet / admin edit, map pin, hours and validation |
| `RouteView.swift` | In-app walking route, directions and nearest destination |
| `Models.swift` | Models, opening hours, filters, input validation and nearest selection |
| `Database.swift` | Preserved v1 SQLite demo database |
| `Backend/setup.sql` | Supabase schema, validation and permissions |
| `Backend/policy-tests.sql` | Transactional server permission tests for an isolated test project |
| `Backend/SETUP.md` | Connection and first-administrator instructions |
| `PLAN_BG.md` | Detailed diploma plan and original project roadmap |

## Pilot limits

Toilet, review and profile writes require connectivity; failures remain errors rather than pretending to save offline. Version 0.6.1 city-category favorites additionally support a local cache and queued sync, with explicit status messages. This is a small pilot implementation: photos are bounded JPEGs in JSON review payloads and the app loads paginated complete datasets. Before a large public rollout, use dedicated photo storage, fetch reviews on demand, add moderation/rate controls and account deletion, and configure email delivery and the final privacy policy. The privacy manifest now declares account details and published user content.

Technical sources: [MapKit directions](https://developer.apple.com/documentation/mapkit/mkdirections), [Supabase Auth](https://supabase.com/docs/guides/auth/passwords), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [column privileges](https://supabase.com/docs/guides/database/postgres/column-level-security).


## Версия 0.3.0 — оценки и екран на обект
Оценяване със звезди за чистота, поддръжка, осветление и състояние. Сапун, хартия, вода и достъпност: Да / Не / Не проверих. Екранът на обекта има карта, общ преглед, ревюта, снимки и бързи действия. Обновете приложението с Run в Xcode. Съществуващата база приема новите отговори; `Backend/review-observations.sql` добавя допълнителна проверка на сървъра и не е изпълнен автоматично.


## Версия 0.4.0 — профил
Профилна снимка, любими места, добавени от Вас тоалетни, Вашите ревюта и статистика. За споделените снимки изпълнете само `Backend/profile-photos.sql` в съществуващата база и стартирайте обновеното приложение от Xcode. Миграцията не е приложена автоматично.


## Версия 0.4.1 — интерактивна карта на място
Картата в детайлите може да се мести, увеличава и завърта. Има центриране върху тоалетната и разгъване. Информацията се превърта отделно под картата. Обновени са заглавията, бутоните и картите с информация. Не е необходим SQL скрипт за тази промяна.


## Версия 0.4.2 — близки места и публични профили
Картата в детайлите показва всички заредени тоалетни; докоснете друг маркер, за да смените мястото. Докоснете автора на ревю, за да видите публичния му профил, добавените тоалетни и ревюта. Имейлите и любимите места не са публични. Не е необходима нова SQL миграция.
