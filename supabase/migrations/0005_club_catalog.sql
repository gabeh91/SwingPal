-- Public catalog downloads; all writes, sources, history and job state are service-only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('club-catalog', 'club-catalog', true, 2000000, array['application/json']),
       ('club-catalog-admin', 'club-catalog-admin', false, 2000000, array['application/json'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create table public.club_catalog_refresh_lock (
  id boolean primary key default true check (id),
  run_id uuid,
  expires_at timestamptz not null default '-infinity'
);
insert into public.club_catalog_refresh_lock (id) values (true);
create table public.club_catalog_runs (
  id uuid primary key,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null check (status in ('running', 'published', 'failed')),
  detail jsonb not null default '{}'::jsonb
);
alter table public.club_catalog_refresh_lock enable row level security;
alter table public.club_catalog_runs enable row level security;
revoke all on public.club_catalog_refresh_lock, public.club_catalog_runs from anon, authenticated;
grant all on public.club_catalog_refresh_lock, public.club_catalog_runs to service_role;

create function public.begin_club_catalog_refresh(p_run_id uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  update public.club_catalog_refresh_lock set run_id = p_run_id, expires_at = now() + interval '5 minutes'
  where id and expires_at < now();
  if not found then return false; end if;
  update public.club_catalog_runs set status = 'failed', finished_at = now(), detail = '{"error":"Worker lease expired"}'
  where status = 'running' and started_at < now() - interval '5 minutes';
  insert into public.club_catalog_runs (id, status) values (p_run_id, 'running');
  return true;
end;
$$;
create function public.finish_club_catalog_refresh(p_run_id uuid, p_status text, p_detail jsonb) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_status not in ('published', 'failed') then raise exception 'Invalid completion status'; end if;
  update public.club_catalog_runs set status = p_status, finished_at = now(), detail = p_detail where id = p_run_id;
  update public.club_catalog_refresh_lock set expires_at = '-infinity', run_id = null where run_id = p_run_id;
end;
$$;
revoke all on function public.begin_club_catalog_refresh(uuid), public.finish_club_catalog_refresh(uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.begin_club_catalog_refresh(uuid), public.finish_club_catalog_refresh(uuid,text,jsonb) to service_role;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
-- Vault is installed on hosted Supabase; no credential is checked into source control.
do $$ begin
  if not exists (select 1 from vault.secrets where name = 'club_catalog_cron_secret') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'club_catalog_cron_secret');
  end if;
end $$;

-- Deployment sets the project URL in Vault and enables the job after a successful initial refresh.
create function public.invoke_club_catalog_refresh() returns bigint
language plpgsql security definer set search_path = '' as $$
declare project_url text; token text;
begin
  select decrypted_secret into project_url from vault.decrypted_secrets where name = 'club_catalog_project_url';
  select decrypted_secret into token from vault.decrypted_secrets where name = 'club_catalog_cron_secret';
  if project_url is null or token is null then raise exception 'Catalog scheduler is not configured'; end if;
  return net.http_post(
    url := project_url || '/functions/v1/refresh-club-catalog',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-catalog-secret', token),
    body := '{}'::jsonb, timeout_milliseconds := 90000
  );
end;
$$;
revoke all on function public.invoke_club_catalog_refresh() from public, anon, authenticated;
grant execute on function public.invoke_club_catalog_refresh() to service_role;
