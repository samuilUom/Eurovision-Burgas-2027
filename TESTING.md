# App verification

## Map interaction checks

- 89 discovery, map, favourites and community regression checks passed. Map coverage includes neighbourhood searches after category changes, exact camera snapshot isolation, pinch recognition during movement, deceleration, stale callback rejection, explicit recentering, unchanged pins, and valid search tiles near the date line and poles.
- Full iOS source type checking and the unsigned iPhone simulator build passed. The Xcode project file also passed validation.
- Interactive simulator testing was unavailable because CoreSimulatorService could not connect. No phone installation or on-device gesture verification was performed. On a device, check pinch/pan/rotation, Map → List → Map, hospital/pharmacy switching after zooming, Search this area, and moving the map while Around me is awaiting a location fix.

## 2026-10-13 version 0.12.0 — Google reviews activated

- Public component deployment succeeded at `https://burgas-restaurant-google-reviews.v7d7fqybzr.chatgpt.site/`. Real Google search returned Бистро "Ореха" at the expected address. Selecting it and opening Отзиви displayed Google's rating and review text with reviewer identity/date and attribution. Proof: `../../work/google-reviews-live.jpg`.
- An initial Google RPC network error recovered through the visible retry button. An optional photo request failed without blocking review text. These observations do not establish an ongoing Google outage or an app Wi-Fi fault.
- Native `GoogleReviewsWidgetURL` now points to the public component. The packaged app's Info.plist was read back and contains the exact HTTPS URL.
- **Full unsigned generic-iPhone build succeeded** with Xcode 15.2 after allowing access to local developer services. Log: `../../work/google-reviews-build.log`. The earlier CoreSimulator/platform errors were not source failures in this run. Existing unassigned-asset warnings remain in BurgasBackdrop and LaunchOrbit.
- No simulator was running and no app was installed on a phone. Actual WKWebView rendering, source/profile links and match persistence across app launches still need a device run. Browser viewport override returned a blank screenshot and left the document at 1280 px; the saved live proof is a desktop browser view, not an iPhone screenshot.
- The 66 native and nine component checks below remain the source-level evidence; activation changed only the endpoint and documentation, not tested behavior. Project and Info.plist validation passed again.

## 2026-10-12 version 0.12.0 — implementation checks (before activation)

- All 66 native regression tests passed, including six new checks for HTTPS configuration, restaurant-context encoding, invalid coordinates/IDs, exact-origin bridge trust, match expiry/clearing, and address-specific matching.
- Full iOS 17 Swift source typecheck passed; project/Info.plist validation passed. No full Xcode packaging or phone installation was performed; the previously documented simulator/platform issue is not claimed resolved.
- All nine JavaScript DOM tests passed: disabled setup performs no Google calls, search requires an explicit selection, official review component opens after selection, only a successful Place ID is saved, clearing a match works, errors/retry/timeouts/empty results behave correctly, stale results cannot replace newer state, and input is not injected as HTML. Google is stubbed in these tests.
- Browser checked the inactive component at 390×844. Screenshot: `../../work/google-reviews-iphone-preview.jpg`. No live Google reviews or native WKWebView rendering have been verified.
- Authenticated Google Console showed both required services enabled. After explicit user approval, the key was restricted to the exact widget origin and these two APIs; the saved restrictions were verified in the Console. Proof: `../../work/google-key-restrictions.jpg`. Publishing the private component was blocked at the source-credential handoff by automatic approval review; no hosted version is live. See Backend/GOOGLE-REVIEWS.md for continuation.

## 2026-10-07 version 0.11.1 — misleading Wi-Fi warning

Confirmed the live public catalogue is reachable, but the restaurant RPC returns HTTP 404/PGRST202. After the user reported “Restaurant community ready”, a further API check still returned PGRST205 for both restaurant tables and PGRST202 for the function. The user then reported all three existence checks true using `Backend/check-restaurant-community.sql`, which also refreshes the API schema. Subsequent live reads returned HTTP 200 for the restaurant community RPC, including the screenshot restaurant Ореха. Shared read availability is now verified; the previous error was endpoint/schema availability, not a phone Wi-Fi diagnosis. New authenticated writes from a phone remain untested here.

Cloud errors now retain status and server error code. The restaurant feed maps setup/network/auth/permission/throttling/server/decoding errors to distinct titles, messages and icons; cancellation remains silent. 60 Swift regression tests and full-source iOS 17 type checking passed, including seven new error classification and recovery tests. No SQL schema changes were made in this patch. The previously tested full migration remains the required fix for missing database objects.


## 2026-10-07 version 0.11.0 — shared restaurant community

53 regression tests passed, including 13 new restaurant tests. All app Swift sources passed iOS 17 Simulator SDK type checking. Project/Info.plist validation passed. The original backup SHA256 remains `233b706bd330d31ec6c947d4ae9904d5c1fbec90effcb7743f8d428d86f60042`.

34 isolated PostgreSQL checks passed with PGlite 0.5.8, applying the actual base/category/hours migrations and the restaurant migration twice. Verified anonymous reads, denied anonymous writes, server-assigned authors, one review per author, immutable identity fields, owner update/delete boundaries, admin moderation, atomic registration deduplication, rating/text/image limits, 10-photo quota and idempotent retries, bounded thumbnail-only pages, full-dataset rating/count, and cascades. Test: `Backend/tests/restaurant-community.mjs`; local execution log: `work/restaurant-db-tests/results.log`. These checks never wrote to the live project.

Live read-only verification: 76 restaurant rows; hours available; `restaurant_reviews` absent (HTTP 404/PGRST205). New SQL is prepared, not applied. CUA dashboard control failed during kernel startup (`TIOCSTI` sandbox variable). No service-role key or user password was accessed.

