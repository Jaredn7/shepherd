-- Phase 1: Bus Station relay table
-- Holds encrypted lockboxes in per-device inboxes until the recipient ACKs deletion.

create table public.lockboxes (
  id uuid primary key default gen_random_uuid(),
  recipient_device_id uuid not null,
  sender_device_id uuid not null,
  min_app_version text not null default '0.0.0',
  payload jsonb not null,
  created_at timestamptz not null default now(),

  constraint lockboxes_payload_is_object check (jsonb_typeof(payload) = 'object')
);

comment on table public.lockboxes is
  'Temporary encrypted message relay (Bus Station). Rows are deleted after the recipient ACKs delivery.';

comment on column public.lockboxes.recipient_device_id is
  'Anonymous device UUID — routes the lockbox to the correct inbox.';

comment on column public.lockboxes.sender_device_id is
  'Anonymous sender device UUID (shipping label). Client verifies against local directory.';

comment on column public.lockboxes.min_app_version is
  'Server-side compatibility filter. Only delivered when client app_version >= this value.';

comment on column public.lockboxes.payload is
  'Encrypted lockbox JSON: type, sender_public_key, iv, ciphertext, auth_tag (see cryptography_spec.md).';

create index lockboxes_recipient_created_idx
  on public.lockboxes (recipient_device_id, created_at);

-- RLS enabled with no client policies yet. Access will go through Edge Functions
-- (service_role) until device auth is added in a later phase.
alter table public.lockboxes enable row level security;
