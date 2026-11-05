# Opening hours — version 0.10.0

The app changes are saved. On 6 October 2026, a read-only check of the connected Supabase project confirmed that `city_places` exists but its `hours` column does not. The migration below has **not** been applied: the dashboard automation service failed to start.

## One database step

1. Open [your Supabase SQL Editor](https://supabase.com/dashboard/project/shodinaimhixnudqqgck/sql) and create a **new query**.
2. Open `place-opening-hours.sql` in this folder. Select all of its text, copy it, paste it into that new query, then click **Run**.
3. Expect `Success. No rows returned`. The script adds an optional schedule column, validates intervals, and grants authenticated users column access under the existing row policies. It does not delete places, accounts, reviews or favorites. Running it again is supported.
4. Run the **FindMyToilet** scheme in Xcode to install **Eurovision Burgas 2027 0.10.0 (24)**. Add or edit a place, enable **Знам работното време**, choose a weekday, and set its hours. The **Бързо** menu can copy a day's hours across the week or choose 24 hours every day.
5. Save, refresh on a second phone, and check that the hours and current status agree. Before this SQL update, places without hours can still be saved, but saving a supplied schedule fails rather than silently discarding it.

## Discovery rules

- Known schedules use the local time in Burgas (Europe/Sofia). Open places and places opening within the next 60 minutes appear automatically. Known-closed places are hidden from discovery and its nearest-place candidates.
- Unknown or invalid schedules remain visible, explicitly labelled **Неизвестно работно време**. Unknown does not mean open. The supported Apple Maps SDK does not supply structured business hours; a strict known-open-only rule would hide those results.
- An empty known schedule means closed all week. Days without intervals are closed; intervals can cross midnight, and split opening periods are supported.
- Shops retain one **Нонстоп** discovery button. A structured weekly schedule takes precedence over older nonstop answers or a shop's name. A name containing 24/7 can match the shop filter but does not establish that the place is currently open.
- Transport stops do not use business-hour filtering. Favorites and contributed-place collections keep closed places accessible for revisiting/editing.
- Toilet filter buttons are removed; prices and amenities are shown on the cards. Existing toilet schedules already work and need no migration.

## Restaurant coverage

Opening Restaurants searches nine areas across Burgas, including Sarafovo and Meden Rudnik, through Apple's native MapKit search. Results appear progressively, duplicates are removed, and completed searches are reused for 10 minutes in memory. Manual refresh searches again. A search after moving the map uses that selected map area. Partial results remain available with a retry message if a district lookup fails.

This is live discovery in the iPhone app, not an import of every restaurant into Supabase. Google integration is deferred at the user's request. No Google billing account is needed. Apple results can be incomplete; no promise of all restaurants or verified opening hours is made. The live native lookup on this Mac failed with MKErrorDomain 1 / MKErrorGEOError -15, so current restaurant names/counts need verification on an iPhone.

Server hosting and Burgasbus feed access remain deferred; see `burgasbus/server/SETUP.md`.
