var CACHE_NAME = "redirect-fallback-v1";
var TILE_CACHE_NAME = "map-tiles-v1";
var MAX_TILE_CACHE_ENTRIES = 300;
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
          if (key !== CACHE_NAME && key !== TILE_CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    })
  );
  self.clients.claim();
});

function isMapTileRequest(request) {
  if (request.method !== "GET") {
    return false;
  }
  try {
    var url = new URL(request.url);
    return (
      (url.hostname === "tile.osm.ch" &&
        url.pathname.indexOf("/switzerland/") !== -1) ||
      url.hostname === "tile.openstreetmap.org"
    );
  } catch (_) {
    return false;
  }
}

function trimTileCache(cache) {
  return cache.keys().then(function (keys) {
    if (keys.length <= MAX_TILE_CACHE_ENTRIES) {
      return;
    }

    var overflow = keys.length - MAX_TILE_CACHE_ENTRIES;
    var deletions = [];
    for (var i = 0; i < overflow; i += 1) {
      deletions.push(cache.delete(keys[i]));
    }
    return Promise.all(deletions);
  });
}

self.addEventListener("fetch", function (event) {
  var request = event.request;
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

  if (isMapTileRequest(request)) {
    event.respondWith(
      caches.open(TILE_CACHE_NAME).then(function (cache) {
        return cache.match(request).then(function (cached) {
          var networkFetch = fetch(request)
            .then(function (response) {
              if (response && (response.ok || response.type === "opaque")) {
                cache.put(request, response.clone()).then(function () {
                  trimTileCache(cache);
                });
              }
              return response;
            })
            .catch(function () {
              return cached;
            });

          return cached || networkFetch;
        });
      })
    );
    return;
  }

  if (acceptsHtml) {
    event.respondWith(
      fetch(request).catch(function () {
        return caches.match(OFFLINE_PAGE);
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
