# Activate profile photos

1. Copy all of `profile-photos.sql` into the existing Supabase project SQL Editor and run it once. Do not rerun setup.sql on the existing database.
2. Rebuild the app in Xcode (version 0.4.0).
3. Sign in → Profile → tap the photo → choose an image → Save. Removal also requires Save. The photo is public next to reviews and synchronizes via profiles.avatar_base64.

The migration preserves roles, accounts and existing data. The existing profiles_rename_self RLS policy restricts updates to the account owner; only avatar_base64 is added to the writable columns. Admin-role changes remain unavailable to app users. Photos are capped at 90 KB decoded (120,000 base64 characters). Existing profiles show an initial until a photo is saved.

Migration status: prepared but not applied; browser automation is unavailable. Favorites, added toilets and review collections use existing tables and need no migration.
