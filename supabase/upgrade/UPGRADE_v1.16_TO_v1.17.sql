-- iMersFinora v1.17: dynamic PWA branding + deduplicated image library
create table if not exists public.app_branding (
 family_id uuid primary key references public.families(id) on delete cascade,
 pwa_icon_url text,
 updated_at timestamptz not null default now()
);
create table if not exists public.brand_assets (
 id uuid primary key default gen_random_uuid(),
 family_id uuid not null references public.families(id) on delete cascade,
 file_name text not null,
 file_hash text not null,
 public_url text not null,
 created_at timestamptz not null default now(),
 unique(family_id,file_hash)
);
alter table public.app_branding enable row level security;
alter table public.brand_assets enable row level security;
drop policy if exists app_branding_member_read on public.app_branding;
create policy app_branding_member_read on public.app_branding for select to authenticated using(public.is_family_member(family_id));
drop policy if exists app_branding_admin_manage on public.app_branding;
create policy app_branding_admin_manage on public.app_branding for all to authenticated using(public.is_family_admin(family_id)) with check(public.is_family_admin(family_id));
drop policy if exists brand_assets_member_read on public.brand_assets;
create policy brand_assets_member_read on public.brand_assets for select to authenticated using(public.is_family_member(family_id));
drop policy if exists brand_assets_admin_manage on public.brand_assets;
create policy brand_assets_admin_manage on public.brand_assets for all to authenticated using(public.is_family_admin(family_id)) with check(public.is_family_admin(family_id));
grant select,insert,update,delete on public.app_branding,public.brand_assets to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('finora-branding','finora-branding',true,2097152,array['image/png','image/webp']) on conflict(id) do update set public=true,file_size_limit=2097152,allowed_mime_types=array['image/png','image/webp'];
drop policy if exists finora_branding_select on storage.objects;
create policy finora_branding_select on storage.objects for select to public using(bucket_id='finora-branding');
drop policy if exists finora_branding_insert on storage.objects;
create policy finora_branding_insert on storage.objects for insert to authenticated with check(bucket_id='finora-branding' and public.is_family_admin((storage.foldername(name))[1]::uuid));
drop policy if exists finora_branding_delete on storage.objects;
create policy finora_branding_delete on storage.objects for delete to authenticated using(bucket_id='finora-branding' and public.is_family_admin((storage.foldername(name))[1]::uuid));
drop policy if exists app_branding_public_manifest on public.app_branding;
create policy app_branding_public_manifest on public.app_branding for select to anon using(true);
grant select on public.app_branding to anon;
