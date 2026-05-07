-- Round summary AI analysis sync for Stats + Home hero cards.
-- Apply after 0001_init.sql (+ 0003_... if used).

create table if not exists public.round_analyses (
    round_id uuid primary key references public.rounds(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    cache_key text not null,
    provider text not null,
    summary text not null,
    what_went_well jsonb not null default '[]'::jsonb,
    needs_work jsonb not null default '[]'::jsonb,
    generated_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists round_analyses_user_idx on public.round_analyses (user_id, updated_at desc);

alter table public.round_analyses enable row level security;

drop policy if exists "round analyses owner crud" on public.round_analyses;
create policy "round analyses owner crud" on public.round_analyses
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.set_round_analyses_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists round_analyses_set_updated_at on public.round_analyses;
create trigger round_analyses_set_updated_at
    before update on public.round_analyses
    for each row execute function public.set_round_analyses_updated_at();

