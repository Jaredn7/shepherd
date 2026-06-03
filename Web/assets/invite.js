(function () {
  "use strict";

  const config = window.SHEPHERD_INVITE_CONFIG;
  const statusEl = document.getElementById("status-text");
  const statusBox = document.getElementById("status");
  const codeEl = document.getElementById("invite-code");
  const manualLink = document.getElementById("manual-link");

  let storeRedirectTimer = null;
  let universalFallbackTimer = null;
  let redirectWatchersInstalled = false;

  function setStatus(message, isError) {
    statusEl.textContent = message;
    statusBox.classList.toggle("error", Boolean(isError));
  }

  function cancelPendingRedirects() {
    if (storeRedirectTimer !== null) {
      window.clearTimeout(storeRedirectTimer);
      storeRedirectTimer = null;
    }
    if (universalFallbackTimer !== null) {
      window.clearTimeout(universalFallbackTimer);
      universalFallbackTimer = null;
    }
  }

  function installRedirectCancellation() {
    if (redirectWatchersInstalled) return;
    redirectWatchersInstalled = true;

    document.addEventListener("visibilitychange", function () {
      if (document.hidden) cancelPendingRedirects();
    });
    window.addEventListener("pagehide", cancelPendingRedirects);
    window.addEventListener("blur", cancelPendingRedirects);
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

  function tryOpenUniversalLink(url) {
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.rel = "noopener";
    anchor.style.display = "none";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  function tryOpenApp(inviteCode) {
    const scheme = config?.appScheme || "shepherd";
    const schemeUrl = `${scheme}://invite?code=${encodeURIComponent(inviteCode)}`;

    const host = (config?.inviteHost || window.location.origin).replace(/\/$/, "");
    const universalUrl = `${host}/i/${encodeURIComponent(inviteCode)}`;

    if (detectOS() === "iOS") {
      // Do not navigate to /i/CODE — that reloads the page and hits invite-click twice.
      // Tap from WhatsApp uses OS Universal Links; here we nudge without a full reload.
      tryOpenUniversalLink(universalUrl);
      universalFallbackTimer = window.setTimeout(function () {
        universalFallbackTimer = null;
        if (!document.hidden) {
          window.location.href = schemeUrl;
        }
      }, 800);
      return;
    }

    window.location.href = schemeUrl;
  }

  function scheduleStoreRedirectIfStillOnPage() {
    const os = detectOS();
    const delay = Number(config?.redirectDelayMs) || 6000;

    installRedirectCancellation();
    cancelPendingRedirects();

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
      cancelPendingRedirects();
    });

    try {
      setStatus("Saving your invite…");
      await recordClick(inviteCode, buildFingerprint());
      setStatus("Opening Shepherd…");
      tryOpenApp(inviteCode);
      scheduleStoreRedirectIfStillOnPage();
    } catch (error) {
      console.error(error);
      const message = error instanceof Error ? error.message : "Something went wrong.";
      const alreadyRecorded =
        message.indexOf("already opened on another device") !== -1 &&
        sessionStorage.getItem(clickStorageKey(inviteCode)) === "1";
      if (alreadyRecorded) {
        setStatus("Opening Shepherd…");
        tryOpenApp(inviteCode);
        scheduleStoreRedirectIfStillOnPage();
        return;
      }
      setStatus(
        message || "Something went wrong. Try opening the link again.",
        true
      );
    }
  }

  document.addEventListener("DOMContentLoaded", run);
})();
