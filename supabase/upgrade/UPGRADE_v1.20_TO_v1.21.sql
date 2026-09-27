-- iMersFinora v1.20 -> v1.21
-- Dynamic category management + reporting uses the existing categories/transactions schema.
-- This migration normalizes grants and seeds missing default categories only.
begin;
grant select, insert, update, delete on table public.categories to authenticated;
grant select on table public.transactions, public.accounts, public.family_members, public.profiles to authenticated;
select public.seed_family_categories(f.id) from public.families f;
commit;
