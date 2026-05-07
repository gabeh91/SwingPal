-- Richer profile fields, handicap visibility for followers, avatar storage.
-- Apply after 0001_init.sql and 0002_profile_search.sql.

alter table public.profiles
    add column if not exists bio text,
    add column if not exists show_handicap_to_followers boolean not null default false;

create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
    before update on public.profiles
    for each row execute function public.set_profiles_updated_at();

-- Followers may read a followee's handicap row only when they opted in on their profile.
drop policy if exists "handicaps visible to followers when opted in" on public.handicaps;
create policy "handicaps visible to followers when opted in" on public.handicaps
    for select using (
        exists (
            select 1
            from public.follows f
            join public.profiles p on p.id = handicaps.user_id
            where f.follower_id = auth.uid()
              and f.followee_id = handicaps.user_id
              and p.show_handicap_to_followers is true
        )
    );

-- Public avatar objects; uploads limited to each user's folder (first path segment = user id).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "avatars public read" on storage.objects;
create policy "avatars public read" on storage.objects
    for select using (bucket_id = 'avatars');

drop policy if exists "avatars owner insert" on storage.objects;
create policy "avatars owner insert" on storage.objects
    for insert with check (
        bucket_id = 'avatars'
        and auth.role() = 'authenticated'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "avatars owner update" on storage.objects;
create policy "avatars owner update" on storage.objects
    for update using (
        bucket_id = 'avatars'
        and auth.role() = 'authenticated'
        and (storage.foldername(name))[1] = auth.uid()::text
    ) with check (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "avatars owner delete" on storage.objects;
create policy "avatars owner delete" on storage.objects
    for delete using (
        bucket_id = 'avatars'
        and auth.role() = 'authenticated'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create or replace function public.search_profiles(search_query text, result_limit int default 20)
returns setof public.profiles
language sql
stable
security invoker
set search_path = public
as $$
  select p.*
  from public.profiles p
  where auth.role() = 'authenticated'
    and p.id <> auth.uid()
    and coalesce(trim(search_query), '') <> ''
    and length(trim(search_query)) >= 2
    and (
      p.username ilike '%' || trim(search_query) || '%'
      or p.display_name ilike '%' || trim(search_query) || '%'
      or coalesce(p.bio, '') ilike '%' || trim(search_query) || '%'
    )
  order by
    case when p.username ilike trim(search_query) || '%' then 0 else 1 end,
    p.display_name nulls last
  limit least(coalesce(result_limit, 20), 50);
$$;

grant execute on function public.search_profiles(text, int) to authenticated;
