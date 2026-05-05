-- =============================================================================
-- SwingPal — initial Supabase schema (auth + bags + rounds + follow graph)
-- Run this in Supabase Studio → SQL Editor (one-shot). Idempotent where possible.
-- =============================================================================

-- ---- extensions -------------------------------------------------------------
create extension if not exists pgcrypto;

-- ---- profiles (1:1 mirror of auth.users) ------------------------------------
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    username text unique,
    display_name text,
    avatar_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Auto-create a profile row when a new auth.users row appears.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, display_name)
    values (new.id, coalesce(new.raw_user_meta_data->>'display_name', new.email))
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---- bags (one row per user, clubs as JSONB) --------------------------------
create table if not exists public.bags (
    user_id uuid primary key references auth.users(id) on delete cascade,
    clubs jsonb not null default '[]'::jsonb,
    updated_at timestamptz not null default now()
);

-- ---- handicap snapshot ------------------------------------------------------
create table if not exists public.handicaps (
    user_id uuid primary key references auth.users(id) on delete cascade,
    manual_index numeric,
    updated_at timestamptz not null default now()
);

-- ---- follow graph -----------------------------------------------------------
create table if not exists public.follows (
    follower_id uuid not null references auth.users(id) on delete cascade,
    followee_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (follower_id, followee_id),
    check (follower_id <> followee_id)
);

create index if not exists follows_followee_idx on public.follows (followee_id);

-- ---- rounds (RoundHistorySummary) -------------------------------------------
create table if not exists public.rounds (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    course_name text not null,
    status text not null check (status in ('unfinished', 'finished')),
    hole_number int not null,
    total_hole_count int not null,
    player_count int not null default 1,
    total_strokes int not null default 0,
    completed_hole_count int not null default 0,
    total_putts int not null default 0,
    total_penalties int not null default 0,
    is_shared boolean not null default true,
    payload jsonb,
    updated_at timestamptz not null
);

create index if not exists rounds_user_idx on public.rounds (user_id, updated_at desc);

-- =============================================================================
-- Row Level Security
-- =============================================================================

alter table public.profiles enable row level security;
alter table public.bags enable row level security;
alter table public.handicaps enable row level security;
alter table public.follows enable row level security;
alter table public.rounds enable row level security;

-- profiles: every authed user can read; only owner can write.
drop policy if exists "profiles read by authenticated" on public.profiles;
create policy "profiles read by authenticated" on public.profiles
    for select using (auth.role() = 'authenticated');

drop policy if exists "profiles owner write" on public.profiles;
create policy "profiles owner write" on public.profiles
    for all using (auth.uid() = id) with check (auth.uid() = id);

-- bags: only owner.
drop policy if exists "bags owner crud" on public.bags;
create policy "bags owner crud" on public.bags
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- handicaps: only owner.
drop policy if exists "handicaps owner crud" on public.handicaps;
create policy "handicaps owner crud" on public.handicaps
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- follows: follower owns the row.
drop policy if exists "follows owner crud" on public.follows;
create policy "follows owner crud" on public.follows
    for all using (auth.uid() = follower_id) with check (auth.uid() = follower_id);

drop policy if exists "follows visible to either party" on public.follows;
create policy "follows visible to either party" on public.follows
    for select using (auth.uid() in (follower_id, followee_id));

-- rounds:
--   * owner: full CRUD on own rounds
--   * other authed users: SELECT when round is shared AND they follow the owner
drop policy if exists "rounds owner crud" on public.rounds;
create policy "rounds owner crud" on public.rounds
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "rounds shared with followers" on public.rounds;
create policy "rounds shared with followers" on public.rounds
    for select using (
        is_shared = true
        and exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid()
              and f.followee_id = rounds.user_id
        )
    );

-- =============================================================================
-- Storage: community course bucket
--   * Bucket is *not* public, but every authenticated user (including
--     `authenticated` anon-key sessions) can read & write to it.
--   * Anonymous web visitors (no JWT at all) cannot list or download.
-- =============================================================================

insert into storage.buckets (id, name, public)
values ('courses', 'courses', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists "courses readable by authed" on storage.objects;
create policy "courses readable by authed" on storage.objects
    for select using (
        bucket_id = 'courses' and auth.role() = 'authenticated'
    );

drop policy if exists "courses writable by authed" on storage.objects;
create policy "courses writable by authed" on storage.objects
    for insert with check (
        bucket_id = 'courses' and auth.role() = 'authenticated'
    );

drop policy if exists "courses updatable by authed" on storage.objects;
create policy "courses updatable by authed" on storage.objects
    for update using (
        bucket_id = 'courses' and auth.role() = 'authenticated'
    ) with check (
        bucket_id = 'courses' and auth.role() = 'authenticated'
    );

drop policy if exists "courses deletable by authed" on storage.objects;
create policy "courses deletable by authed" on storage.objects
    for delete using (
        bucket_id = 'courses' and auth.role() = 'authenticated'
    );