A complete simulator build was attempted; it failed in asset/storyboard packaging because CoreSimulatorService/runtime-image service was unavailable and no matching simulator runtime could be located. Full source type checking passed separately. Log: `work/restaurant-build.log`. No successful installation or visual phone verification is claimed.

After running `Backend/restaurant-community.sql`, test restaurant pages on two signed-in phones: review publish/edit/delete and aggregate refresh; independent photo upload/open with attribution; public guest access; owner/admin permissions; offline errors/retry; page loading above 20 items; account changes during requests; canceled iCloud selection; existing favorites and walking routes; large text, light/dark appearance and small-screen layout. Details: [restaurant setup notes](Backend/RESTAURANT-COMMUNITY.md).


## 2026-10-06 version 0.10.0 — opening hours and restaurant discovery

40 XCTest regressions passed, including 12 new availability/restaurant coverage tests, using copies refreshed directly from production sources. The tests are also part of the existing native Xcode test file. Verified: exact 60-minute and closing boundaries; split/overnight/week rollover schedules; Europe/Sofia winter/summer and daylight-saving boundaries; unknown versus closed hours; known hours overriding Nonstop names/flags; legacy and current favorite decoding; filtering known-closed community duplicates before Apple fallback (including Nonstop); bounded outer-district restaurant searches; progressive deduplication; cache reuse/manual refresh; partial failure retry; and ignoring stale restaurant results after changing category. Existing favorites, camera stability, search and transit tests also passed.

All production Swift sources passed type checking against the iOS 17 Simulator SDK. Project and Info.plist syntax validation passed. Reproducible local runner: `work/check-discovery.py` from the workspace root; logs: `work/discovery-tests.log` and `work/discovery-typecheck.log`. The standalone harness initially failed because of unwritable default SwiftPM caches; redirecting caches to the workspace resolved that environment issue.

Read-only live Supabase verification found the existing `city_places` table but no `hours` column (HTTP 400 / 42703). `Backend/place-opening-hours.sql` is additive, preserves row-level policies, and is not yet applied. SQL execution and cross-phone schedule saves remain unverified. Browser automation failed to start. No hosted data was changed.

Live Apple Maps lookups through both POI and natural-language APIs returned MKErrorDomain 1 / MKErrorGEOError -15 on this Mac. No live restaurant count is claimed. The implementation uses region-biased natural-language searches because the supported POI API has a 2 km maximum radius, smaller than the city search tiles. Results are explicitly bounded to the requested overall area. Apple Maps can still omit restaurants.

Full Xcode packaging, rendering and installation on a phone were not repeated; the prior platform/CoreSimulator failure remains unresolved. On an iPhone, check Restaurants then switch rapidly to ATMs/Shops while results arrive, pan and search that area, refresh, and return to cached results. Confirm camera stability, small-screen/large-text layouts, unknown-hours labels, and that nearest directions work with already loaded results while the remaining restaurant areas are loading. After applying SQL, create/edit a schedule, clear it back to unknown, verify on another phone, and check known-closed records disappear from discovery but remain in favorites/contributions.

The original iOS backup still has SHA256 `233b706bd330d31ec6c947d4ae9904d5c1fbec90effcb7743f8d428d86f60042`. The web project was not modified.

## 2026-10-04 version 0.8.0 — event landing and stable category map

All production Swift files passed type checking against the iOS 17 Simulator SDK. Nineteen XCTest tests passed with zero failures in the macOS source harness: eight favorites, seven search, and four new map-state tests. New coverage checks pan/search camera-command stability, explicit recenter, invalid-region rejection, distinguishing layout callbacks from gestures, category-specific marker identities, empty/deduplicated snapshots and unchanged/reordered markers producing no updates. Existing late-category and late-filter search tests also passed. The same test code remains in the native Xcode test target.

CityMapView uses one MKMapView and a marker diff, with no result-driven camera fitting. Only changes to an explicit camera request cause setRegion in updateUIView. Delegate callbacks are delivered outside SwiftUI updates, guard dismantled coordinators/stale camera requests, and selection ignores removed marker instances. Fixed-height category filter rows remove one identified source of category-dependent resizing. This is a code-level fix for the reported flicker/jump, not proof of a device rendering fix.

Event is the default tab, with map/category/favorites links and programme/preparation navigation. Local event content becomes usable after the short startup animation independently of backend completion. The main map is instantiated only when opened. The refreshed loader and static launch share the storyboard and stage assets; layer transforms animate the note, heart and sound bars. Reduce Motion, inactive scene and teardown stop those animations. Stage PNG generation completed and the backdrop was visually inspected. XML, asset references, project/plist syntax and the backup checksum were checked.

An unsigned generic-iPhone Xcode build was attempted and failed at CompileStoryboard with “iOS 17.2 Platform Not Installed”; CoreSimulatorService and runtime-image-service connection failures are in the log. SwiftCompile was also reported failed without a source diagnostic in that aborted build. The separate full-source type check passed. Complete packaging, native marker interactions, launch timing/performance and actual phone rendering remain unverified.

On an iPhone, cold-launch online/offline and confirm the event page appears; check all five category shortcuts, bottom tabs and back stacks; pan/zoom then rapidly alternate Toilets/ATMs/Shops/Transport and confirm the camera stays steady; switch map/list, recenter, select pins, calculate nearest routes, and pan to search a new region. Check first-time location permission, dark/light system appearance, large text, Reduce Motion, background/resume and portrait small-screen layout. No production data or database schema was changed.

## 2026-10-03 version 0.7.0 — categories, tabs and merged shops

