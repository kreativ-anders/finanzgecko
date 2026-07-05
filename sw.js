// sw.js — cached die App-Shell, damit die App offline startet.
// Versionsnummer bei jeder inhaltlichen Änderung hochzählen, damit
// Nutzer:innen automatisch die neue Version bekommen.
// DEVELOPMENT: On localhost/127.0.0.1, skip all caching to prevent stale files

const CACHE_VERSION = "v2";
const CACHE_NAME = `finanzgecko-${CACHE_VERSION}`;

const APP_SHELL = [
  "./",
  "./index.html",
  "./manifest.json",
  "./css/theme.css",
  "./js/main.js",
  "./js/db.js",
  "./js/currency.js",
  "./js/charts.js",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
];

// Pico.css kommt vom CDN — best effort cachen
const CDN_ASSETS = ["https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"];

// Skip all caching on localhost/127.0.0.1 for development
if (self.location && (self.location.hostname === "localhost" || self.location.hostname === "127.0.0.1")) {
  console.log("Service Worker: Skipping ALL caching on localhost/127.0.0.1 for development");
  // Don't register any event listeners - just exit
} else {
  // Production mode - normal service worker behavior
  
  self.addEventListener("install", (event) => {
    event.waitUntil(
      (async () => {
        const cache = await caches.open(CACHE_NAME);
        await cache.addAll(APP_SHELL);
        await Promise.all(
          CDN_ASSETS.map((url) =>
            fetch(url)
              .then((res) => (res.ok ? cache.put(url, res) : null))
              .catch(() => null)
          )
        );
        self.skipWaiting();
      })()
    );
  });

  self.addEventListener("activate", (event) => {
    event.waitUntil(
      (async () => {
        // Delete ALL old caches
        const keys = await caches.keys();
        await Promise.all(
          keys
            .filter((k) => k.includes("vermoegenstracker") || k.includes("finanzgecko"))
            .map((k) => caches.delete(k))
        );
        self.clients.claim();
      })()
    );
  });

  self.addEventListener("fetch", (event) => {
    const req = event.request;
    if (req.method !== "GET") return;

    const isApiCall = req.url.includes("api.frankfurter.app");

    if (isApiCall) {
      event.respondWith(
        fetch(req)
          .then((res) => {
            const clone = res.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
            return res;
          })
          .catch(() => caches.match(req))
      );
      return;
    }

    event.respondWith(
      caches.match(req).then((cached) => {
        if (cached) return cached;
        return fetch(req)
          .then((res) => {
            const clone = res.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
            return res;
          })
          .catch(() => cached);
      })
    );
  });
}
