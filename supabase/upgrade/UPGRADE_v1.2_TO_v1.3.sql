create or replace function public.bootstrap_my_workspace() returns uuid
language plpgsql security definer set search_path=public as $$
declare v_family uuid; v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  insert into public.profiles(id,full_name,phone)
  select u.id,coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name',split_part(u.email,'@',1)),u.phone from auth.users u where u.id=v_uid
  on conflict(id) do nothing;
  select family_id into v_family from public.family_members where user_id=v_uid order by joined_at limit 1;
  if v_family is null then
    insert into public.families(owner_id,name) values(v_uid,'My Family') returning id into v_family;
    insert into public.family_members(family_id,user_id,role) values(v_family,v_uid,'owner');
    insert into public.accounts(family_id,owner_user_id,name,type) values(v_family,v_uid,'Main Wallet','wallet');
    insert into public.wa_gateway_settings(family_id) values(v_family) on conflict(family_id) do nothing;
    insert into public.telegram_settings(family_id) values(v_family) on conflict(family_id) do nothing;
  end if;
  return v_family;
end;$$;
revoke all on function public.bootstrap_my_workspace() from public;
grant execute on function public.bootstrap_my_workspace() to authenticated;
