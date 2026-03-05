// MarketWatch Service Worker — network-first for data, cache for shell
const CACHE = 'marketwatch-v2';
const SHELL = ['./index.html'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  // Remove old caches
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  const isData = url.pathname.includes('/data/');
  const isLocal = url.origin === self.location.origin;

  if (!isLocal) return; // Don't intercept cross-origin (fonts etc)

  if (isData) {
    // Network-first: try fresh, fall back to cache on failure
    e.respondWith(
      fetch(e.request).then(res => {
        if (res.ok) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return res;
      }).catch(() => caches.match(e.request).then(r => r || new Response('{}', {
        headers: {'Content-Type': 'application/json'}
      })))
    );
  } else {
    // Cache-first for shell files
    e.respondWith(
      caches.match(e.request).then(r => r || fetch(e.request))
    );
  }
});
