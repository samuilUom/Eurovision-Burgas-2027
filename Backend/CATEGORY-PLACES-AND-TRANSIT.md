# Categories and Burgasbus — version 0.9.0

## Enable adding places

The app code is ready. The database migration has **not been applied**: browser automation could not access the Supabase dashboard. No hosted data was changed by this update.

1. Open the existing project's [SQL Editor](https://supabase.com/dashboard/project/shodinaimhixnudqqgck/sql) and choose a **new query**.
2. Open `category-places-and-transit.sql` beside this document. Select all of its text, copy it, paste it into the new SQL query, and click **Run**.
3. If Supabase shows a destructive-operation warning: this file replaces only its own named access policies and defines a future official-stop replacement function. Running the migration does not remove existing toilets, reviews, users, favorites, or transport rows. Review that the editor contains this exact new file, not an older query, before running it.
4. Run **FindMyToilet** in Xcode to install **Eurovision Burgas 2027, 0.9.0 (23)**. In a category, tap **+**, enter a name, choose a map point, and save.
5. Check the place from another signed-in phone after refreshing its map. It should also appear under **Профил → Добавени от мен** on the author's phone.

All users can read places. Signed-in users can create places with their own author ID. Admins can edit and delete them. The category is fixed to the supported list, and the database validates coordinates and field lengths. Toilets continue to use the existing separate editor, tables and permissions. Shops have a three-state Nonstop setting: yes / no / unknown.

City favorites still use the earlier `city-place-favorites.sql` migration. This update does not rerun or replace it.

## Official transport data — still pending

No official Burgasbus stops or live vehicles were imported. The user has not requested data access, and no authorized feed URLs or provider credentials have been supplied. The map currently continues to use Apple Maps and community transport places, with their source displayed in details.

Burgasbus lists a GTFS data-access application and terms on its [official data page](https://burgasbus.info/burgasbus/?page_id=15477). Request access to the static GTFS schedule/stops and GTFS-Realtime **VehiclePositions**, including permission to show the data in this app, required attribution, authentication details and permitted refresh interval. No application or email has been sent on the user's behalf.

The app has a **Бургасбус** panel with an in-app browser for the [official transport planner](https://transport.burgasbus.info/app/planner). This is a link to the provider's portal, not a claim that native live tracking is already connected.

## Prepared integration

`burgasbus/import_feed.py` is a server-side adapter for standard GTFS ZIP + GTFS-Realtime VehiclePositions. The exact provider feed format and terms still need verification after access is granted. If the provider exposes a different format, adapt the importer before deployment.

- `burgasbus_stops` stores authoritative stops. The importer replaces them atomically through `replace_burgasbus_stops`; validation failure rolls back the operation.
- `burgasbus_live` stores one full current vehicle snapshot. A fresh empty feed clears disappeared buses. Differential feeds are rejected until supported explicitly.
- Mobile clients (including admins) have read-only access to these two tables. Only server service credentials can import official data.
- The app fetches stops when Transport is opened and polls vehicle positions every 20 seconds only while that category is foregrounded. It stops polling in the background or another tab.
- Vehicle timestamps must be actual GPS measurement times, never import time or the feed-header timestamp. Positions older than 120 seconds or more than 30 seconds in the future are hidden. A local expiry task removes stale markers even if a request hangs.
- Marker positions update without recreating the map or recentering the user's camera. Vehicles are not included in the “nearest stop” walking destinations.
- A failed official-data request does not block the rest of the app. Cached stops can remain available, with a visible failure message; live markers are cleared.

### Server operator instructions (after Burgasbus approval)

Use Python 3.9+ in a server virtual environment and install `burgasbus/requirements.txt`. The parser uses the [official GTFS Python bindings](https://gtfs.org/documentation/realtime/language-bindings/python/) and [VehiclePosition specification](https://gtfs.org/documentation/realtime/reference/#message-vehicleposition).

Set these values through the server's private environment/secret settings, never in Swift, Info.plist, a checked-in file or a screenshot:

- `BURGASBUS_GTFS_URL`: final authorized HTTPS ZIP endpoint.
- `BURGASBUS_VEHICLES_URL`: final authorized HTTPS VehiclePositions endpoint.
- `BURGASBUS_HEADERS_JSON`: optional provider-authorized HTTP headers as JSON; default `{}`.
- `SUPABASE_URL`: this project's HTTPS origin.
- `SUPABASE_SERVICE_ROLE_KEY`: server-only Supabase service key.

First run `python import_feed.py` from `Backend/burgasbus` to validate without writing. It prints counts only. An authorized downloaded feed can be checked with `--schedule-file /path/to/feed.zip --live-file /path/to/vehicles.pb`.

After checking the output and provider terms, `python import_feed.py --publish` imports one snapshot. `--publish --watch` refreshes vehicle positions every 20 seconds and the static GTFS daily. Adjust these intervals to comply with the approved provider limits before enabling a server process. Do not start this as an unsupervised process on the user's Mac; deploy and monitor it on an appropriate server after access is confirmed.

No importer, recurring job, new paid service, provider credential, or secret key was installed/deployed/configured in this turn.

## Validation

28 Swift regression tests and 7 Python normalization tests passed. The complete iOS source set passed type checking. Tests cover place validation/filtering, favorites compatibility, category/map state, stale and invalid vehicle observations, cancellation, old-server responses, stop parsing, and refusal of incomplete/differential live data.

The SQL migration and RLS behavior have been reviewed but not executed against a database. The Python normalization tests use explicit test fixtures; decoding a real authorized protobuf feed, cloud publication, cross-phone saving, and on-device rendering are not yet verified. A full Xcode build remains blocked by the previously observed local iOS 17.2/CoreSimulator platform issue.

After applying the SQL, verify guest read/no write, user create/no edit/delete, admin edit/delete, and refusal of mobile writes to official transport tables before broader release.

Server preparation update (4 October 2026): a secret-free Ubuntu initialization package and IP verification script are ready in [burgasbus/server/SETUP.md](burgasbus/server/SETUP.md). Hosting is **free only**. Oracle account creation/verification is still pending; no server or reserved IP has been allocated. Three local server-configuration checks passed; a live Linux boot has not been tested.
