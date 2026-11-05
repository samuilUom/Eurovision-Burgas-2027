# Five mapped toilets and recreated administrator

Run the entire `admin-and-five-toilets.sql` in the existing Supabase project's SQL Editor as project owner. It resolves samuil.ivanov2008@gmail.com to the current auth user ID, creates a missing profile if needed, grants that account admin and inserts five locations. Missing or ambiguous accounts abort the transaction. Re-running preserves existing toilet edits. No passwords, confirmation settings, other roles or row policies change.

Status: prepared, not executed on the hosted database because browser control failed. After execution, expect one admin profile row and five toilet rows. Sign out/in on the phone and refresh the map. No app rebuild is required.

The locations are actual OpenStreetMap amenity=toilets records, not demonstration points. They have not been physically inspected and current availability is not guaranteed. Names are descriptive area labels, not source-provided business names. Coordinates come from OSM nodes, or the mean of building outline vertices for ways (not a surveyed entrance). Old/unknown hours, price and amenities are deliberately left unknown. No reviews or verification dates are fabricated. A seasonal restriction is retained for node 5063648843.

Attribution: © OpenStreetMap contributors, ODbL: https://www.openstreetmap.org/copyright . Raw selected source tags and links are in `burgas-five-sources.json`; app-compatible data is in `burgas-five-toilets.json`. Source credit also appears in each toilet's details. Extracted 2026-09-22 through the public OSM map API.

- Обществена тоалетна — център: https://www.openstreetmap.org/node/3287240667
- Обществена тоалетна — Автогара Юг: https://www.openstreetmap.org/way/330453563
- Обществена тоалетна — Морска градина: https://www.openstreetmap.org/node/3287240668
- Обществена тоалетна — Морска градина (юг): https://www.openstreetmap.org/way/985556845
- Обществена тоалетна — крайбрежна алея: https://www.openstreetmap.org/node/5063648843
