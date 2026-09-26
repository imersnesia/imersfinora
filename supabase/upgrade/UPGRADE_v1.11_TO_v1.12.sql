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
