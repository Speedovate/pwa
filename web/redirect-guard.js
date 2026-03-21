(function () {
  var CONFIG_URL = "redirect-config.json";
  var OFFLINE_URL = "offline.html";
  var STORAGE_KEY = "redirect-fallback-config";
  var ready = false;
  var timeoutId = null;

  function readStoredConfig() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (_) {
      return null;
    }
  }

  function writeStoredConfig(config) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
    } catch (_) {}
  }

  function goToOffline(reason) {
    if (ready) {
      return;
    }

    var url = OFFLINE_URL + "?reason=" + encodeURIComponent(reason || "app-timeout");
    window.location.replace(url);
  }

  function scheduleTimeout(config) {
    var delay = Number(config && config.appBootTimeoutMs) || 12000;
    window.clearTimeout(timeoutId);
    timeoutId = window.setTimeout(function () {
      goToOffline("app-timeout");
    }, delay);
  }

  function loadConfig() {
    return fetch(CONFIG_URL, { cache: "no-store" })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Config request failed");
        }

        return response.json();
      })
      .then(function (config) {
        writeStoredConfig(config);
        return config;
      })
      .catch(function () {
        return readStoredConfig() || {};
      });
  }

  window.__redirectGuard = {
    markAppReady: function () {
      ready = true;
      window.clearTimeout(timeoutId);
    },
    forceOffline: function () {
      goToOffline("manual");
    }
  };

  loadConfig().then(function (config) {
    if (config && config.enabled === false) {
      return;
    }

    scheduleTimeout(config);
  });
})();
