-- V24: allow organizer-only archiving without deleting registration history.
alter table public.registrations
  add column if not exists archived_at timestamptz;
