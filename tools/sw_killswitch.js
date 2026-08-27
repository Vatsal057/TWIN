// Kill switch for the old Flutter service worker.
//
// This app no longer uses a service worker (tools/build_web.sh passes
// --pwa-strategy=none). Simply deleting the file is not enough: a browser that
// already registered the old worker serves the cached index.html from it, so any
// cleanup script inside the page never gets a chance to run. Those visitors
// would be stuck on a stale build forever.
//
// Instead we keep the same filename and put a worker here whose only job is to
// remove itself. The browser notices this file differs from the one it has,
// installs it, and this runs:
//
//   1. take over immediately instead of waiting for tabs to close
//   2. delete every cache the old worker created
//   3. unregister
//   4. reload any open tab so it picks up the real, current build
//
// firebase.json serves this with Cache-Control: no-cache so the update is seen.
//
// Safe to keep indefinitely. Once a browser has run it there is no registration
// left, and it is never fetched again.

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    (async function () {
      try {
        const keys = await caches.keys();
        await Promise.all(keys.map(function (key) { return caches.delete(key); }));
      } catch (e) {
        // Clearing caches is best effort; unregistering matters more.
      }

      await self.registration.unregister();

      const clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach(function (client) {
        client.navigate(client.url);
      });
    })(),
  );
});

// Pass every request straight through while this worker is briefly alive.
self.addEventListener('fetch', function () {});
