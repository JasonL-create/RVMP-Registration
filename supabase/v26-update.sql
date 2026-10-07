-- RVMP Registration V26
-- Adds public confirmation-code lookup and stored sponsor inquiries.

create table if not exists public.sponsor_inquiries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  contact_name text not null,
  business_name text not null,
  email text not null,
  phone text,
  status text not null default 'new' check (status in ('new','contacted','closed')),
  created_at timestamptz not null default now()
);

alter table public.sponsor_inquiries enable row level security;

drop policy if exists "organizers manage sponsor inquiries" on public.sponsor_inquiries;
create policy "organizers manage sponsor inquiries"
on public.sponsor_inquiries
for all
to authenticated
using (exists (select 1 from public.organizers o where o.user_id = auth.uid()))
with check (exists (select 1 from public.organizers o where o.user_id = auth.uid()));

grant select, insert, update, delete on public.sponsor_inquiries to authenticated;

create or replace function public.submit_sponsor_inquiry(
  p_event_id uuid,
  p_contact_name text,
  p_business_name text,
  p_email text,
  p_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if nullif(trim(p_contact_name),'') is null
     or nullif(trim(p_business_name),'') is null
     or nullif(trim(p_email),'') is null then
    raise exception 'Name, business name, and email are required.';
  end if;

  insert into public.sponsor_inquiries(event_id,contact_name,business_name,email,phone)
  values (p_event_id,trim(p_contact_name),trim(p_business_name),lower(trim(p_email)),nullif(trim(coalesce(p_phone,'')),''))
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_sponsor_inquiry(uuid,text,text,text,text) from public;
grant execute on function public.submit_sponsor_inquiry(uuid,text,text,text,text) to anon, authenticated;

create or replace function public.lookup_registration(
  p_event_id uuid,
  p_confirmation_code text
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'confirmation_code', r.confirmation_code,
    'primary_name', r.primary_name,
    'status', r.status,
    'volunteers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id,
        'full_name', v.full_name,
        'is_adult', v.is_adult
      ) order by v.created_at, v.id)
      from public.volunteers v
      where v.registration_id = r.id
    ), '[]'::jsonb),
    'sessions', coalesce((
      select jsonb_agg(distinct jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'session_type', s.session_type,
        'session_date', s.session_date,
        'start_time', s.start_time,
        'end_time', s.end_time,
        'sort_order', s.sort_order
      ))
      from public.volunteers v
      join public.volunteer_sessions vs on vs.volunteer_id = v.id
      join public.sessions s on s.id = vs.session_id
      where v.registration_id = r.id
    ), '[]'::jsonb)
  )
  from public.registrations r
  where r.event_id = p_event_id
    and upper(trim(r.confirmation_code)) = upper(trim(p_confirmation_code))
    and coalesce(r.archived,false) = false
  limit 1;
$$;

revoke all on function public.lookup_registration(uuid,text) from public;
grant execute on function public.lookup_registration(uuid,text) to anon, authenticated;
