-- MarketLab initial schema: profiles, markets, positions, ledger_entries

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text,
  last_name text,
  balance_cents bigint not null default 1000000 check (balance_cents >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.markets (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  status text not null default 'open' check (status in ('open', 'closed', 'resolved')),
  close_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.positions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  market_id uuid not null references public.markets (id) on delete restrict,
  yes_shares_cents bigint not null default 0 check (yes_shares_cents >= 0),
  no_shares_cents bigint not null default 0 check (no_shares_cents >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, market_id)
);

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  market_id uuid references public.markets (id) on delete set null,
  amount_cents bigint not null check (amount_cents <> 0),
  entry_type text not null check (
    entry_type in ('initial_grant', 'trade', 'payout', 'adjustment')
  ),
  description text,
  created_at timestamptz not null default now()
);

create index positions_user_id_idx on public.positions (user_id);
create index positions_market_id_idx on public.positions (market_id);
create index ledger_entries_user_id_idx on public.ledger_entries (user_id);
create index ledger_entries_created_at_idx on public.ledger_entries (created_at desc);

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create trigger markets_set_updated_at
before update on public.markets
for each row
execute function public.set_updated_at();

create trigger positions_set_updated_at
before update on public.positions
for each row
execute function public.set_updated_at();

create or replace function public.prevent_profile_balance_update()
returns trigger
language plpgsql
as $$
begin
  if new.balance_cents is distinct from old.balance_cents then
    raise exception 'Direct balance updates are not allowed';
  end if;

  return new;
end;
$$;

create trigger profiles_prevent_balance_update
before update on public.profiles
for each row
execute function public.prevent_profile_balance_update();

alter table public.profiles enable row level security;
alter table public.markets enable row level security;
alter table public.positions enable row level security;
alter table public.ledger_entries enable row level security;

-- Public read for market data.
create policy "Markets are viewable by everyone"
on public.markets
for select
to anon, authenticated
using (true);

-- Owner read for profile, positions, and ledger.
create policy "Profiles are viewable by owner"
on public.profiles
for select
to authenticated
using (id = auth.uid());

create policy "Positions are viewable by owner"
on public.positions
for select
to authenticated
using (user_id = auth.uid());

create policy "Ledger entries are viewable by owner"
on public.ledger_entries
for select
to authenticated
using (user_id = auth.uid());

-- No client write policies on profiles, positions, or ledger_entries.
-- Balance and trade writes will go through security definer RPCs later.

-- Auth signUp options.data.first_name / last_name land in raw_user_meta_data.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  starting_balance_cents bigint := 1000000;
begin
  insert into public.profiles (
    id,
    first_name,
    last_name,
    balance_cents
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    starting_balance_cents
  );

  insert into public.ledger_entries (
    user_id,
    amount_cents,
    entry_type,
    description
  )
  values (
    new.id,
    starting_balance_cents,
    'initial_grant',
    'Welcome bonus'
  );

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();