All production Swift files passed iOS 17 Simulator SDK type checking. The Xcode project passed plist validation and no leaderboard references remain in app/test sources or project membership. Fifteen XCTest regressions passed in the existing macOS harness using production favorites/search sources and category definitions: eight favorites tests and seven search tests. Four added tests cover legacy convenience decoding/grouping with shopping, deduplicated removal of both stored aliases across restart/stale remote data, Nonstop label/region/store filtering without affecting ATMs, and rejection of late all-shops results after switching filters. Existing account isolation and offline pending-change tests also passed. The canonical display identity handles truncated long place names consistently.

The leaderboard screen, model, update computations and obsolete tests were removed; underlying profiles, contributions, reviews and favorites were not deleted. There are five visible category choices, with the convenience raw value retained solely for compatibility. New search results use shopping, and no additional backend migration is required.

Presentation changes: a four-item rounded material bottom bar over the existing native TabView (preserving each tab's navigation), category colors/labels/cards and route styling, Favorites collection UI, and purple styling for own Profile/More. Existing toilet details/editors are unchanged. Semantic surfaces, light/dark text colors, scalable labels and selected accessibility traits are provided. Nonstop has a visible qualification: it matches explicit name labels and cannot prove current or 24-hour opening.

Runtime visual checks remain outstanding because the simulator service/build packaging limitation below remains unresolved; source checks do not prove layout on a phone. Install build 21 and check small/large iPhones, large text, dark appearance, each bottom tab, keyboard and navigation back state, sheet dismissal, selected category colors, All/Nonstop and map/list parity, nearest routing from filtered shops, and existing favorites on two phones. Live MapKit coverage and server sync were not exercised. The original backup archive checksum was reverified unchanged.

## 2026-10-03 version 0.6.1 — category favorites

All production iOS Swift files passed type checking with the iOS Simulator SDK. Eleven XCTest regressions passed with zero failures in a macOS harness using the exact production city-place/favorites code and category definitions: six new favorites tests and five existing city-search tests. The same tests are registered in the Xcode test target.

New coverage includes stable per-category identity and duplicate saves, saved-place decoding/reopening, offline removals surviving relaunch and stale remote snapshots, merging other-phone favorites without losing pending additions, separate account/server caches and rejecting a mismatched owner, invalid coordinates/categories and unsafe website links. Cache reads/writes happen off the main thread. Sync uses an account generation guard, cancels on logout/server change, and serializes local writes and remote acknowledgments.

The new SQL migration adds only the city_place_favorites table, its validation function and self-only policies. It has **not been executed** against Supabase: browser automation failed to start, and no privileged database connector is available. Live RLS enforcement, actual server serialization and cross-phone synchronization remain unverified. The app retains pending edits locally until the table exists and synchronization succeeds. Existing toilet favorites are unchanged.

Full simulator packaging remains blocked by the CoreSimulatorService/runtime issue documented below. On an iPhone, save/remove a place in each category, switch All/category filters, reopen a place and its route, check the profile total, then restart and switch accounts. After running Backend/city-place-favorites.sql, refresh on two phones signed into the same account and verify adds/removals propagate. Check offline save/remove and retry, plus another account's empty/private collection. Device layout and these live flows have not been verified in this session.

## 2026-10-03 version 0.6.0 — map categories and Eurovision branding

The first tab now opens directly to a Burgas map with category chips, search, map/list switching, location/recenter controls, a search-in-this-area action and nearest walking navigation. Toilet records and filters continue to use the existing store and toilet UI. Restaurants, ATMs, convenience shops, shops and public transport stops use MKLocalSearch with POI filters; returned items are restricted to the searched map region and deduplicated. Provider items are transient route destinations, never database toilet records. The UI labels opening-hour uncertainty and the lack of live transport schedules.

All iOS Swift sources passed type checking. Five regression tests passed in the macOS harness using production CityPlaces.swift, Models.swift and extracted category definitions: region/category filtering and deduplication, external-place navigation fields without invented amenities, stale category results, timeout/late completion/retry, and offline failure/toilet-category isolation. The tests are also in the Xcode test target. The test map-item subclass supplies category metadata because synthetic macOS MKMapItems do not retain the assigned value. No live Apple Maps search or production database writes were performed.

The display/bundle name is Eurovision Burgas 2027; the existing bundle identifier and executable/scheme identity are preserved. The new 1024-pixel app icon is RGB without alpha. All new asset filenames, storyboard image references, project/plist syntax and launch XML validate. The new icon and decorative backdrop were visually inspected. Static and runtime loading screens both use LaunchScreenEurovision.storyboard; the runtime glyph is a music note with a five-second Core Animation orbit. Reduce Motion and inactive scenes show the matching static frame. The archived original app checksum remains unchanged.

A full Xcode simulator build was attempted. It failed during asset compilation because CoreSimulatorService could not locate/connect to a simulator runtime. Thus complete packaging, live map coverage, navigation gestures and the actual launch handoff remain unverified. On an iPhone, verify cold launch and new name/icon; light/dark mode; Reduce Motion; every category; quick category/query changes; offline retry; pan/search here; location permission; map/list mode; nearest-route selection; toilet detail/review/edit and large text. Programme pages remain previews. Existing unrelated tests were not rerun.

## 2026-10-03 Eurovision event home, first UI

All native Swift sources passed iOS 17 simulator type checking with no diagnostics. Xcode project syntax and the new EventHomeView.swift source registration were validated. The backup archive SHA-256 still matches its original manifest. Changes are limited to the new event UI, its project registration, replacing the first tab's entry view, the first tab's colors and an optional close/back action in DiscoverView. Existing toilet details, reviews, editor, route, shared data and backend files are unchanged.

The home provides six category entry points. Toilets present the existing discovery NavigationStack full screen, with a back action. Other categories and the programme navigate to clearly marked previews with no fabricated places or event facts. Programme segments switch the visible content. The preparation checklist uses separate AppStorage keys on the device. Accessibility text sizes switch categories and quick links to single-column layouts; decorative artwork is hidden from VoiceOver.

Simulator execution was attempted but CoreSimulatorService refused the connection in this environment. Full device/simulator rendering and navigation are not verified. In Xcode Run, check: home → each category → back; programme segments; checklist persistence after relaunch; home → toilets → detail/review/route → dismiss → event home; all five existing tab destinations; small iPhone and large text; system light/dark appearance; signed-in and offline startup. No new tests were added for this presentation-only change and existing logic tests were not rerun.

## 2026-09-25 community leaderboard

Added a native Класация tab with separate toilet/review rankings, public profile links and the signed-in user's position. Rankings derive from the existing shared public profiles, toilet ownership and reviews; no database migration or new API request is required. Successful refreshes and contribution edits/deletions update the rankings. Failed refreshes retain the last complete rankings and show the existing sync status. Equal totals use competition ranks (1, 1, 3); demo/deleted places, missing authors/profiles, duplicate records and repeated author/place reviews do not add points.

All iOS app Swift sources passed type checking and the Xcode project passed plist validation. Six leaderboard regression tests passed with zero failures in a macOS harness using the exact production Models.swift and Leaderboard.swift files. Tests also reside in the Xcode test target. Coverage includes both metrics, both totals, competition ties, deterministic ordering, UUID casing, deduplication, missing/deleted/demo data and empty rankings.

Full simulator/device rendering and live cross-phone updates remain unverified. On an iPhone, check both ranking segments, profile links, your highlighted position, pull-to-refresh, an edited versus newly published review, deleting a contribution, dark mode and larger text. No production data was changed during verification.

## 2026-09-25 nearest-route startup and retry

The nearest-route sheet now presents an immutable, nonempty toilet snapshot using item-based presentation. Navigation accepts a recent home-map location, listens to every GPS publication, and resumes after backgrounding without depending on coordinates changing. Permission prompts no longer stop tracking. Stale GPS callbacks keep waiting for a fresh fix, with a 20-second timeout. Route requests have a 25-second timeout and visible retry controls; late/cancelled results cannot replace a newer request.

All iOS Swift sources passed type checking. Five routing regression tests passed against the production model/route-controller code in a macOS test harness with injected MapKit results: presentation snapshot/empty input, stale/invalid GPS, empty destinations, timeout/retry/late completion, and cancellation/new-request isolation. These tests are also included in the Xcode test target. No production database writes or real route requests were made.

On-device checks still needed: tap nearest immediately after launch, accept first-time location permission, deny permission then enable it in Settings, stay stationary, background/resume, retry with poor internet, and verify a real walking route in Burgas. Simulator/device rendering and real GPS/Apple routing were not available in this environment.

## 0.5.9 one layout for static and animated launch

Swift iOS type checking and plist/project syntax checks passed. Launch storyboard XML, project membership, tagged image views and all referenced raster asset filenames validated. AppLoadingView now loads the actual launch storyboard through UIViewControllerRepresentable rather than maintaining a separate SwiftUI copy of the layout. The only runtime difference is replacing the fixed toilet with the Core Animation orbit at identical center/radius dimensions. Reduce Motion/inactive uses the original static image. Ring/orbit assets are now PNGs at three scales. Launch storyboard renamed LaunchScreenUnified and both Info.plist and project resource reference updated. Static loading text, font sizes, map crop, full-view centering, light/dark assets and icon all derive from the same layout.

Full storyboard compilation and device cold-launch handoff remain unverified because the current environment cannot run Interface Builder's simulator service. Test actual install/Home Screen launch, animation start, Reduce Motion, dark mode, offline startup and foreground resume. No claim that iOS can animate before process startup. Prior core tests were not rerun for this presentation-only update.

## 0.5.8 visible centered launch map

All Swift sources passed iOS type checking. Replaced vector-backed map asset entries with bundled 1x/2x/3x PNG variants for light/dark appearance, avoiding reliance on SVG asset rendering. The dark 1x result was visually inspected. Roads converge at the exact image center. Runtime GeometryReader now uses full-screen coordinates; static launch logo/orbit/text center constraints also reference the full view rather than safe area. Both map and icon therefore share the same center, with centered aspect-fill cropping. No network request or extra animation added.

The screenshot confirmed a missing background but did not establish whether its cause was asset rendering, launch caching or an older installed build. This update supplies raster assets and fixes the independently identified centering mismatch. Full asset/storyboard compilation and on-device cold-launch behavior remain unverified. Install and test both initial/static and animated phases in light and dark appearance. No core tests rerun for this asset/layout change.

## 0.5.7 compact review previews and centered-road launch art

All iOS Swift sources passed type checking. Review list cards show stars/date, a three-line comment preview and photo count instead of inline pictures or scoring details. Tapping the card opens a dedicated complete-review page with all scores, observations, text, photos and own-review actions. The author button remains a profile shortcut. Public-profile review cards also replace photos with a count; reviewID destinations open the complete review directly. Deleted/missing reviews show an unavailable state. The gallery remains a separate destination from a review's photo button.

Both light and dark bundled launch illustrations now use fictional roads converging on the center, without Burgas place labels. Existing static launch and animated loading views share that same asset, with the toilet app icon covering the central junction. No network request added. SVG XML validated. On-device navigation, launch rendering and storyboard compilation remain unverified; check card/author taps, profile review links, full-review edit/delete, photo gallery/back, cold launch and dark mode. No core logic tests rerun for this UI-only update.

## 0.5.6 Maps-inspired reviews and launch illustration

All iOS Swift sources passed type checking. Reviews now offer tappable rating-distribution bars, 1–5 star filter chips, a photos-only filter and newest/highest/lowest sorting. Filters combine; All clears them and switching toilets resets them. Rating buckets round each review average consistently with the existing histogram. Visitor cards show a single author header, contribution count, stars/date, written experience before optional detailed scores/essentials, and existing photo/profile actions. Empty filter results have an explicit message. The write-review action spans the summary card.

A native MapKit snapshot was attempted but failed with unavailable accelerated graphics / MKErrorDomain 1. The bundled decorative map was instead redesigned with roads, blocks, park, coast and light/dark palettes; it remains a stylized Burgas illustration, not actual Apple Maps imagery or a surveyed street map. Both launch storyboard and runtime use the same named asset at full opacity. SVG and storyboard XML parsed successfully. No launch network request added.

Device appearance, filters, direct-review navigation, dark-mode asset rendering and full storyboard/asset compilation remain unverified. Test combined star/photo filters and clear, each sort, filters after selecting another toilet, profile-to-review jump, empty results, and cold-launch map/icon readability. Prior core tests were not rerun for these UI changes.

## 0.5.5 photo gallery page and decorative loading backdrop

All iOS Swift sources passed type checking. Photo buttons now push a gallery page through the enclosing NavigationStack instead of presenting a full-screen cover. The page scrolls to the selected photo and shows the review's photos as cards with uploader name/avatar, profile link and review date. Native Back returns to the previous page. Missing profiles retain a clear fallback. Bundled BurgasBackdrop SVG adds a stylized street/coast/Sea Garden illustration behind both static launch and animated loading screens. It is decorative, not a surveyed/navigation map, and performs no network or GPS work. Storyboard and SVG XML plus asset JSON parsed successfully.

Device navigation, profile parent-tap behavior and launch rendering remain unverified. Full storyboard/asset compilation remains unavailable in this environment as previously documented. Check gallery/review/profile photo links, Back, author links, initial photo scroll, large text, light/dark loading backgrounds and logo legibility. UI-only change; prior core tests were not rerun.

## 0.5.4 essential voters and photo viewing

All iOS Swift sources passed type checking. Each essential tile opens a sheet grouping the current toilet's review authors by explicit Yes/No observation; unknown responses are excluded. Counts, names and review dates are shown, with profile navigation for available public profiles and a non-tappable fallback for missing profiles. The gallery retains review/index attribution rather than flattening to anonymous image data. Shared photo buttons in the gallery, review cards and public profiles open a full-screen paged viewer starting at the selected image, with uploader profile link and Close action. Swiping remains within that review's photos. No backend or permissions changes.

Device sheet presentation, profile-card gesture interaction, paging and large-text layouts remain unverified. Check mixed/no answers, deleted/missing profile, opening a voter profile and returning, each photo entry point, selecting a later photo, swiping, uploader profile and dismissal. UI-only changes; prior core tests were not rerun.

## 0.5.3 simpler known-price and weekly-hours controls

All iOS Swift sources passed type checking. Price and hours switches now use positive labels and inverse bindings: ON means known, OFF means unknown. Existing nil/non-nil persistence is unchanged, including known zero/free price and a known entirely closed schedule. Weekly hours are grouped in one section. Each day has an Open switch; closed days show no time inputs, open days show From/To pickers. Copy, 24-hour and additional-interval actions are under More options. All-day intervals show a single 24-hour label with an edit action. Split intervals and overnight behavior remain supported; extra intervals can be removed. The existing interval cap and copy confirmation remain intact.

UI-only update; prior core tests were not rerun. On-device interactions remain unverified. Check existing unknown/known/free prices and schedules, turning known switches off/on without losing draft values, daily open/closed, multiple intervals, 24-hour editing, copy and save/reopen.

## 0.5.2 compositor-driven loading orbit and rounded launch mark

All iOS Swift sources passed type checking. Replaced per-frame TimelineView/SwiftUI orbit updates with a UIViewRepresentable containing Core Animation layers. Matching four-second linear rotation and counterrotation keep the toilet upright, without per-frame SwiftUI body updates. Animation is installed only once per active period and removed when inactive, Reduce Motion is enabled, or the view is dismantled. Layer layout disables implicit animations. Both launch storyboard and runtime view now use the same rounded, transparent-corner LaunchLogo PNG assets at 1x/2x/3x; the app icon itself is unchanged. The rendered 3x logo was visually inspected.

Device frame rate and launch-screen cache behavior remain unverified; test a cold Home Screen launch after installing this build, slow/offline loading, foreground resume, Reduce Motion, and dark mode. The iOS launch storyboard remains static until the process is ready. No artificial loading delay or backend change. Prior core tests were not rerun for this UI-only change.

## 0.5.1 portrait-only iPhone layout

Removed both landscape orientations from Info.plist. Parsed the plist and verified that UISupportedInterfaceOrientations contains only UIInterfaceOrientationPortrait. The project targets iPhone only and uses this explicit plist for Debug and Release. No Swift behavior changes; prior tests were not rerun. Install the new build and rotate the phone on the map, route, profile and editor screens to verify device behavior.

## 0.5.0 live nearest-toilet navigation

All iOS Swift sources passed type checking; existing core XCTest suite passed (see current run log). Route map starts with a Burgas fallback and native heading-following user location instead of automatic whole-route fit. Camera bounds keep zoom between 100 and 3000 meters; native UserAnnotation and recenter control replace the fixed origin marker. Routing no longer resets the map camera after requests. LocationService adds continuous navigation accuracy tracking with a 5m distance filter and 15-second stale-fix rejection, while preserving one-shot Discover requests. Route tracking stops on dismissal/inactive scene and resumes on active. Destination is selected once; directions refresh after movement of at least 50m and at least 30 seconds, or manual refresh. Failed directions can retry on subsequent updates after the cooldown. Directions cancellation and response IDs remain in use.

Physical GPS movement, heading, map camera behavior and battery usage remain unverified here. Test outdoors on device: nearest route starts locally, user marker follows walking, pan then recenter, destination stays fixed, route refresh after movement, permission denial/precise-location off, offline retry, close/background stops tracking and foreground resumes. No background-location entitlement or external Maps redirect added. Existing core tests do not exercise CoreLocation callbacks or MapKit UI.

## 0.4.9 continuous launch appearance

Swift type checking and project/plist syntax checks passed. Launch storyboard XML parsed successfully. Replaced icon-only launch configuration with a static storyboard showing the same background, centered icon, orbit ring/toilet and loading copy as the runtime view. Added the storyboard to app resources and LaunchOrbit vector asset. Runtime orbit starts relative to view creation at the top, instead of jumping to an arbitrary clock-based position, and now uses display-driven TimelineView updates instead of a 30fps cap. Removed mismatching runtime icon clipping/shadows. No added delay or auth/network changes.

Storyboard compilation was attempted but blocked by unavailable CoreSimulator services / “iOS 17.2 Platform Not Installed” in this environment. Full Xcode build and actual cold-launch handoff remain unverified. Test physical-device Home Screen launch separately from debugger launch, light/dark appearance, large text, landscape, Reduce Motion and offline startup. iOS must display a static launch screen until app code runs; this change matches that static frame rather than claiming animation before process startup.

## 0.4.8 branded startup

All Swift app sources passed iOS 17 type checking. Launch plist and named image/color references validated. The system launch screen now uses a light/dark teal-tinted background and the existing app icon via a new LaunchLogo imageset (1x/2x/3x). RootView shows AppLoadingView while AppStore.starting is true, then creates the tabs; startup task stays on the persistent outer Group. No artificial startup delay. A toilet follows a four-second circular path around the center icon with a 30fps TimelineView; Reduce Motion and inactive scenes show a stationary symbol. The illustration scales for shorter screens. Startup errors continue into the existing error/retry UI when starting clears. No data/auth changes.

Full asset compilation, actual launch transitions and device visuals remain unverified in this environment. Check cold launch, dark mode, landscape, Reduce Motion, background/foreground, offline/error-to-retry behavior and successful startup. The OS launch screen is static; animation begins in SwiftUI. This does not resolve OS-level prelaunch stalls. Previous core tests were not rerun for this UI-only change.

## 0.4.7 negative essential reports

All Swift app sources passed iOS 17 type checking. Essential tiles turn orange only when explicit No answers outnumber Yes answers. Ties and no answers remain neutral; free-text comments are not classified. Negative tiles have a persistent orange outline, warning label, and a slow 1.6-second-per-phase background pulse. Text does not flash. Reduce Motion and inactive scenes use a static tint. VoiceOver announces counts and the negative majority. Counts derive from current reviews and update on edits/deletions. No backend changes.

Device animation/appearance remains unverified. Check 0/0, 1/0, 0/1, 1/1 and 1/2 Yes/No counts, then update a review so the warning clears. Check Reduce Motion, app background/foreground, changing toilets, dark mode and large text. UI-only change; prior core tests were not rerun.

## 0.4.6 detail-page information cards

All app Swift sources passed iOS 17 type checking. Working hours now show live open/closed/unknown status, today's schedule and an expandable Monday–Sunday list with today's row highlighted. Status and Sofia weekday refresh every minute; multiple intervals, overnight annotations and 24-hour schedules remain supported. Price has a dedicated card with distinct free/paid/unknown text. Amenities and visitor observations use adaptive icon tiles; missing amenities are labeled unverified, never inferred absent. Visitor Yes/No counts remain separate. No database changes.

UI-only update; core tests were not rerun. Full Xcode build and on-device appearance/touch verification remain outstanding. Check free/paid/unknown prices, nil/empty/split/overnight/all-day schedules, week expansion, changing map pins, conflicting/no visitor answers, dark mode and large text.

## 0.4.5 toilet editor and weekly hours

All app Swift sources passed iOS 17 type checking. The editor has an introductory card, collapsible coordinates, labeled price entry and larger amenity rows. Monday–Sunday schedule cards support closed, scheduled and 24-hour days, compact time pickers, multiple intervals, overnight indicators and copying to weekdays/all days with replacement confirmation. Copying and additions enforce the existing 28-interval limit. Unknown hours remain nil; days without intervals remain closed. Fixed UTC time-picker anchors preserve Burgas wall-clock values independently of device timezone; closing midnight is stored as 24:00. Existing records and backend schema are unchanged.

Device appearance and interaction have not been verified here; no full Xcode build was run. Check a split schedule, 22:00–02:00, 00:00–24:00, equal-time validation, copy/replace/cancel, the interval limit, unknown hours, saving/reopening an existing record, and large text on iPhone. Prior core tests were not rerun for this editor-only change.

## 0.4.4 larger feature answers

All app sources passed iOS type checking. Feature labels are now single words: Сапун, Хартия, Вода, Достъпност. Full descriptions remain in accessibility labels. Review and public-profile answers use larger padded rows and bold Yes/No badges with text and color. The editor has 48-point answer buttons and a separate unknown option; unknown still removes the key rather than saving false. The place overview retains counts of conflicting visitor answers instead of inventing a consensus. ViewThatFits stacks controls/rows for narrow or larger-text layouts. No schema/data migration.

UI-only update; previous core tests were not rerun. Device visual, touch and large-text verification remains outstanding.


## 0.4.3 direct review navigation

All iOS app sources passed type checking. Public profile review cards pass the toilet and exact review UUID together in a single sheet destination. Detail opens Reviews, scrolls to the matching card and outlines it in teal. Added-toilet links still open Overview. Tapping another map pin clears the review target; missing reviews show an explanatory message. The profile list remains behind the sheet for return navigation.

UI-only update; previous core tests were not rerun. Device scrolling/VoiceOver not verified in this session. Acceptance: open the oldest review in a long list from a public profile by title and card body; confirm the exact author/date/comment is highlighted; close and choose another review for the same toilet; verify added-place links still show Overview and selecting another map pin clears highlighting.


## 0.4.2 nearby pins and public profiles

All app Swift sources passed iOS type checking. Details maps now render the full loaded toilets collection with tagged selectable pins, highlight the current place, and switch the active place without creating another details sheet. Switching resets the information scroll and tab to Overview; route, reviews, favorites, reports and admin actions derive from the active place. Deletion handling follows that active ID.

Review author rows open PublicProfileView by user ID. The profile reads public name/photo, toilets filtered by created_by and reviews filtered by authorID. No email, favorites, private reports or account controls are displayed. Added places and review destinations can open toilet details. Missing profiles and empty contributions have explicit states. No database/schema change is required.

UI changes only: previous 24 core tests were not rerun. On-device interaction and appearance were not exercised in this environment. Acceptance: pan/zoom details to see other loaded pins, select a different place after scrolling reviews, verify route/favorite/edit target the new place, delete active place as admin, open another author, inspect their two collections, open a place and return, verify private email/favorites are absent. Existing legacy reviews without an author remain non-tappable.


## 0.4.1 interactive place map

All iOS sources passed type checking. The existing MapKit detail map now uses a bound camera and all native interaction modes. It starts at a 0.004-degree span around the selected toilet, uses the same standard map style as Discover, supports compass/scale controls, and offers recenter and expand/collapse buttons. The map is outside the details ScrollView so map gestures do not compete with the information scroll area. Expansion preserves camera state; coordinate edits explicitly recenter. The previous negative overlap was removed to keep native map attribution visible.

The information panel has a location heading, price badge, address, review shortcut, capsule action buttons and subtle card borders/shadows. No database changes. This is a UI-only update: the previous 24 core tests were not rerun. On-device visuals and gestures remain unverified in this environment. Check pan/pinch/rotation, recenter, expand while panned, scrolling all three tabs, landscape and large text, edited coordinates, map attribution, slow/offline map loading, route and dismiss actions.


## 0.4.0 profile dashboard and photos

All 24 core XCTest tests passed on macOS, including legacy profiles, avatar round-trip/removal, invalid image rejection, resizing and GPS metadata removal. iOS app sources passed type checking. Profile includes avatar editing, stats, favorite/added/review collections, name editing and admin guidance. The current user’s created_by ownership is retained independently of favorites and roles. Private collections refresh once after login; no periodic profile refresh was reintroduced.

Avatar data is downsampled to at most 320 pixels, center cropped square and encoded as a new JPEG under 90 KB before upload. The user reviews the image and saves explicitly; removal sends SQL null. Optional avatar_base64 decodes older profiles. Photos are public alongside reviews; email remains visible only on the signed-in profile screen.

Backend/profile-photos.sql MUST be run once in the hosted SQL Editor to enable photo uploads. It adds the bounded nullable column and grants only column-level updates under the existing owner-only RLS policy. This migration has NOT been applied remotely. Existing favorite/review/added-place lists do not require migration. No live signed-in photo upload/RLS test or on-device visual test was possible in this session.

Device acceptance: upload, replace and remove a photo; inspect it from a second account’s review list; confirm another account cannot update it; compare favorite/added/review counts; open every collection and place; sign out/in and verify no previous user’s private items appear. Test short/long names and larger accessibility text.


## 0.3.0 stars, visitor observations and place details

All iOS app Swift sources passed type checking. All 20 core XCTest tests passed on macOS. New tests verify that Yes, No and unknown survive JSON round trips, observations do not affect the star average, and old reviews without observations remain readable without inferring yes/no answers.

The review editor uses accessible 44-point star buttons for cleanliness, maintenance, lighting and condition; soap, paper, water and wheelchair access use Yes/No/Not checked. Editing an old review explicitly warns that legacy numeric feature ratings are replaced by the new answers on save. At least one quality rating is required. Existing untouched review averages are preserved.

The detail screen has a map header, rounded information panel, route/save/rate actions, overview/reviews/photos tabs, rating distribution, per-review stars and dated observations. All original route, favorite, review, reporting and admin actions remain. Unknown amenities display an explicit empty state.

The existing hosted JSON schema accepts the optional observations field, so no migration is required for the new app to save it. Backend/review-observations.sql adds strict server validation for its allowed keys and Boolean values; it is prepared but NOT applied live. setup.sql includes this validation for new databases.

Not verified in this session: full iPhone/simulator build, visual rendering, VoiceOver, keyboard/layout with large text, live signed-in review persistence and server migration. Device acceptance: publish/edit a review with soap=No, paper=Yes, water=Not checked; reopen on another phone; check averages exclude observations; test empty photos/reviews, tabs, route, favorites and admin editing.


## 0.2.3 phone registration

All app sources pass the iOS type check. All 18 core XCTest tests passed on macOS; new cases cover numeric code validation and expired-code error handling. Registration now leads to an in-app code-entry screen when confirmation is required, with resend, cooldown, cancel and existing-unconfirmed-account entry. Successful verification loads the profile. Signup with confirmation disabled still supports an immediately returned session.

Live signup/code delivery/verification and device UI are not verified. The hosted Confirm signup email template must be updated using Backend/confirmation-email.html; this has not been applied remotely. See Backend/PHONE-REGISTRATION.md. Check successful signup and code verification, wrong/expired codes, resend, an existing unconfirmed account, duplicate signup, network failures and app restart before declaring the flow ready.


## 0.2.2 profile responsiveness update

The iOS source type check passed. All 16 core XCTest tests passed on macOS, including two new tests distinguishing invalid credentials, unconfirmed email, permission errors and malformed server errors. Secure-session writes/deletion now run off the main actor. Login loads only the signed-in profile; shared data refreshes when leaving Profile. Periodic and foreground refreshes pause on the Profile tab.

Device responsiveness has not been measured or verified: simulator control remains unavailable. Rebuild and test typing in Profile for over 30 seconds, failed login, successful user/admin login, sign-out, session restore and switching to Favorites after login. The live backend rejected the supplied credentials; no password or server role was changed by this patch.

## 0.2.1 startup update

All app sources pass the iOS type check after moving configuration/SQLite/Keychain reads out of synchronous root initialization, making Core Location lazy and adding startup/loading/error/empty states. The map now remains visible with an empty catalogue. Main-tab startup alerts were consolidated into a non-modal banner.

The user's immediately blank screen on both simulator and iPhone is **not yet reproduced or confirmed resolved**. CoreSimulatorService remains inaccessible from this session and no matching crash report was available. Rebuild 0.2.1 and verify: cold launch with an empty server, airplane-mode launch and retry, persisted session restore, and Profile access. If the whole screen remains blank, capture the device screen and Xcode debugger/console to identify the actual launch failure. Previous 14 core test results apply to the earlier core logic; this change received type checking, not device/UI execution.

## Completed

- iOS type check: all 14 app Swift files, Xcode 15.2 compiler, iOS 17.2 SDK, arm64 iOS 17.0 target.
- **14 core XCTest methods executed on macOS with 0 failures.** The runner compiled the actual Models, Database, DemoData and CloudClient sources into a testable module. It ran the project’s FindMyToiletTests file through XCTest. This is not an iPhone UI test or a full iOS app build.
- Project file references, shared scheme XML, Info.plist and privacy manifest checked.
- SQLite foreign-key, uniqueness, seed-idempotence and rollback checks passed.
- Source checked: no `openInMaps`, external Apple Maps URL or launch-options redirect remains.

Core test coverage: Sofia timezone/open/close boundaries; overnight schedule; winter timezone/split hours; unknown and 24-hour schedules; combined filters; average of rated criteria; SQLite round trip including image data; rollback; one local review constraint; nearest place and empty input; invalid place fields; insecure/secret backend configuration; decoding v1 reviews without an author.

## Not yet verified

Live connection update: the configured Supabase project returned HTTP 200 for public toilets, profiles and reviews reads. Anonymous favorites/reports reads returned permission-denied responses, as expected. No records or accounts were created by these checks. This verifies connectivity and those anonymous boundaries, not the complete signed-in authorization policy.

- Full build and UI run of version 0.2 on iPhone/simulator in this session. The user reported that version 0.1 ran in their simulator. That does not verify these new screens.
- Supabase signup, email confirmation, token refresh, signed-in user/admin policies and sharing between phones are not yet tested. A project is now configured and read-only connection checks have passed.
- Live MapKit walking routes, denied-location/settings flow and route cancellation on a real device.
- Keychain persistence on a signed iOS install, VoiceOver, largest Dynamic Type and photo uploads.

`Backend/policy-tests.sql` is prepared for a disposable Supabase test project, but has **not been executed here**. It creates test accounts inside a transaction, checks privilege boundaries and rolls back.

## Acceptance checks after connecting Supabase

1. Without sign-in, read the shared catalogue and reviews; add/edit actions are disabled.
2. Register user A, confirm email, sign in. Check the role is User, even if signup metadata tries to request admin through the API.
3. Add a valid toilet with a map pin, price, amenities and split/overnight hours. Invalid coordinates, negative price and malformed hours must be rejected.
4. On a second phone with user B, refresh and see the new toilet. Post another review; both phones show both reviews and the same average.
5. User A can edit/delete A’s review, but direct API attempts against B’s review affect no row. The server, not only UI buttons, must enforce this.
6. A regular user must not update/delete toilet rows or change `profiles.role`, including by direct REST requests.
7. Assign Admin to a designated account through SQL Editor, refresh, and edit every toilet field. Another device sees the changes after refresh.
8. Admin deletes a test toilet: confirm it disappears along with related reviews, favorites and reports. Cancellation preserves everything.
9. A user sees only their own favorites/reports; admin sees all reports but not other users’ private favorites.
10. Sign out and sign in as another user. Private records must not carry across accounts. Relaunch and check session persistence/refresh.
11. Tap navigation on a selected toilet: the route is drawn inside the app; no other maps app opens. Check distance, estimated time and written steps.
12. Apply filters, then “До най-близката”. Destination must be the nearest by straight-line distance within the filtered results. Empty results disable the button.
13. Deny location, lose internet, cancel a route request and retry. No fake route or stale request should replace the current route. Refresh must obtain a fresh position.
14. Disconnect internet before a save: retain form data and show failure. No success message unless the server confirms the write.
15. Pick/remove up to three images, then verify their visibility from the other phone. Confirm over-limit payloads/invalid scores are rejected by server checks.

## Environment notes

The standard SwiftPM runner could not start its nested sandbox in this session. Core XCTest tests were instead built and run directly using the same installed Xcode compiler and XCTest framework, with caches and generated files under work/. This did not test server-side SQL or iPhone-only UI services.
