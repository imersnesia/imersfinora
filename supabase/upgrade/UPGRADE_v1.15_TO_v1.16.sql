-- iMersFinora v1.16
-- Robust client data access: use SECURITY DEFINER RPCs for family context/accounts.
-- Safe to run repeatedly.

create or replace function public.get_my_context()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_family uuid;
  v_name text;
  v_currency text;
  v_role text;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  v_family:=public.bootstrap_my_workspace();
  select f.name,f.currency into v_name,v_currency from public.families f where f.id=v_family;
  select fm.role::text into v_role from public.family_members fm where fm.family_id=v_family and fm.user_id=v_uid;
  return jsonb_build_object('id',v_family,'name',v_name,'currency',coalesce(v_currency,'IDR'),'role',coalesce(v_role,'member'));
end;$$;
revoke all on function public.get_my_context() from public;
grant execute on function public.get_my_context() to authenticated;

create or replace function public.get_my_accounts()
returns setof public.accounts
language sql
stable
security definer
set search_path=public
as $$
  select a.* from public.accounts a
  where a.family_id in (select fm.family_id from public.family_members fm where fm.user_id=auth.uid())
    and a.is_active=true
  order by a.created_at;
$$;
revoke all on function public.get_my_accounts() from public;
grant execute on function public.get_my_accounts() to authenticated;

create or replace function public.add_my_account(p_name text,p_type public.account_type,p_opening_balance numeric default 0)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_uid uuid:=auth.uid(); v_family uuid; v_role public.app_role; v_id uuid; v_bal numeric:=coalesce(p_opening_balance,0);
begin
 if v_uid is null then raise exception 'Not authenticated'; end if;
 select fm.family_id,fm.role into v_family,v_role from public.family_members fm where fm.user_id=v_uid order by fm.joined_at limit 1;
 if v_family is null then v_family:=public.bootstrap_my_workspace(); v_role:='owner'; end if;
 if v_role not in ('owner','admin') then raise exception 'Only owner/admin can add accounts'; end if;
 if nullif(trim(p_name),'') is null then raise exception 'Account name is required'; end if;
 insert into public.accounts(family_id,owner_user_id,name,type,opening_balance,current_balance,is_active)
 values(v_family,v_uid,trim(p_name),p_type,v_bal,v_bal,true) returning id into v_id;
 return v_id;
end;$$;
revoke all on function public.add_my_account(text,public.account_type,numeric) from public;
grant execute on function public.add_my_account(text,public.account_type,numeric) to authenticated;
