-- Mio Client: безопасный профиль пользователя и статус Premium
-- Вставь весь скрипт в Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Premium по умолчанию false. Клиент сайта не получает права менять is_premium.

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    is_premium boolean not null default false,
    created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
    on public.profiles
    for select
    to authenticated
    using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;

revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;

create or replace function public.handle_new_mio_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, is_premium)
    values (new.id, false)
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created_mio on auth.users;
create trigger on_auth_user_created_mio
    after insert on auth.users
    for each row execute procedure public.handle_new_mio_user();

insert into public.profiles (id, is_premium)
select id, false from auth.users
on conflict (id) do nothing;
