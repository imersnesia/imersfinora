create extension if not exists pgcrypto;

create type public.app_role as enum ('owner','admin','member','viewer');
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
