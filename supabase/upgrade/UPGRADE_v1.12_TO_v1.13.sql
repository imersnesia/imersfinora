-- iMersFinora v1.13 - account recovery hardening
-- Safe to run once or repeatedly.
create or replace function public.ensure_default_account(p_family_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'Not authenticated'; end if;
 if not exists(select 1 from public.family_members where family_id=p_family_id and user_id=auth.uid()) then raise exception 'Forbidden'; end if;
 select id into v_id from public.accounts where family_id=p_family_id and is_active=true order by created_at limit 1;
 if v_id is null then
   insert into public.accounts(family_id,owner_user_id,name,type,opening_balance,current_balance,is_active)
   values(p_family_id,auth.uid(),'Cash / Tunai','cash',0,0,true)
   returning id into v_id;
 end if;
 return v_id;
end;$$;
revoke all on function public.ensure_default_account(uuid) from public;
grant execute on function public.ensure_default_account(uuid) to authenticated;
