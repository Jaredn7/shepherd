-- Phase 1: Deferred deep-link invite sessions + global app version gate.

create table public.invite_sessions (
  id uuid primary key default gen_random_uuid(),
  invite_code text not null unique,
  congregation_id uuid not null,
  elder_public_key text not null,
  elder_device_id uuid not null,
  fingerprint jsonb not null,
  expires_at timestamptz not null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),

  constraint invite_sessions_fingerprint_is_object check (jsonb_typeof(fingerprint) = 'object')
);

comment on table public.invite_sessions is
  'Temporary invite fingerprints for deferred deep linking. Matched when the app launches after install.';

create index invite_sessions_expires_idx on public.invite_sessions (expires_at);
create index invite_sessions_fingerprint_os_idx on public.invite_sessions ((fingerprint->>'os'));

create table public.app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

comment on table public.app_config is
  'Global client configuration (e.g. minimum_required_version).';

insert into public.app_config (key, value)
values ('minimum_required_version', '1.0.0')
on conflict (key) do nothing;

alter table public.invite_sessions enable row level security;
alter table public.app_config enable row level security;
