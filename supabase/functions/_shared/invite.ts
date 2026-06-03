export function normalizeInviteCode(code: string): string {
  return code.trim().toUpperCase();
}

export function fingerprintMatches(
  stored: Record<string, unknown> | null | undefined,
  request: Record<string, unknown>,
): boolean {
  if (!stored || stored.source !== "landing_page") return false;

  return (
    String(stored.os ?? "") === String(request.os ?? "") &&
    String(stored.screen_width ?? "") === String(request.screen_width ?? "") &&
    String(stored.screen_height ?? "") === String(request.screen_height ?? "")
  );
}

export function inviteResolveError(
  session: {
    claimed_at?: string | null;
    clicked_at?: string | null;
    welcome_package?: unknown;
    fingerprint?: Record<string, unknown>;
    expires_at: string;
  },
  requestFingerprint: Record<string, unknown>,
  now: string,
): string | null {
  if (session.claimed_at) return "Invite already used";
  if (session.expires_at <= now) return "Invite expired";
  if (!session.clicked_at) return "Open the invite link on this device first";
  if (!session.welcome_package) return "Invite missing welcome package";
  if (!fingerprintMatches(session.fingerprint, requestFingerprint)) {
    return "This device does not match the invite link";
  }
  return null;
}
