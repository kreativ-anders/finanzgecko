// sw.js — cached die App-Shell, damit die App offline startet.
// Versionsnummer bei jeder inhaltlichen Änderung hochzählen, damit
// Nutzer:innen automatisch die neue Version bekommen.

const CACHE_VERSION = "v1";
const CACHE_NAME = `vermoegenstracker-${CACHE_VERSION}`;

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

// Pico.css kommt vom CDN — best effort cachen, darf die Installation
// aber nicht blockieren, falls beim ersten Aufruf keine Verbindung besteht.
const CDN_ASSETS = ["https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"];

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
      const keys = await caches.keys();
      await Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)));
      self.clients.claim();
    })()
  );
});

// Cache-first für die App-Shell, Network-first (mit Cache-Fallback) für alles
// andere — z.B. die Frankfurter-API-Aufrufe, die immer möglichst frisch sein sollen.
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
