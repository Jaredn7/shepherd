import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { normalizeInviteCode } from "../_shared/invite.ts";
import { serviceClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: {
    invite_code?: string;
    congregation_id?: string;
    publisher_id?: string;
    elder_public_key?: string;
    elder_device_id?: string;
    welcome_package?: unknown[];
    ttl_hours?: number;
  };

  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const {
    invite_code,
    congregation_id,
    publisher_id,
    elder_public_key,
    elder_device_id,
    welcome_package,
    ttl_hours = 48,
  } = body;

  if (
    !invite_code || !congregation_id || !publisher_id || !elder_public_key ||
    !elder_device_id || !welcome_package || !Array.isArray(welcome_package) ||
    welcome_package.length === 0
  ) {
    return jsonResponse({ error: "Missing required invite fields" }, 400);
  }

  const expiresAt = new Date(Date.now() + ttl_hours * 60 * 60 * 1000);
  const normalizedCode = normalizeInviteCode(invite_code);

  const supabase = serviceClient();
  const { data, error } = await supabase
    .from("invite_sessions")
    .upsert({
      invite_code: normalizedCode,
      congregation_id,
      publisher_id,
      elder_public_key,
      elder_device_id,
      welcome_package,
      fingerprint: { source: "pending_click" },
      expires_at: expiresAt.toISOString(),
      clicked_at: null,
      claimed_at: null,
    }, { onConflict: "invite_code" })
    .select("id, invite_code, expires_at")
    .single();

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  return jsonResponse({ session: data });
});
