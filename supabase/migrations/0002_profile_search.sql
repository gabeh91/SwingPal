-- Searchable profiles for authenticated golfers (excludes self).
-- Execute in Supabase SQL after 0001_init.sql.

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
    )
  order by
    case when p.username ilike trim(search_query) || '%' then 0 else 1 end,
    p.display_name nulls last
  limit least(coalesce(result_limit, 20), 50);
$$;

grant execute on function public.search_profiles(text, int) to authenticated;
