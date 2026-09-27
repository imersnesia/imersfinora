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
