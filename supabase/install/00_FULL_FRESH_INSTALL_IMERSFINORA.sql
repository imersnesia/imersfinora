create extension if not exists pgcrypto;

create type public.app_role as enum ('owner','admin','partner','member','child','viewer');
create type public.account_type as enum ('cash','bank','ewallet','wallet','other');
create type public.transaction_type as enum ('income','expense','transfer_in','transfer_out','adjustment');
create type public.transaction_status as enum ('pending','completed','failed','cancelled');
create type public.notification_channel as enum ('whatsapp','telegram');
create type public.notification_status as enum ('queued','sent','failed','skipped');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  theme_id text not null default 'finora',
  appearance_mode text not null default 'system' check (appearance_mode in ('light','dark','system')),
  custom_primary text,
  custom_secondary text,
  custom_accent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.families (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  name text not null default 'My Family',
  currency text not null default 'IDR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null default 'member',
  joined_at timestamptz not null default now(),
  unique (family_id, user_id)
);

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  owner_user_id uuid references auth.users(id) on delete set null,
  name text not null,
  type public.account_type not null default 'wallet',
  currency text not null default 'IDR',
  opening_balance numeric(20,2) not null default 0,
  current_balance numeric(20,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('income','expense','both')),
  icon text,
  color text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (family_id, name)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete restrict,
  account_id uuid not null references public.accounts(id) on delete restrict,
  category_id uuid references public.categories(id) on delete set null,
  created_by uuid not null references auth.users(id) on delete restrict,
  type public.transaction_type not null,
  amount numeric(20,2) not null check (amount > 0),
  description text,
  note text,
  reference_no text,
  receipt_url text,
  occurred_at timestamptz not null default now(),
  status public.transaction_status not null default 'completed',
  transfer_group_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete restrict,
  account_id uuid not null references public.accounts(id) on delete restrict,
  transaction_id uuid not null references public.transactions(id) on delete restrict,
  debit numeric(20,2) not null default 0 check (debit >= 0),
  credit numeric(20,2) not null default 0 check (credit >= 0),
  balance_after numeric(20,2) not null,
  created_at timestamptz not null default now(),
  check ((debit = 0) <> (credit = 0))
);

