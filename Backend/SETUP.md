# Shared accounts and database setup

The app now bundles your project URL (`https://shodinaimhixnudqqgck.supabase.co`) and publishable key as its default connection. Read-only API checks confirmed that the public tables are accessible and private favorites/reports reject anonymous access. **For this project, skip steps 1–5 if you already ran setup.sql successfully. Rebuild the app and start at step 6.** Do not rerun setup.sql on the existing schema. There is no built-in admin password and no automatic admin assignment. The instructions below also document how to configure a separate project later.

1. Create a project at [Supabase](https://supabase.com/dashboard). Keep its database password private.
2. Open its SQL Editor and run the complete `setup.sql` in this folder **once in a new project**. This creates profiles, toilets, reviews, favorites, reports, input validation and row-level security policies. This is separate from the existing on-device SQLite database.
3. In Authentication, enable email/password sign-in and set the minimum password length to at least 8. Keep email confirmation enabled. Set an appropriate confirmation landing URL in Auth URL Configuration; after confirming, users return to the app and sign in with their password. Configure SMTP before a public launch; the default email service has limits.
4. Copy the Project URL and **publishable key** (or legacy **anon** key) from the project’s Connect/API settings. Never use a secret/service-role key in the app or send it in chat.
5. Run the app. In **Профил**, paste the URL and public key, then choose **Провери и свържи**. The app checks the `toilets` endpoint before saving the configuration. Repeat on each test phone with the same project.
6. In **Профил → Регистрация**, create your account. Confirm the email if requested, then sign in. New accounts always receive role `user`.
7. Create your administrator privately in the Supabase SQL Editor. Replace the placeholder below with the exact UUID from **Authentication → Users** for your own account. Do not promote arbitrary users:

```sql
update public.profiles
set role = 'admin'
where id = 'REPLACE-WITH-YOUR-AUTH-USER-UUID'::uuid;
```

8. In the app tap **Обнови профила и данните**. The role now displays **Администратор**. Open a toilet to edit or delete it.
9. Create a different regular account on a second device. Add a toilet on one device, then refresh the other. Review it from both accounts; both reviews and their average should be visible.

## Permissions

| Action | Guest | User | Admin |
|---|---|---|---|
| Read toilets/reviews and use routes | Yes | Yes | Yes |
| Add toilet | No | Yes | Yes |
| Edit/delete any toilet | No | No | Yes |
| Mark a toilet as verified | No | No | Yes |
| Create/edit/delete own review | No | Yes | Yes |
| Edit somebody else's review | No | No | No |
| Rename own profile | No | Yes | Yes |
| Change role through app/API | No | No | No |
| Read reports | No | Own | All |

Roles are enforced with database grants and RLS, not just the app’s buttons. `profiles.role` is never writable by the client. The signup trigger ignores any role requested in signup metadata. An admin deletes a toilet with a confirmation; associated reviews, favorites and reports are deleted by foreign-key cascades.

## Storage and updates

The previous SQLite demo database stays on-device and is not uploaded. A configured cloud project starts with its actual records, possibly an empty list. No fictional demo toilets are uploaded. Shared changes are written immediately; other devices fetch updates on app activation, at a 30-second foreground interval, or using Refresh/pull-to-refresh. Offline writes show an error and are not described as saved.

Sessions are kept in iOS Keychain, scoped to the server URL, with refresh tokens; passwords are not stored. The public connection settings are in the app’s Application Support directory. Public display names, roles, toilets and reviews are readable from the public API. Emails/passwords remain in Supabase Auth. Reports and favorites have separate privacy rules.

For this small pilot, review photos are reduced JPEGs stored as base64 in each review's JSON payload, with server size limits. Before a large/public deployment, move photos to Supabase Storage with upload policies and moderation, fetch reviews/photos on demand, add spam/rate controls and an account-deletion flow, and publish a privacy policy. The current client loads paginated complete datasets and is intended for a small Burgas pilot.

## Verification before inviting users

Run the included `policy-tests.sql` in an isolated test project after `setup.sql`. It uses temporary test users in a transaction and rolls all changes back. Then test two real phones/accounts, email confirmation, session renewal, sign-out/sign-in, bad network and the in-app route. The source integration alone does not prove these hosted checks pass.

MapKit supplies the route inside the app. It requires internet and location permission and does not provide voice guidance or automatic turn-by-turn rerouting. “До най-близката” chooses the nearest filtered toilet by straight-line distance and requests a walking route to that destination.

Sources: [Supabase Auth](https://supabase.com/docs/guides/auth/passwords), [Row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security), [Column privileges](https://supabase.com/docs/guides/database/postgres/column-level-security), [API keys](https://supabase.com/docs/guides/getting-started/api-keys).


## Shared demonstration locations
Run `add-demo-toilets.sql` in the existing project SQL Editor to add six fictional locations. The script allows the existing `isDemo` Boolean to be true, preserves all access policies and does not modify accounts. Re-running does not overwrite edits. These are not verified public toilets. The script has been prepared but has not been executed on the hosted database. For a regular test account, use Authentication → Users → Add user → Create new user with an email you control, a password and Auto Confirm User enabled. The existing signup trigger creates role `user`; do not run grant-admin.sql for that account.
