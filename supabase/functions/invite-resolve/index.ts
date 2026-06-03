import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import {
  inviteResolveError,
  normalizeInviteCode,
} from "../_shared/invite.ts";
import { serviceClient } from "../_shared/supabase.ts";

type InviteSession = {
  id: string;
  invite_code: string;
  congregation_id: string;
  publisher_id: string | null;
  elder_public_key: string;
  elder_device_id: string;
  fingerprint: Record<string, unknown>;
  welcome_package: unknown[] | null;
  expires_at: string;
  clicked_at: string | null;
  claimed_at: string | null;
};

function buildSuccessPayload(session: InviteSession) {
  if (!session.publisher_id) {
    throw new Error("Invite session missing publisher_id");
  }

  if (!session.welcome_package || !Array.isArray(session.welcome_package)) {
    throw new Error("Invite session missing welcome_package");
  }

  return {
    congregation_id: session.congregation_id,
    elder_public_key: session.elder_public_key,
    elder_device_id: session.elder_device_id,
    invite_code: session.invite_code,
    publisher_id: session.publisher_id,
    welcome_package: session.welcome_package,
    /** Package remains on server until invite-ack confirms safe local receipt. */
    pending_ack: true,
  };
}

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

  if (!fingerprint || typeof fingerprint !== "object") {
    return jsonResponse({ error: "fingerprint object is required" }, 400);
  }

  const supabase = serviceClient();
  const now = new Date().toISOString();

  let session: InviteSession | null = null;

  if (invite_code) {
    const normalizedCode = normalizeInviteCode(invite_code);
    const { data, error } = await supabase
      .from("invite_sessions")
      .select("*")
      .eq("invite_code", normalizedCode)
      .maybeSingle();

    if (error) {
      return jsonResponse({ error: error.message }, 500);
    }

    session = data as InviteSession | null;
  } else {
    const os = String(fingerprint.os ?? "");
    const screenWidth = String(fingerprint.screen_width ?? "");
    const screenHeight = String(fingerprint.screen_height ?? "");

    const { data: candidates, error } = await supabase
      .from("invite_sessions")
      .select("*")
      .gt("expires_at", now)
      .is("claimed_at", null)
      .not("clicked_at", "is", null)
      .not("welcome_package", "is", null)
      .eq("fingerprint->>source", "landing_page")
      .eq("fingerprint->>os", os)
      .eq("fingerprint->>screen_width", screenWidth)
      .eq("fingerprint->>screen_height", screenHeight)
      .order("clicked_at", { ascending: false })
      .limit(1);

    if (error) {
      return jsonResponse({ error: error.message }, 500);
    }

    session = (candidates?.[0] as InviteSession | undefined) ?? null;
  }

  if (!session) {
    return jsonResponse({ error: "Invite not found or expired" }, 404);
  }

  const validationError = inviteResolveError(session, fingerprint, now);
  if (validationError) {
    const status = validationError.includes("already used") ? 410 : 403;
    return jsonResponse({ error: validationError }, status);
  }

  try {
    return jsonResponse(buildSuccessPayload(session));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Invite resolve failed";
    return jsonResponse({ error: message }, 500);
  }
});
