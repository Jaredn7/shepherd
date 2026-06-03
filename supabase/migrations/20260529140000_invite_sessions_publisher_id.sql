-- Tie each invite session to a pre-created publisher record on the elder's device.

alter table public.invite_sessions
  add column if not exists publisher_id uuid;

comment on column public.invite_sessions.publisher_id is
  'Publisher UUID created on the inviting elder device before the invite was sent.';
