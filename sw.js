// Our Tasks service worker: keeps the app's files on the device so it opens without internet.
// Data is not handled here: the app keeps its own copy of the data and syncs it with Supabase.
// Bump VERSION when the list of files below changes.
const VERSION = "v6";
// Production (/our-tasks/) and development (/our-tasks/dev/) share one website, so each keeps its own cache.
const SCOPE = new URL(self.registration.scope).pathname;
const CACHE = "our-tasks-" + VERSION + "-" + SCOPE;
const SUPABASE_JS = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js";
const SUPABASE_JS_SRI = "sha384-0w2KAL2YHP6wKOkUDzkCDGgVvfmHnj02DHeQ6XcHOgTfFsGyonKOpShMH1x6nk9o"; // the same value as in index.html
const FILES = ["./", "./index.html", "./manifest.webmanifest", "./icons/icon-32.png", "./icons/icon-192.png",
  "./icons/icon-512.png", "./icons/apple-touch-icon.png", new Request(SUPABASE_JS, { integrity: SUPABASE_JS_SRI })];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => (k.startsWith("our-tasks-") && k.endsWith("-" + SCOPE) && k !== CACHE) || /^our-tasks-v\d+$/.test(k)) // older caches had no scope in the name
      .map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", (e) => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== "GET" || url.hostname.endsWith("supabase.co")) return; // data and sign-in always go to the network

  // The app itself: network first, so updates arrive as soon as you're online; the stored copy when offline.
  if (url.origin === self.location.origin) {
    e.respondWith(fetch(req).then((res) => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
      return res;
    }).catch(() => caches.match(req, { ignoreSearch: true }).then((r) => r || caches.match("./index.html"))));
    return;
  }

  // Libraries and fonts never change at a fixed address: stored copy first, network to fill the store.
  if (url.hostname === "cdn.jsdelivr.net" || url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com") {
    e.respondWith(caches.match(req).then((hit) => hit || fetch(req).then((res) => {
      if (res.ok || res.type === "opaque") { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
      return res;
    })));
  }
});

// ---- push notifications (sent by the Supabase "notify" function) ----
self.addEventListener("push", (e) => {
  let msg = {};
  try { msg = e.data ? e.data.json() : {}; } catch { msg = { body: e.data ? e.data.text() : "" }; }
  e.waitUntil(self.registration.showNotification(msg.title || "Our Tasks", {
    body: msg.body || "",
    icon: "icons/icon-192.png",
    badge: "icons/icon-192.png",
    tag: msg.tag || undefined,
    data: { url: msg.url || self.registration.scope },
  }));
});

// Tapping a notification opens the app (or brings it to the front) at the notification's address.
self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  const url = new URL(e.notification.data?.url || "./", self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((windows) => {
    const open = windows.find((w) => w.url.startsWith(self.registration.scope));
    if (open) { open.postMessage({ open: url }); return open.focus(); }
    return self.clients.openWindow(url);
  }));
});
