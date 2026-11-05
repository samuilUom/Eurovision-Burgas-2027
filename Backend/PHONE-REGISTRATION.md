# Register on iPhone

One-time Supabase project-owner setup:
1. Open Authentication → Email Templates → Confirm signup in your Supabase dashboard.
2. Replace the email body with the contents of `confirmation-email.html` and save. Keep the literal `{{ .Token }}` placeholder.
3. Keep email confirmation enabled and allow new signups.

On the phone, rebuild the updated app, then Profile → Регистрация. Enter a display name, email and password (at least eight characters). Submit, read the newest email and enter its numeric code in the app. Verification creates a session and loads the profile. The database signup trigger assigns role `user`; no administrator promotion is performed.

Existing unconfirmed accounts: select Вход, enter the account email, then „Имам непотвърден профил — изпрати код“. This confirms ownership; it does not reset an existing password. Resends have a 60-second client cooldown and server rate limits still apply. Duplicate signups may receive an intentionally generic server response; confirmed existing users should use login.

The template change has NOT been applied to the hosted project because dashboard automation is unavailable. Without it, Supabase continues sending its old link email. No global confirmation bypass, privileged key or admin-role selection is added to the app.

Reference: https://supabase.com/docs/guides/auth/auth-email-templates
