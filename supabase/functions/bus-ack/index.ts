import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: { recipient_device_id?: string; lockbox_ids?: string[] };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const recipientDeviceId = body.recipient_device_id;
  const lockboxIds = body.lockbox_ids;

  if (!recipientDeviceId || !Array.isArray(lockboxIds) || lockboxIds.length === 0) {
    return jsonResponse({
      error: "recipient_device_id and non-empty lockbox_ids are required",
    }, 400);
  }

  const supabase = serviceClient();
  const { error, count } = await supabase
    .from("lockboxes")
    .delete({ count: "exact" })
    .eq("recipient_device_id", recipientDeviceId)
    .in("id", lockboxIds);

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  return jsonResponse({ deleted: count ?? 0 });
});
