import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";

interface OutboundLockbox {
  recipient_device_id: string;
  min_app_version?: string;
  payload: Record<string, unknown>;
}

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: { sender_device_id?: string; lockboxes?: OutboundLockbox[] };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const senderDeviceId = body.sender_device_id;
  const lockboxes = body.lockboxes;

  if (!senderDeviceId || !Array.isArray(lockboxes) || lockboxes.length === 0) {
    return jsonResponse({
      error: "sender_device_id and non-empty lockboxes array are required",
    }, 400);
  }

  if (lockboxes.length > 100) {
    return jsonResponse({ error: "Maximum 100 lockboxes per batch" }, 400);
  }

  const rows = lockboxes.map((box) => ({
    sender_device_id: senderDeviceId,
    recipient_device_id: box.recipient_device_id,
    min_app_version: box.min_app_version ?? "0.0.0",
    payload: box.payload,
  }));

  const supabase = serviceClient();
  const { data, error } = await supabase
    .from("lockboxes")
    .insert(rows)
    .select("id");

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  return jsonResponse({
    inserted: data?.length ?? 0,
    ids: (data ?? []).map((row) => row.id),
  });
});
