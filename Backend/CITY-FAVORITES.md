# Favorites in every category

The updated app saves restaurant, ATM, convenience-store, shopping and transport favorites privately under the signed-in account. Version 0.7.0 groups existing convenience-store entries into Shops, with All/Nonstop filters. Legacy database IDs are retained, so no additional SQL migration is needed for that merge. The original toilet favorites table and records are unchanged.

## Enable syncing between phones

1. Open the project's Supabase SQL Editor: https://supabase.com/dashboard/project/shodinaimhixnudqqgck/sql
2. Create a new query. Paste the complete contents of `city-place-favorites.sql` and click **Run**.
3. In the updated iPhone app, open **Любими** and pull down to refresh, or tap **Опитай синхронизация**.

This migration was prepared, but has **not** been applied automatically. The dashboard automation tool could not start in this session. It requires no secret keys in the app, no account recreation and no changes to existing toilets or favorites.

Until the migration runs, the new favorites work on the current phone. Their pending additions/removals are stored across restarts and uploaded once syncing becomes available. The app explicitly distinguishes local saves from successful cloud synchronization. Do not delete the app while unsynced changes remain; uninstalling removes its local cache.

Favorites are isolated by both server and account. Signing out clears the displayed collection; signing back into the same account reloads that account's cache. Reading and writing the cache occurs away from the main thread. Save/remove actions for city places pause during a sync to avoid conflicting local writes. Failed writes are not presented as successful saves.

The SQL uses row-level security so authenticated users can only read/change their own rows. Other users (including ordinary in-app admins) cannot see them. The migration is additive and can be rerun. Existing toilet favorites continue using their established online-only saving behavior.

Place names, addresses and coordinates are saved snapshots; they may become outdated. Walking navigation uses saved coordinates, and opening a favorite does not depend on repeating the original search.
