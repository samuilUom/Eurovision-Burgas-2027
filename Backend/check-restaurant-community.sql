-- Run both statements in the SAME Supabase project used by the app:
-- shodinaimhixnudqqgck
-- Refreshes the API schema cache, then checks the actual database objects.
notify pgrst, 'reload schema';
select
  to_regclass('public.restaurant_reviews') is not null as reviews_table_exists,
  to_regclass('public.restaurant_photos') is not null as photos_table_exists,
  to_regprocedure('public.restaurant_community(uuid,integer,integer)') is not null as community_function_exists;
