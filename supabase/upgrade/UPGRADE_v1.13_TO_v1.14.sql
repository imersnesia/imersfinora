-- iMersFinora v1.14
-- Single-family install: family context is internal and is created automatically.
-- Safe to run repeatedly.
create or replace function public.bootstrap_my_workspace() returns uuid
language plpgsql security definer set search_path=public as $$
declare v_family uuid; v_uid uuid:=auth.uid(); v_email text; v_inv record;
begin
 if v_uid is null then raise exception 'Not authenticated'; end if;
 select lower(email) into v_email from auth.users where id=v_uid;
 insert into public.profiles(id,full_name,phone)
 select u.id,coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name',split_part(u.email,'@',1)),u.phone
 from auth.users u where u.id=v_uid on conflict(id) do nothing;
 select fm.family_id into v_family from public.family_members fm where fm.user_id=v_uid order by fm.joined_at limit 1;
 if v_family is null then
   select * into v_inv from public.family_invites where email=v_email and accepted_at is null order by created_at limit 1;
   if found then
     v_family:=v_inv.family_id;
     insert into public.family_members(family_id,user_id,role) values(v_family,v_uid,v_inv.role) on conflict(family_id,user_id) do nothing;
     update public.family_invites set accepted_at=now() where id=v_inv.id;
   else
     insert into public.families(owner_id,name) values(v_uid,'Keluarga '||coalesce((select nullif(split_part(full_name,' ',1),'') from public.profiles where id=v_uid),'Saya')) returning id into v_family;
     insert into public.family_members(family_id,user_id,role) values(v_family,v_uid,'owner');
   end if;
 end if;
 if not exists(select 1 from public.accounts where family_id=v_family and is_active=true) then
   insert into public.accounts(family_id,owner_user_id,name,type,opening_balance,current_balance,is_active) values(v_family,v_uid,'Cash / Tunai','cash',0,0,true);
 end if;
 insert into public.wa_gateway_settings(family_id) values(v_family) on conflict(family_id) do nothing;
 insert into public.telegram_settings(family_id) values(v_family) on conflict(family_id) do nothing;
 perform public.seed_family_categories(v_family);
 return v_family;
end;$$;
revoke all on function public.bootstrap_my_workspace() from public;
grant execute on function public.bootstrap_my_workspace() to authenticated;
