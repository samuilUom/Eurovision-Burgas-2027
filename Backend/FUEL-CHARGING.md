# Fuel and EV charging — 0.14.1 (31)

Бензиностанции (`fuel`) and Зарядни станции (`charging`) are separate visible sections on the start page, map and favourites. The combined fuel/charging slot and its extra type filters were removed in 0.14.1. The existing category presentation is reused. Search uses MapKit's `.gasStation` and `.evCharger` point-of-interest filters and restricts results to the requested map region. Listings are live Apple Maps results or user contributions; no fabricated seed locations or charger availability were added.

The existing detail screen, walking directions, website, add/edit form and hours editor are reused. A known all-week 24-hour schedule (or explicit nonstop flag when no schedule exists) supplies the 24/7 badge. Unknown schedules and “24/7” in a place name do not. Edited hours override an old nonstop flag. Hospitals and pharmacies retain their own stored categories.

## Manual Supabase update

Run the whole [fuel-charging-categories.sql](fuel-charging-categories.sql) in the existing Supabase project. It extends the existing category constraints and favourites payload validator, retains healthcare support, and does not delete place or favourite records or change ownership policies. Success returns **Fuel and charging categories ready**. The file has not been executed by the assistant.

Browse and route to Apple Maps locations before running it; shared new fuel/charging records and synced favourites require the update.

## Map changes

- Health/fuel type searches use one region query instead of nine district queries.
- Bounded in-memory caches (16 keys, 10-minute complete-result freshness) are keyed by category, query, region and shop filter.
- Explicit refresh retains the old snapshot until replacement, so pins do not clear during refresh. A changed search key never borrows another type's pins. Late responses retain the existing generation guard.
- Map annotation changes do not move the camera. Coordinate KVO updates are skipped for unchanged coordinates. 24/7 labels update without changing pin IDs and reset when marker views are reused.
- Loading and health helper text reserve consistent footer space to reduce map resizing during type changes.

82 regression checks cover the existing discovery, favourites and review logic plus the new search caching, rapid switching, badge updates and fuel/charger separation. Full iOS source type checking and the Xcode simulator build also passed. Device visual verification remains pending.
