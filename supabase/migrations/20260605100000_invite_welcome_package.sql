-- Pre-approved welcome packages: elder uploads congregation snapshot when creating invite.

alter table public.invite_sessions
  add column if not exists welcome_package jsonb,
  add column if not exists clicked_at timestamptz;

comment on column public.invite_sessions.welcome_package is
  'Welcome instruction array uploaded by elder at invite creation (invite = pre-approval).';

comment on column public.invite_sessions.clicked_at is
  'First time the invite link was opened; binds fingerprint before app install.';

alter table public.invite_sessions
  drop constraint if exists invite_sessions_welcome_package_is_array;

alter table public.invite_sessions
  add constraint invite_sessions_welcome_package_is_array check (
    welcome_package is null or jsonb_typeof(welcome_package) = 'array'
  );
