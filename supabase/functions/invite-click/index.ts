import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { fingerprintMatches, normalizeInviteCode } from "../_shared/invite.ts";
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
    .select("id, expires_at, claimed_at, clicked_at, fingerprint")
    .eq("invite_code", normalizedCode)
    .maybeSingle();

  if (fetchError) {
    return jsonResponse({ error: fetchError.message }, 500);
  }

  if (!session) {
    return jsonResponse({ error: "Invite not found" }, 404);
  }

  if (session.claimed_at) {
    return jsonResponse({ error: "Invite already used" }, 410);
  }

  if (session.clicked_at) {
    const stored = session.fingerprint as Record<string, unknown> | null;
    if (fingerprintMatches(stored, fingerprint)) {
      return jsonResponse({ ok: true, invite_code: normalizedCode, already_recorded: true });
    }
    return jsonResponse({ error: "Invite link already opened on another device" }, 410);
  }

  if (session.expires_at <= now) {
    return jsonResponse({ error: "Invite expired" }, 410);
  }

  const clickFingerprint = {
    ...fingerprint,
    source: "landing_page",
    recorded_at: now,
  };

  const { error: updateError } = await supabase
    .from("invite_sessions")
    .update({
      fingerprint: clickFingerprint,
      clicked_at: now,
    })
    .eq("id", session.id)
    .is("clicked_at", null);

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  return jsonResponse({ ok: true, invite_code: normalizedCode });
});
