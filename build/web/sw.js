var APP_VERSION = "1.0.47+67";
var CACHE_NAME = "redirect-fallback-" + APP_VERSION;
var OFFLINE_PAGE = "offline.html";
var STATIC_ASSETS = [
  "./",
  "index.html",
  "offline.html",
  "offline.js",
  "redirect-guard.js",
  "redirect-config.json"
];

self.addEventListener("install", function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys.map(function (key) {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener("fetch", function (event) {
  var request = event.request;
  var url = new URL(request.url);
  var acceptsHtml =
    request.mode === "navigate" ||
    (request.headers.get("accept") || "").indexOf("text/html") !== -1;

  if (request.url.indexOf("redirect-config.json") !== -1) {
    event.respondWith(
      fetch(request)
        .then(function (response) {
          var cloned = response.clone();
          caches.open(CACHE_NAME).then(function (cache) {
            cache.put("redirect-config.json", cloned);
          });
          return response;
        })
        .catch(function () {
          return caches.match("redirect-config.json");
        })
    );
    return;
  }

  if (acceptsHtml) {
    event.respondWith(
      fetch(request, { cache: "no-store" }).catch(function () {
        return caches.match(OFFLINE_PAGE);
      })
    );
    return;
  }

  if (url.origin === self.location.origin && url.search) {
    event.respondWith(
      fetch(request, { cache: "no-store" }).catch(function () {
        return caches.match(request);
      })
    );
    return;
  }

  event.respondWith(
    caches.match(request).then(function (cached) {
      return (
        cached ||
        fetch(request).catch(function () {
          return caches.match(OFFLINE_PAGE);
        })
      );
    })
  );
});