create table public.wa_gateway_settings (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null unique references public.families(id) on delete cascade,
  provider text not null default 'fonnte' check (provider in ('fonnte','starsender')),
  enabled boolean not null default false,
  endpoint text,
  api_key_encrypted text,
  sender_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.telegram_settings (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null unique references public.families(id) on delete cascade,
  enabled boolean not null default false,
  bot_username text,
  bot_token_encrypted text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notification_recipients (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  phone text,
  telegram_chat_id text,
  whatsapp_enabled boolean not null default true,
  telegram_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (family_id, user_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  transaction_id uuid references public.transactions(id) on delete set null,
  channel public.notification_channel not null,
  recipient text not null,
  message text not null,
  status public.notification_status not null default 'queued',
  provider text,
  provider_message_id text,
  error_message text,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id) on delete set null,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_family_members_user on public.family_members(user_id);
create index idx_accounts_family on public.accounts(family_id);
create index idx_categories_family on public.categories(family_id);
create index idx_transactions_family_date on public.transactions(family_id, occurred_at desc);
create index idx_transactions_account_date on public.transactions(account_id, occurred_at desc);
create index idx_ledger_account_date on public.wallet_ledger(account_id, created_at desc);
create index idx_notifications_family_date on public.notifications(family_id, created_at desc);
create index idx_audit_family_date on public.audit_logs(family_id, created_at desc);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create trigger profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
create trigger families_updated before update on public.families for each row execute function public.set_updated_at();
create trigger accounts_updated before update on public.accounts for each row execute function public.set_updated_at();
create trigger wa_settings_updated before update on public.wa_gateway_settings for each row execute function public.set_updated_at();
create trigger telegram_settings_updated before update on public.telegram_settings for each row execute function public.set_updated_at();
create trigger notification_recipients_updated before update on public.notification_recipients for each row execute function public.set_updated_at();
create trigger transactions_updated before update on public.transactions for each row execute function public.set_updated_at();

create or replace function public.is_family_member(p_family_id uuid, p_user_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.family_members fm where fm.family_id=p_family_id and fm.user_id=p_user_id);
$$;

create or replace function public.is_family_admin(p_family_id uuid, p_user_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.family_members fm where fm.family_id=p_family_id and fm.user_id=p_user_id and fm.role in ('owner','admin'));
$$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, full_name, phone) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'), new.phone) on conflict (id) do nothing;
  return new;
end; $$;

create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.create_my_family(p_name text default 'My Family') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_family uuid;
begin
  select fm.family_id into v_family from public.family_members fm where fm.user_id=auth.uid() order by fm.joined_at limit 1;
  if v_family is not null then return v_family; end if;
  insert into public.families(owner_id,name) values(auth.uid(),coalesce(nullif(trim(p_name),''),'My Family')) returning id into v_family;
  insert into public.family_members(family_id,user_id,role) values(v_family,auth.uid(),'owner');
  insert into public.wa_gateway_settings(family_id) values(v_family);
  insert into public.telegram_settings(family_id) values(v_family);
  insert into public.accounts(family_id,owner_user_id,name,type) values(v_family,auth.uid(),'Main Wallet','wallet');
  return v_family;
end; $$;

create or replace function public.post_transaction(
  p_family_id uuid, p_account_id uuid, p_category_id uuid, p_type public.transaction_type,
  p_amount numeric, p_description text default null, p_note text default null,
  p_occurred_at timestamptz default now(), p_metadata jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_tx uuid; v_balance numeric; v_delta numeric;
begin
  if not public.is_family_member(p_family_id) then raise exception 'Not a family member'; end if;
  if p_amount <= 0 then raise exception 'Amount must be positive'; end if;
  if not exists(select 1 from public.accounts where id=p_account_id and family_id=p_family_id and is_active) then raise exception 'Invalid account'; end if;
  v_delta := case when p_type in ('income','transfer_in') then p_amount else -p_amount end;
  insert into public.transactions(family_id,account_id,category_id,created_by,type,amount,description,note,occurred_at,metadata)
  values(p_family_id,p_account_id,p_category_id,auth.uid(),p_type,p_amount,p_description,p_note,p_occurred_at,p_metadata) returning id into v_tx;
  update public.accounts set current_balance=current_balance+v_delta where id=p_account_id returning current_balance into v_balance;
  insert into public.wallet_ledger(family_id,account_id,transaction_id,debit,credit,balance_after)
  values(p_family_id,p_account_id,v_tx,case when v_delta<0 then p_amount else 0 end,case when v_delta>0 then p_amount else 0 end,v_balance);
  insert into public.audit_logs(family_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(p_family_id,auth.uid(),'transaction.created','transaction',v_tx,jsonb_build_object('type',p_type,'amount',p_amount));
  return v_tx;
end; $$;

create or replace function public.transfer_money(
  p_family_id uuid,p_from_account uuid,p_to_account uuid,p_amount numeric,p_note text default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_group uuid:=gen_random_uuid(); v_out uuid; v_in uuid;
begin
  if p_from_account=p_to_account then raise exception 'Accounts must be different'; end if;
  if not public.is_family_member(p_family_id) then raise exception 'Not a family member'; end if;
  if p_amount<=0 then raise exception 'Amount must be positive'; end if;
  perform 1 from public.accounts where id=p_from_account and family_id=p_family_id and is_active for update;
  if not found then raise exception 'Invalid source account'; end if;
  perform 1 from public.accounts where id=p_to_account and family_id=p_family_id and is_active for update;
  if not found then raise exception 'Invalid destination account'; end if;
  if (select current_balance from public.accounts where id=p_from_account) < p_amount then raise exception 'Insufficient balance'; end if;
  v_out:=public.post_transaction(p_family_id,p_from_account,null,'transfer_out',p_amount,'Transfer',p_note,now(),jsonb_build_object('transfer_group_id',v_group,'to_account',p_to_account));
  v_in:=public.post_transaction(p_family_id,p_to_account,null,'transfer_in',p_amount,'Transfer',p_note,now(),jsonb_build_object('transfer_group_id',v_group,'from_account',p_from_account));
  update public.transactions set transfer_group_id=v_group where id in(v_out,v_in);
  return v_group;
end; $$;

alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.wa_gateway_settings enable row level security;
alter table public.telegram_settings enable row level security;
alter table public.notification_recipients enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_self on public.profiles for all using(id=auth.uid()) with check(id=auth.uid());
create policy families_member_select on public.families for select using(public.is_family_member(id));
create policy families_owner_manage on public.families for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy family_members_member_select on public.family_members for select using(public.is_family_member(family_id));
create policy family_members_admin_manage on public.family_members for all using(public.is_family_admin(family_id)) with check(public.is_family_admin(family_id));
create policy accounts_member_select on public.accounts for select using(public.is_family_member(family_id));
create policy accounts_admin_manage on public.accounts for all using(public.is_family_admin(family_id)) with check(public.is_family_admin(family_id));
create policy categories_member_select on public.categories for select using(public.is_family_member(family_id));
create policy categories_admin_manage on public.categories for all using(public.is_family_admin(family_id)) with check(public.is_family_admin(family_id));
create policy transactions_member_select on public.transactions for select using(public.is_family_member(family_id));
create policy ledger_member_select on public.wallet_ledger for select using(public.is_family_member(family_id));
create policy wa_admin_manage on public.wa_gateway_settings for all using(public.is_family_admin(family_id)) with check(public.is_family_admin(family_id));
create policy telegram_admin_manage on public.telegram_settings for all using(public.is_family_admin(family_id)) with check(public.is_family_admin(family_id));
create policy recipients_member_select on public.notification_recipients for select using(public.is_family_member(family_id));
create policy recipients_self_manage on public.notification_recipients for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy notifications_member_select on public.notifications for select using(public.is_family_member(family_id));
create policy audit_member_select on public.audit_logs for select using(public.is_family_member(family_id));

revoke all on function public.post_transaction(uuid,uuid,uuid,public.transaction_type,numeric,text,text,timestamptz,jsonb) from public;
revoke all on function public.transfer_money(uuid,uuid,uuid,numeric,text) from public;
grant execute on function public.post_transaction(uuid,uuid,uuid,public.transaction_type,numeric,text,text,timestamptz,jsonb) to authenticated;
grant execute on function public.transfer_money(uuid,uuid,uuid,numeric,text) to authenticated;
grant execute on function public.create_my_family(text) to authenticated;
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
-- iMersFinora v1.7 Core Functional Upgrade
-- Run ONCE only on installations already using v1.6.

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
-- iMersFinora v1.12: optional chat-bot + receipt/photo support + account recovery
alter table public.wa_gateway_settings add column if not exists bot_enabled boolean not null default false;
alter table public.wa_gateway_settings add column if not exists webhook_secret text;
alter table public.telegram_settings add column if not exists bot_enabled boolean not null default false;
alter table public.telegram_settings add column if not exists webhook_secret text;

create table if not exists public.bot_inbox (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  channel public.notification_channel not null,
  external_sender text not null,
  message_text text,
  media_url text,
  status text not null default 'received' check(status in ('received','pending_amount','processed','ignored','failed')),
  transaction_id uuid references public.transactions(id) on delete set null,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_bot_inbox_family_date on public.bot_inbox(family_id,created_at desc);
alter table public.bot_inbox enable row level security;
drop policy if exists bot_inbox_member_select on public.bot_inbox;
create policy bot_inbox_member_select on public.bot_inbox for select using(public.is_family_member(family_id));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('finora-receipts','finora-receipts',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists finora_receipts_select on storage.objects;
create policy finora_receipts_select on storage.objects for select to authenticated using(
 bucket_id='finora-receipts' and public.is_family_member((storage.foldername(name))[1]::uuid)
);
drop policy if exists finora_receipts_insert on storage.objects;
create policy finora_receipts_insert on storage.objects for insert to authenticated with check(
 bucket_id='finora-receipts' and public.is_family_member((storage.foldername(name))[1]::uuid)
);
drop policy if exists finora_receipts_delete on storage.objects;
create policy finora_receipts_delete on storage.objects for delete to authenticated using(
 bucket_id='finora-receipts' and public.is_family_member((storage.foldername(name))[1]::uuid)
);

create or replace function public.ensure_default_account(p_family_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 if not public.is_family_member(p_family_id) then raise exception 'Forbidden'; end if;
 select id into v_id from public.accounts where family_id=p_family_id and is_active order by created_at limit 1;
 if v_id is null then
   insert into public.accounts(family_id,owner_user_id,name,type) values(p_family_id,auth.uid(),'Cash / Tunai','cash') returning id into v_id;
 end if;
 return v_id;
end;$$;
grant execute on function public.ensure_default_account(uuid) to authenticated;

create or replace function public.bot_post_transaction(p_family_id uuid,p_user_id uuid,p_account_id uuid,p_type public.transaction_type,p_amount numeric,p_description text default null,p_receipt_url text default null,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_tx uuid; v_delta numeric; v_balance numeric;
begin
 if p_type not in ('income','expense') then raise exception 'Unsupported bot transaction type'; end if;
 if p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
 if not exists(select 1 from public.family_members where family_id=p_family_id and user_id=p_user_id) then raise exception 'User is not a family member'; end if;
 perform 1 from public.accounts where id=p_account_id and family_id=p_family_id and is_active for update;
 if not found then raise exception 'Invalid account'; end if;
 v_delta:=case when p_type='income' then p_amount else -p_amount end;
 insert into public.transactions(family_id,account_id,created_by,type,amount,description,receipt_url,metadata)
 values(p_family_id,p_account_id,p_user_id,p_type,p_amount,p_description,p_receipt_url,p_metadata) returning id into v_tx;
 update public.accounts set current_balance=current_balance+v_delta where id=p_account_id returning current_balance into v_balance;
 insert into public.wallet_ledger(family_id,account_id,transaction_id,debit,credit,balance_after)
 values(p_family_id,p_account_id,v_tx,case when v_delta<0 then p_amount else 0 end,case when v_delta>0 then p_amount else 0 end,v_balance);
 return v_tx;
end;$$;
revoke all on function public.bot_post_transaction(uuid,uuid,uuid,public.transaction_type,numeric,text,text,jsonb) from public;
grant execute on function public.bot_post_transaction(uuid,uuid,uuid,public.transaction_type,numeric,text,text,jsonb) to service_role;
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

-- v1.15 PostgREST privileges (RLS remains authoritative)
grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.profiles, public.families, public.family_members, public.family_invites, public.accounts, public.categories, public.transactions, public.wallet_ledger, public.wa_gateway_settings, public.telegram_settings, public.notification_recipients, public.notifications, public.audit_logs to authenticated;
grant select, insert, update, delete on table public.bot_inbox, public.transaction_attachments to authenticated;
grant execute on function public.bootstrap_my_workspace() to authenticated;
grant execute on function public.ensure_default_account(uuid) to authenticated;
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
-- iMersFinora v1.18: dynamic PWA branding + deduplicated image library
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

-- ============================================================
-- iMersFinora v1.18 SELF-VERIFICATION (FRESH INSTALL)
-- Fresh clients run THIS ONE FILE ONLY. If anything required is
-- missing, this block raises an exception instead of silently passing.
-- ============================================================
do $$
declare
  missing text[] := array[]::text[];
  obj text;
begin
  foreach obj in array array[
    'profiles','families','family_members','accounts','categories','transactions',
    'wallet_ledger','wa_gateway_settings','telegram_settings','notification_recipients',
    'notifications','audit_logs','family_invites','bot_inbox','app_branding','brand_assets'
  ] loop
    if to_regclass('public.' || obj) is null then missing := array_append(missing, 'table:' || obj); end if;
  end loop;

  if to_regprocedure('public.bootstrap_my_workspace()') is null then missing := array_append(missing,'function:bootstrap_my_workspace'); end if;
  if to_regprocedure('public.get_my_context()') is null then missing := array_append(missing,'function:get_my_context'); end if;
  if to_regprocedure('public.get_my_accounts()') is null then missing := array_append(missing,'function:get_my_accounts'); end if;
  if to_regprocedure('public.add_my_account(text,public.account_type,numeric)') is null then missing := array_append(missing,'function:add_my_account'); end if;
  if to_regprocedure('public.ensure_default_account(uuid)') is null then missing := array_append(missing,'function:ensure_default_account'); end if;
  if to_regprocedure('public.post_transaction(uuid,uuid,public.transaction_type,numeric,uuid,text,timestamptz,text,jsonb)') is null then
    -- signature may evolve; confirm at least one public.post_transaction exists
    if not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='post_transaction') then missing := array_append(missing,'function:post_transaction'); end if;
  end if;
  if not exists(select 1 from storage.buckets where id='finora-branding') then missing := array_append(missing,'storage-bucket:finora-branding'); end if;

  if cardinality(missing) > 0 then
    raise exception 'iMersFinora fresh install verification FAILED. Missing: %', array_to_string(missing, ', ');
  end if;

  raise notice 'iMersFinora v1.18 fresh install OK - schema, RPC and branding storage verified.';
end $$;

-- iMersFinora v1.19 - Family activation links + Family CRUD
alter table public.family_invites add column if not exists token text;
alter table public.family_invites add column if not exists expires_at timestamptz;
alter table public.family_invites add column if not exists cancelled_at timestamptz;
create unique index if not exists family_invites_token_uidx on public.family_invites(token) where token is not null;

drop function if exists public.invite_family_member(uuid,text,public.app_role);

create or replace function public.invite_family_member(p_family_id uuid,p_email text,p_role public.app_role default 'member') returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare v_target uuid; v_email text:=lower(trim(p_email)); v_token text; v_id uuid;
begin
 if not public.is_family_admin(p_family_id) then raise exception 'Only owner/admin can invite members'; end if;
 if p_role='owner' then raise exception 'Owner role cannot be invited'; end if;
 if v_email='' then raise exception 'Email wajib diisi'; end if;
 select id into v_target from auth.users where lower(email)=v_email limit 1;
 if v_target is not null then
   insert into public.profiles(id,full_name,phone) select id,coalesce(raw_user_meta_data->>'full_name',raw_user_meta_data->>'name',split_part(email,'@',1)),phone from auth.users where id=v_target on conflict(id) do nothing;
   insert into public.family_members(family_id,user_id,role) values(p_family_id,v_target,p_role) on conflict(family_id,user_id) do update set role=excluded.role;
   return jsonb_build_object('status','added','email',v_email,'role',p_role::text);
 end if;
 v_token:=encode(gen_random_bytes(24),'hex');
 insert into public.family_invites(family_id,email,role,invited_by,token,expires_at,accepted_at,cancelled_at)
 values(p_family_id,v_email,p_role,auth.uid(),v_token,now()+interval '7 days',null,null)
 on conflict(family_id,email) do update set role=excluded.role,invited_by=excluded.invited_by,token=excluded.token,expires_at=excluded.expires_at,accepted_at=null,cancelled_at=null
 returning id into v_id;
 return jsonb_build_object('status','invited','id',v_id,'email',v_email,'role',p_role::text,'token',v_token,'expires_at',now()+interval '7 days');
end; $$;

create or replace function public.get_family_invite(p_token text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v record;
begin
 select i.id,i.email,i.role,i.expires_at,i.accepted_at,i.cancelled_at,f.name family_name into v
 from public.family_invites i join public.families f on f.id=i.family_id where i.token=p_token limit 1;
 if not found then return jsonb_build_object('valid',false,'reason','not_found'); end if;
 if v.cancelled_at is not null then return jsonb_build_object('valid',false,'reason','cancelled'); end if;
 if v.accepted_at is not null then return jsonb_build_object('valid',false,'reason','used'); end if;
 if v.expires_at is null or v.expires_at < now() then return jsonb_build_object('valid',false,'reason','expired'); end if;
 return jsonb_build_object('valid',true,'email',v.email,'role',v.role::text,'family_name',v.family_name,'expires_at',v.expires_at);
end; $$;

create or replace function public.accept_family_invite(p_token text) returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare v record; v_uid uuid:=auth.uid(); v_email text;
begin
 if v_uid is null then raise exception 'Silakan login/aktivasi akun terlebih dahulu'; end if;
 select lower(email) into v_email from auth.users where id=v_uid;
 select * into v from public.family_invites where token=p_token for update;
 if not found then raise exception 'Link undangan tidak valid'; end if;
 if v.cancelled_at is not null then raise exception 'Undangan sudah dibatalkan'; end if;
 if v.accepted_at is not null then raise exception 'Undangan sudah digunakan'; end if;
 if v.expires_at is null or v.expires_at < now() then raise exception 'Undangan sudah kedaluwarsa'; end if;
 if lower(v.email)<>v_email then raise exception 'Email akun tidak sesuai dengan undangan'; end if;
 insert into public.profiles(id,full_name,phone) select id,coalesce(raw_user_meta_data->>'full_name',raw_user_meta_data->>'name',split_part(email,'@',1)),phone from auth.users where id=v_uid on conflict(id) do nothing;
 insert into public.family_members(family_id,user_id,role) values(v.family_id,v_uid,v.role) on conflict(family_id,user_id) do update set role=excluded.role;
 update public.family_invites set accepted_at=now() where id=v.id;
 return jsonb_build_object('ok',true,'family_id',v.family_id,'role',v.role::text);
end; $$;

create or replace function public.list_family_admin(p_family_id uuid) returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare v_members jsonb; v_invites jsonb;
begin
 if not public.is_family_member(p_family_id) then raise exception 'Access denied'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',fm.id,'user_id',fm.user_id,'role',fm.role::text,'joined_at',fm.joined_at,'full_name',p.full_name,'avatar_url',p.avatar_url,'email',u.email) order by fm.joined_at),'[]'::jsonb)
 into v_members from public.family_members fm left join public.profiles p on p.id=fm.user_id left join auth.users u on u.id=fm.user_id where fm.family_id=p_family_id;
 if public.is_family_admin(p_family_id) then
   select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'role',i.role::text,'token',i.token,'expires_at',i.expires_at,'accepted_at',i.accepted_at,'cancelled_at',i.cancelled_at,'created_at',i.created_at) order by i.created_at desc),'[]'::jsonb)
   into v_invites from public.family_invites i where i.family_id=p_family_id and i.accepted_at is null and i.cancelled_at is null;
 else v_invites:='[]'::jsonb; end if;
 return jsonb_build_object('members',v_members,'invites',v_invites);
end; $$;

create or replace function public.update_family_member(p_family_id uuid,p_user_id uuid,p_role public.app_role,p_full_name text default null) returns void
language plpgsql security definer set search_path=public as $$
declare v_current public.app_role;
begin
 if not public.is_family_admin(p_family_id) then raise exception 'Only owner/admin can manage members'; end if;
 select role into v_current from public.family_members where family_id=p_family_id and user_id=p_user_id;
 if v_current is null then raise exception 'Member tidak ditemukan'; end if;
 if v_current='owner' then raise exception 'Owner utama tidak dapat diubah dari menu anggota'; end if;
 if p_role='owner' then raise exception 'Gunakan proses transfer owner untuk mengganti owner'; end if;
 update public.family_members set role=p_role where family_id=p_family_id and user_id=p_user_id;
 if p_full_name is not null and trim(p_full_name)<>'' then update public.profiles set full_name=trim(p_full_name) where id=p_user_id; end if;
end; $$;

create or replace function public.remove_family_member(p_family_id uuid,p_user_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare v_role public.app_role;
begin
 if not public.is_family_admin(p_family_id) then raise exception 'Only owner/admin can delete members'; end if;
 select role into v_role from public.family_members where family_id=p_family_id and user_id=p_user_id;
 if v_role is null then raise exception 'Member tidak ditemukan'; end if;
 if v_role='owner' then raise exception 'Owner utama tidak dapat dihapus'; end if;
 delete from public.family_members where family_id=p_family_id and user_id=p_user_id;
end; $$;

create or replace function public.cancel_family_invite(p_family_id uuid,p_invite_id uuid) returns void
language plpgsql security definer set search_path=public as $$ begin
 if not public.is_family_admin(p_family_id) then raise exception 'Only owner/admin can manage invites'; end if;
 update public.family_invites set cancelled_at=now() where id=p_invite_id and family_id=p_family_id and accepted_at is null;
end; $$;

create or replace function public.regenerate_family_invite(p_family_id uuid,p_invite_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_token text:=encode(gen_random_bytes(24),'hex'); v record;
begin
 if not public.is_family_admin(p_family_id) then raise exception 'Only owner/admin can manage invites'; end if;
 update public.family_invites set token=v_token,expires_at=now()+interval '7 days',cancelled_at=null where id=p_invite_id and family_id=p_family_id and accepted_at is null returning email,role,expires_at into v;
 if not found then raise exception 'Undangan tidak ditemukan'; end if;
 return jsonb_build_object('token',v_token,'email',v.email,'role',v.role::text,'expires_at',v.expires_at);
end; $$;

revoke all on function public.invite_family_member(uuid,text,public.app_role) from public;
grant execute on function public.invite_family_member(uuid,text,public.app_role) to authenticated;
revoke all on function public.get_family_invite(text) from public;
grant execute on function public.get_family_invite(text) to anon,authenticated;
revoke all on function public.accept_family_invite(text) from public;
grant execute on function public.accept_family_invite(text) to authenticated;
grant execute on function public.list_family_admin(uuid) to authenticated;
grant execute on function public.update_family_member(uuid,uuid,public.app_role,text) to authenticated;
grant execute on function public.remove_family_member(uuid,uuid) to authenticated;
grant execute on function public.cancel_family_invite(uuid,uuid) to authenticated;
grant execute on function public.regenerate_family_invite(uuid,uuid) to authenticated;

-- v1.21: categories are database-driven and reports read existing transaction data.
-- Fresh install requires no additional SQL beyond this master file.
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
