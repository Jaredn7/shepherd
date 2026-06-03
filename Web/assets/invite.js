(function () {
  "use strict";

  const config = window.SHEPHERD_INVITE_CONFIG;
  const statusEl = document.getElementById("status-text");
  const statusBox = document.getElementById("status");
  const codeEl = document.getElementById("invite-code");
  const manualLink = document.getElementById("manual-link");

  let storeRedirectTimer = null;
  let redirectWatchersInstalled = false;

  function setStatus(message, isError) {
    statusEl.textContent = message;
    statusBox.classList.toggle("error", Boolean(isError));
  }

  function cancelStoreRedirect() {
    if (storeRedirectTimer !== null) {
      window.clearTimeout(storeRedirectTimer);
      storeRedirectTimer = null;
    }
  }

  function installRedirectCancellation() {
    if (redirectWatchersInstalled) return;
    redirectWatchersInstalled = true;

    document.addEventListener("visibilitychange", function () {
      if (document.hidden) cancelStoreRedirect();
    });
    window.addEventListener("pagehide", cancelStoreRedirect);
  }

  function readInviteCode() {
    const params = new URLSearchParams(window.location.search);
    const fromQuery = params.get("code") || params.get("c");
    if (fromQuery) return fromQuery.trim().toUpperCase();

    const parts = window.location.pathname.split("/").filter(Boolean);
    const iIndex = parts.indexOf("i");
    if (iIndex !== -1 && parts[iIndex + 1]) {
      return decodeURIComponent(parts[iIndex + 1]).trim().toUpperCase();
    }

    const last = parts[parts.length - 1];
    if (last && last !== "i" && last !== "index.html") {
      return decodeURIComponent(last).trim().toUpperCase();
    }

    return "";
  }

  function detectOS() {
    const ua = navigator.userAgent || "";
    if (/iPad|iPhone|iPod/.test(ua)) return "iOS";
    if (/Android/.test(ua)) return "Android";
    return "Web";
  }

  function buildFingerprint() {
    const screen = window.screen;
    return {
      os: detectOS(),
      os_version: navigator.userAgent || "",
      screen_width: String(Math.round(screen.width)),
      screen_height: String(Math.round(screen.height)),
      viewport_width: String(Math.round(window.innerWidth)),
      viewport_height: String(Math.round(window.innerHeight)),
      device_pixel_ratio: String(window.devicePixelRatio || 1),
      language: navigator.language || "",
      user_agent: navigator.userAgent || "",
      clicked_at: new Date().toISOString(),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "",
    };
  }

  function clickStorageKey(inviteCode) {
    return `shepherd_invite_click_${inviteCode}`;
  }

  async function recordClick(inviteCode, fingerprint) {
    if (sessionStorage.getItem(clickStorageKey(inviteCode)) === "1") {
      return { ok: true, already_recorded: true };
    }

    if (!config?.supabaseUrl || !config?.supabaseAnonKey) {
      throw new Error("Missing Supabase config. Copy config.example.js to config.js.");
    }

    const functionName = config.inviteClickFunction || "invite-click";
    const url = `${config.supabaseUrl.replace(/\/$/, "")}/functions/v1/${functionName}`;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: config.supabaseAnonKey,
        Authorization: `Bearer ${config.supabaseAnonKey}`,
      },
      body: JSON.stringify({
        invite_code: inviteCode,
        fingerprint,
      }),
    });

    if (!response.ok) {
      const payload = await response.json().catch(function () {
        return {};
      });
      throw new Error(payload.error || `Invite click failed (${response.status})`);
    }

    const payload = await response.json();
    sessionStorage.setItem(clickStorageKey(inviteCode), "1");
    return payload;
  }

  /** Opens the native app via custom URL scheme (iOS shows one system “Open?” sheet). */
  function tryOpenApp(inviteCode) {
    const scheme = config?.appScheme || "shepherd";
    window.location.href = `${scheme}://invite?code=${encodeURIComponent(inviteCode)}`;
  }

  function scheduleStoreRedirectIfStillOnPage() {
    const os = detectOS();
    const delay = Number(config?.redirectDelayMs) || 6000;

    installRedirectCancellation();
    cancelStoreRedirect();

    storeRedirectTimer = window.setTimeout(function () {
      storeRedirectTimer = null;
      if (document.hidden) return;

      if (os === "Android" && config?.playStoreUrl) {
        window.location.href = config.playStoreUrl;
        return;
      }
      if (config?.appStoreUrl) {
        window.location.href = config.appStoreUrl;
      }
    }, delay);
  }

  async function run() {
    const inviteCode = readInviteCode();

    if (!inviteCode) {
      setStatus("This invite link is missing a code. Ask your elder to send a new link.", true);
      return;
    }

    codeEl.textContent = inviteCode;
    manualLink.href = `${(config?.appScheme || "shepherd")}://invite?code=${encodeURIComponent(inviteCode)}`;
    manualLink.addEventListener("click", function () {
      cancelStoreRedirect();
    });

    const alreadySaved = sessionStorage.getItem(clickStorageKey(inviteCode)) === "1";

    try {
      if (!alreadySaved) {
        setStatus("Saving your invite for this device…");
        await recordClick(inviteCode, buildFingerprint());
      }

      setStatus("Opening Shepherd… Tap Open if iOS asks.");
      if (detectOS() === "iOS" || detectOS() === "Android") {
        tryOpenApp(inviteCode);
      }
      scheduleStoreRedirectIfStillOnPage();
    } catch (error) {
      console.error(error);
      const message = error instanceof Error ? error.message : "Something went wrong.";
      if (sessionStorage.getItem(clickStorageKey(inviteCode)) === "1") {
        setStatus("Opening Shepherd… Tap Open in Shepherd below if needed.");
        tryOpenApp(inviteCode);
        scheduleStoreRedirectIfStillOnPage();
        return;
      }
      setStatus(message, true);
    }
  }

  document.addEventListener("DOMContentLoaded", run);
})();
