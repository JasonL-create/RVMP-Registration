-- RVMP database foundation (NOT connected to the demo app).
-- Run in a new Supabase project when available. No public write policies are granted.
-- Before production, implement server-side atomic registration RPC, rate limiting,
-- verified contact lookup, and secure group-leader access; see README.md.
create extension if not exists pgcrypto;
create table if not exists public.rvmp_events (
 id uuid primary key default gen_random_uuid(), title text not null,
 location text not null default '', instructions text not null default '',
 donation_url text not null default 'https://www.rvmp.org/',
 contact_email text not null default '', public_max integer not null default 10 check(public_max between 1 and 100),
 created_at timestamptz not null default now()
);
create table if not exists public.rvmp_shifts (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references public.rvmp_events on delete cascade,
 name text not null, kind text not null check(kind in ('packing','extra')),
 starts_at timestamptz not null, ends_at timestamptz not null,
 capacity integer not null check(capacity>=0), public_open boolean not null default true,
 check(ends_at>starts_at)
);
create table if not exists public.rvmp_groups (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references public.rvmp_events on delete cascade,
 name text not null, code_hash text not null, created_at timestamptz not null default now()
);
create table if not exists public.rvmp_group_allocations (
 group_id uuid not null references public.rvmp_groups on delete cascade,
 shift_id uuid not null references public.rvmp_shifts on delete cascade,
 allocated integer not null default 0 check(allocated>=0), primary key(group_id,shift_id)
);
create table if not exists public.rvmp_registrations (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references public.rvmp_events,
 group_id uuid references public.rvmp_groups, contact_name text not null,
 contact_email text not null, contact_phone text not null,
 future_email_opt_in boolean not null default false, sms_opt_in boolean not null default false,
 consent_recorded_at timestamptz not null default now(), consent_version text not null default 'v1',
 status text not null default 'active' check(status in ('active','cancelled')),
 created_at timestamptz not null default now()
);
create table if not exists public.rvmp_volunteers (
 id uuid primary key default gen_random_uuid(), registration_id uuid not null references public.rvmp_registrations on delete cascade,
 full_name text not null, adult_18_plus boolean not null
);
create table if not exists public.rvmp_volunteer_shifts (
 volunteer_id uuid not null references public.rvmp_volunteers on delete cascade,
 shift_id uuid not null references public.rvmp_shifts,
 primary key(volunteer_id,shift_id)
);
create table if not exists public.rvmp_organizers (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create or replace function public.rvmp_is_organizer() returns boolean
 language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.rvmp_organizers where user_id=auth.uid())
 $$;
revoke all on function public.rvmp_is_organizer() from public;
grant execute on function public.rvmp_is_organizer() to authenticated;
alter table public.rvmp_events enable row level security;
alter table public.rvmp_shifts enable row level security;
alter table public.rvmp_groups enable row level security;
alter table public.rvmp_group_allocations enable row level security;
alter table public.rvmp_registrations enable row level security;
alter table public.rvmp_volunteers enable row level security;
alter table public.rvmp_volunteer_shifts enable row level security;
alter table public.rvmp_organizers enable row level security;
create policy "read public event metadata" on public.rvmp_events for select to anon,authenticated using(true);
create policy "read public shift metadata" on public.rvmp_shifts for select to anon,authenticated using(true);
create policy "organizers manage events" on public.rvmp_events for all to authenticated using(public.rvmp_is_organizer()) with check(public.rvmp_is_organizer());
create policy "organizers manage shifts" on public.rvmp_shifts for all to authenticated using(public.rvmp_is_organizer()) with check(public.rvmp_is_organizer());
create policy "organizers manage groups" on public.rvmp_groups for all to authenticated using(public.rvmp_is_organizer()) with check(public.rvmp_is_organizer());
create policy "organizers manage allocations" on public.rvmp_group_allocations for all to authenticated using(public.rvmp_is_organizer()) with check(public.rvmp_is_organizer());
create policy "organizers manage registrations" on public.rvmp_registrations for all to authenticated using(public.rvmp_is_organizer()) with check(public.rvmp_is_organizer());
create policy "organizers manage volunteers" on public.rvmp_volunteers for all to authenticated using(public.rvmp_is_organizer()) with check(public.rvmp_is_organizer());
create policy "organizers manage volunteer shifts" on public.rvmp_volunteer_shifts for all to authenticated using(public.rvmp_is_organizer()) with check(public.rvmp_is_organizer());
-- Deliberately NO public policies on contact details, groups, or registrations.
-- Public writes must be implemented through a SECURITY DEFINER RPC that checks
-- group-code hashes, enforces per-shift availability under transaction locks,
-- enforces one packing shift per volunteer, and rate limits abusive requests.
