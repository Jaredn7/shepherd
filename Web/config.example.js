/**
 * Copy this file to `config.js` and edit before deploying.
 * `config.js` is listed in .gitignore if you prefer not to commit keys locally.
 */
window.SHEPHERD_INVITE_CONFIG = {
  /** Supabase project URL (same as iOS SupabaseConfig.plist) */
  supabaseUrl: "https://zrtinnhwfrygizuagsqz.supabase.co",

  /** Supabase anon key (publishable; same as iOS) */
  supabaseAnonKey: "YOUR_SUPABASE_ANON_KEY",

  /** Edge function that records the landing-page click fingerprint */
  inviteClickFunction: "invite-click",

  /** Where to send users if the app is not installed */
  appStoreUrl: "https://apps.apple.com/app/id0000000000",
  playStoreUrl: "https://play.google.com/store/apps/details?id=com.shepherd.app",

  /** Custom URL scheme fallback (must match iOS URL types when added) */
  appScheme: "shepherd",

  /**
   * Your public invite host (no trailing slash).
   * Used for Universal Link open attempts, e.g. https://join.yourdomain.com
   */
  inviteHost: "https://shepherd-pi-nine.vercel.app",

  /** Milliseconds to wait after trying to open the app before store redirect */
  redirectDelayMs: 2500,
};
