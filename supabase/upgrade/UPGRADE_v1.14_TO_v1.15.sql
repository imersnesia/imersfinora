-- iMersFinora v1.15
-- FIX: PostgREST authenticated role lacked table privileges ("permission denied for table families").
-- Safe to run repeatedly.

grant usage on schema public to authenticated;

grant select, insert, update, delete on table public.profiles to authenticated;
grant select, insert, update, delete on table public.families to authenticated;
grant select, insert, update, delete on table public.family_members to authenticated;
grant select, insert, update, delete on table public.family_invites to authenticated;
grant select, insert, update, delete on table public.accounts to authenticated;
grant select, insert, update, delete on table public.categories to authenticated;
grant select, insert, update, delete on table public.transactions to authenticated;
grant select, insert, update, delete on table public.wallet_ledger to authenticated;
grant select, insert, update, delete on table public.wa_gateway_settings to authenticated;
grant select, insert, update, delete on table public.telegram_settings to authenticated;
grant select, insert, update, delete on table public.notification_recipients to authenticated;
grant select, insert, update, delete on table public.notifications to authenticated;
grant select, insert, update, delete on table public.audit_logs to authenticated;

-- Optional bot/receipt tables exist on v1.12+ installs.
do $$ begin
  if to_regclass('public.bot_inbox') is not null then
    execute 'grant select, insert, update, delete on table public.bot_inbox to authenticated';
  end if;
  if to_regclass('public.transaction_attachments') is not null then
    execute 'grant select, insert, update, delete on table public.transaction_attachments to authenticated';
  end if;
end $$;

-- Keep access constrained by the existing RLS policies; GRANT only allows PostgREST
-- to reach the tables so RLS can evaluate the logged-in family member.

grant execute on function public.bootstrap_my_workspace() to authenticated;
grant execute on function public.ensure_default_account(uuid) to authenticated;
grant execute on function public.create_my_family(text) to authenticated;
