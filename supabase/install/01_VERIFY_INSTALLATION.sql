-- iMersFinora v1.0 fresh-install verification
select table_name from information_schema.tables where table_schema='public' and table_name in ('profiles','families','family_members','accounts','categories','transactions','wallet_ledger','wa_gateway_settings','telegram_settings','notifications','audit_logs') order by table_name;
select schemaname, tablename, rowsecurity from pg_tables where schemaname='public' order by tablename;
select proname from pg_proc join pg_namespace n on n.oid=pronamespace where n.nspname='public' and proname in ('create_transaction','transfer_between_accounts') order by proname;
