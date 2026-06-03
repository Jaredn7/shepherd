import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { isVersionCompatible } from "../_shared/semver.ts";

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== "GET") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const url = new URL(req.url);
  const recipientDeviceId = url.searchParams.get("recipient_device_id");
  const appVersion = url.searchParams.get("app_version") ?? "0.0.0";

  if (!recipientDeviceId) {
    return jsonResponse({ error: "recipient_device_id is required" }, 400);
  }

  const supabase = serviceClient();

  const { data: configRow } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", "minimum_required_version")
    .maybeSingle();

  const minimumRequired = configRow?.value ?? "0.0.0";
  if (!isVersionCompatible(appVersion, minimumRequired)) {
    return jsonResponse({
      error: "major_update_required",
      minimum_required_version: minimumRequired,
    }, 426);
  }

  const { data: rows, error } = await supabase
    .from("lockboxes")
    .select("id, sender_device_id, min_app_version, payload, created_at")
    .eq("recipient_device_id", recipientDeviceId)
    .order("created_at", { ascending: true })
    .limit(500);

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  const delivered = (rows ?? []).filter((row) =>
    isVersionCompatible(appVersion, row.min_app_version ?? "0.0.0")
  );

  const heldCount = (rows?.length ?? 0) - delivered.length;

  return jsonResponse({
    lockboxes: delivered,
    update_available: heldCount > 0,
    held_count: heldCount,
  });
});
