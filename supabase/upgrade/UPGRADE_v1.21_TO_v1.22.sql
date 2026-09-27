-- iMersFinora v1.21 -> v1.22
-- Branding upload reliability: DB operations go through SECURITY DEFINER RPCs.

create or replace function public.get_branding_library(p_family_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if not public.is_family_member(p_family_id) then raise exception 'Akses keluarga ditolak'; end if;
  return jsonb_build_object(
    'active',coalesce((select pwa_icon_url from public.app_branding where family_id=p_family_id),''),
    'assets',coalesce((select jsonb_agg(jsonb_build_object('id',id,'file_name',file_name,'public_url',public_url,'created_at',created_at) order by created_at desc) from public.brand_assets where family_id=p_family_id),'[]'::jsonb)
  );
end $$;

create or replace function public.register_brand_asset(p_family_id uuid,p_file_name text,p_file_hash text,p_public_url text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v public.brand_assets;
begin
  if not public.is_family_admin(p_family_id) then raise exception 'Hanya Owner/Admin yang dapat mengelola branding'; end if;
  insert into public.brand_assets(family_id,file_name,file_hash,public_url)
  values(p_family_id,p_file_name,p_file_hash,p_public_url)
  on conflict(family_id,file_hash) do update set file_name=excluded.file_name
  returning * into v;
  return jsonb_build_object('id',v.id,'file_name',v.file_name,'public_url',v.public_url,'created_at',v.created_at);
end $$;

create or replace function public.apply_pwa_icon(p_family_id uuid,p_public_url text)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  if not public.is_family_admin(p_family_id) then raise exception 'Hanya Owner/Admin yang dapat mengelola branding'; end if;
  if not exists(select 1 from public.brand_assets where family_id=p_family_id and public_url=p_public_url) then raise exception 'Gambar tidak ditemukan di Media Library'; end if;
  insert into public.app_branding(family_id,pwa_icon_url,updated_at) values(p_family_id,p_public_url,now())
  on conflict(family_id) do update set pwa_icon_url=excluded.pwa_icon_url,updated_at=now();
  return true;
end $$;

create or replace function public.delete_brand_asset(p_family_id uuid,p_asset_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_url text;
begin
  if not public.is_family_admin(p_family_id) then raise exception 'Hanya Owner/Admin yang dapat mengelola branding'; end if;
  select public_url into v_url from public.brand_assets where id=p_asset_id and family_id=p_family_id;
  if v_url is null then raise exception 'Gambar tidak ditemukan'; end if;
  if exists(select 1 from public.app_branding where family_id=p_family_id and pwa_icon_url=v_url) then raise exception 'Icon sedang aktif. Terapkan gambar lain terlebih dahulu'; end if;
  delete from public.brand_assets where id=p_asset_id and family_id=p_family_id;
  return true;
end $$;

revoke all on function public.get_branding_library(uuid) from public;
revoke all on function public.register_brand_asset(uuid,text,text,text) from public;
revoke all on function public.apply_pwa_icon(uuid,text) from public;
revoke all on function public.delete_brand_asset(uuid,uuid) from public;
grant execute on function public.get_branding_library(uuid) to authenticated;
grant execute on function public.register_brand_asset(uuid,text,text,text) to authenticated;
grant execute on function public.apply_pwa_icon(uuid,text) to authenticated;
grant execute on function public.delete_brand_asset(uuid,uuid) to authenticated;
