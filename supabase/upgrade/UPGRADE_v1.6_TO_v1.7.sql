-- iMersFinora v1.7 Core Functional Upgrade
-- Run ONCE only on installations already using v1.6.

alter type public.app_role add value if not exists 'partner';
alter type public.app_role add value if not exists 'child';

create table if not exists public.family_invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  email text not null,
  role public.app_role not null default 'member',
  invited_by uuid not null references auth.users(id) on delete cascade,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  unique(family_id,email)
);
alter table public.family_invites enable row level security;
drop policy if exists family_invites_admin_manage on public.family_invites;
create policy family_invites_admin_manage on public.family_invites for all using(public.is_family_admin(family_id)) with check(public.is_family_admin(family_id));

create or replace function public.shares_family_with_user(p_user_id uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.family_members mine join public.family_members theirs on theirs.family_id=mine.family_id where mine.user_id=auth.uid() and theirs.user_id=p_user_id);
$$;
drop policy if exists profiles_family_select on public.profiles;
create policy profiles_family_select on public.profiles for select using(id=auth.uid() or public.shares_family_with_user(id));

create or replace function public.seed_family_categories(p_family uuid) returns void
language plpgsql security definer set search_path=public as $$ begin
 insert into public.categories(family_id,name,kind,icon,color) values
 (p_family,'Gaji','income','💰','#49D69C'),(p_family,'Bonus','income','🎁','#6B7CFF'),(p_family,'Makanan','expense','🍜','#FFB65C'),
 (p_family,'Belanja','expense','🛍️','#FF6F91'),(p_family,'Transport','expense','🚗','#59B7FF'),(p_family,'Tagihan','expense','🧾','#9C7BFF'),
 (p_family,'Pendidikan','expense','🎓','#4ED2C2'),(p_family,'Kesehatan','expense','❤️','#FF6B6B'),(p_family,'Lainnya','both','✨','#A0A8B8')
 on conflict(family_id,name) do nothing;
end; $$;

create or replace function public.invite_family_member(p_family_id uuid,p_email text,p_role public.app_role default 'member') returns text
language plpgsql security definer set search_path=public as $$
declare v_target uuid; v_email text:=lower(trim(p_email));
begin
 if not public.is_family_admin(p_family_id) then raise exception 'Only owner/admin can invite members'; end if;
 if p_role='owner' then raise exception 'Owner role cannot be invited'; end if;
 select id into v_target from auth.users where lower(email)=v_email limit 1;
 if v_target is not null then
   insert into public.profiles(id,full_name,phone) select id,coalesce(raw_user_meta_data->>'full_name',raw_user_meta_data->>'name',split_part(email,'@',1)),phone from auth.users where id=v_target on conflict(id) do nothing;
   insert into public.family_members(family_id,user_id,role) values(p_family_id,v_target,p_role) on conflict(family_id,user_id) do update set role=excluded.role;
   return 'added';
 end if;
 insert into public.family_invites(family_id,email,role,invited_by) values(p_family_id,v_email,p_role,auth.uid()) on conflict(family_id,email) do update set role=excluded.role,invited_by=excluded.invited_by,accepted_at=null;
 return 'invited';
end; $$;

create or replace function public.bootstrap_my_workspace() returns uuid
language plpgsql security definer set search_path=public as $$
declare v_family uuid; v_uid uuid:=auth.uid(); v_email text; v_inv record;
begin
 if v_uid is null then raise exception 'Not authenticated'; end if;
 select lower(email) into v_email from auth.users where id=v_uid;
 insert into public.profiles(id,full_name,phone) select u.id,coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name',split_part(u.email,'@',1)),u.phone from auth.users u where u.id=v_uid on conflict(id) do nothing;
 select family_id into v_family from public.family_members where user_id=v_uid order by joined_at limit 1;
 if v_family is null then
   select * into v_inv from public.family_invites where email=v_email and accepted_at is null order by created_at limit 1;
   if found then
     v_family:=v_inv.family_id;
     insert into public.family_members(family_id,user_id,role) values(v_family,v_uid,v_inv.role) on conflict(family_id,user_id) do nothing;
     update public.family_invites set accepted_at=now() where id=v_inv.id;
   else
     insert into public.families(owner_id,name) values(v_uid,'Keluarga '||coalesce((select nullif(split_part(full_name,' ',1),'') from public.profiles where id=v_uid),'Saya')) returning id into v_family;
     insert into public.family_members(family_id,user_id,role) values(v_family,v_uid,'owner');
     insert into public.accounts(family_id,owner_user_id,name,type) values(v_family,v_uid,'Dompet Utama','wallet');
     insert into public.wa_gateway_settings(family_id) values(v_family) on conflict(family_id) do nothing;
     insert into public.telegram_settings(family_id) values(v_family) on conflict(family_id) do nothing;
   end if;
 end if;
 perform public.seed_family_categories(v_family);
 return v_family;
end; $$;

revoke all on function public.invite_family_member(uuid,text,public.app_role) from public;
grant execute on function public.invite_family_member(uuid,text,public.app_role) to authenticated;
revoke all on function public.bootstrap_my_workspace() from public;
grant execute on function public.bootstrap_my_workspace() to authenticated;
