import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import {
  fingerprintMatches,
  normalizeInviteCode,
} from "../_shared/invite.ts";
import { serviceClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: {
    invite_code?: string;
    fingerprint?: Record<string, unknown>;
  };

  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const { invite_code, fingerprint } = body;

  if (!invite_code || typeof invite_code !== "string") {
    return jsonResponse({ error: "invite_code is required" }, 400);
  }

  if (!fingerprint || typeof fingerprint !== "object") {
    return jsonResponse({ error: "fingerprint object is required" }, 400);
  }

  const normalizedCode = normalizeInviteCode(invite_code);
  const supabase = serviceClient();
  const now = new Date().toISOString();

  const { data: session, error: fetchError } = await supabase
    .from("invite_sessions")
    .select("*")
    .eq("invite_code", normalizedCode)
    .maybeSingle();

  if (fetchError) {
    return jsonResponse({ error: fetchError.message }, 500);
  }

  if (!session) {
    return jsonResponse({ error: "Invite not found" }, 404);
  }

  if (session.claimed_at) {
    return jsonResponse({ ok: true, invite_code: normalizedCode, already_acked: true });
  }

  if (session.expires_at <= now) {
    return jsonResponse({ error: "Invite expired" }, 410);
  }

  if (!session.clicked_at) {
    return jsonResponse({ error: "Open the invite link on this device first" }, 403);
  }

  if (!fingerprintMatches(session.fingerprint, fingerprint)) {
    return jsonResponse({ error: "This device does not match the invite link" }, 403);
  }

  const { data: cleared, error: updateError } = await supabase
    .from("invite_sessions")
    .update({
      claimed_at: now,
      welcome_package: null,
      fingerprint: { source: "completed", completed_at: now },
    })
    .eq("id", session.id)
    .is("claimed_at", null)
    .select("id, invite_code, claimed_at")
    .maybeSingle();

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  if (!cleared) {
    return jsonResponse({ ok: true, invite_code: normalizedCode, already_acked: true });
  }

  return jsonResponse({
    ok: true,
    invite_code: normalizedCode,
    claimed_at: cleared.claimed_at,
  });
});
