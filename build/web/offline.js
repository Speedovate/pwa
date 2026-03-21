(function () {
  var CONFIG_URL = "redirect-config.json";
  var STORAGE_KEY = "redirect-fallback-config";

  function $(id) {
    return document.getElementById(id);
  }

  function getReason() {
    var params = new URLSearchParams(window.location.search);
    return params.get("reason") || "offline";
  }

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

  function fetchConfig() {
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

  function render(config) {
    var primaryUrl = config.primaryUrl || "/";
    var backupUrl = config.backupUrl || "/";
    var delay = Number(config.autoRedirectMs) || 2500;
    var appName = config.appName || "Service";
    var statusMessage =
      config.statusMessage || "We are routing you to the current live service.";

    $("appName").textContent = appName;
    $("message").textContent = statusMessage;
    $("reasonValue").textContent = getReason();
    $("primaryValue").textContent = primaryUrl;
    $("backupValue").textContent = config.backupUrl || "Not configured";
    $("primaryLink").href = primaryUrl;
    $("backupLink").href = backupUrl;

    if (!config.backupUrl) {
      $("backupLink").setAttribute("aria-disabled", "true");
      $("backupLink").style.pointerEvents = "none";
      $("backupLink").style.opacity = "0.6";
    } else if (config.enabled !== false) {
      $("detail").textContent =
        "The app did not finish loading. We will open the backup site automatically.";
      $("title").textContent = "Main app unavailable";
      window.setTimeout(function () {
        window.location.replace(backupUrl);
      }, delay);
    }

    $("retryButton").addEventListener("click", function () {
      window.location.replace(primaryUrl);
    });
  }

  fetchConfig().then(render);
})();
