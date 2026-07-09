let deferredPrompt = null;
let isOpenMode = false;
let manifestUrl = null;
let appStartUrl = "/";

const installButtons = document.querySelectorAll(".button-cta");
const manifestLink = document.querySelector('link[rel="manifest"]');
let installProblemMessage =
  "Install is not available yet. Use your browser menu and choose Add to Home screen if supported.";

initializeDownloadInstall();

window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault();
  deferredPrompt = event;
  setButtonText("Install");
});

window.addEventListener("appinstalled", () => {
  deferredPrompt = null;
  setOpenMode();
});

installButtons.forEach((button) => {
  button.addEventListener("click", handleDownloadClick);
});

async function initializeDownloadInstall() {
  await Promise.all([registerServiceWorker(), initializeInstallState()]);
  await checkIfInstalled();
  setInterval(checkIfInstalled, 5000);
}

async function handleDownloadClick() {
  const ua = navigator.userAgent || "";
  const isIOS =
    /iPhone|iPad|iPod/.test(ua) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const isAndroid = /android/i.test(ua);

  if (isOpenMode) {
    window.location.href = appStartUrl;
    return;
  }

  if (isIOS) {
    window.location.href = "https://apps.apple.com/us/app/ppc-toda/id6743928831";
    return;
  }

  if (deferredPrompt) {
    deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    deferredPrompt = null;
    return;
  }

  if (isAndroid) {
    alert(installProblemMessage);
    return;
  }

  window.location.href = "https://ppc-toda.com";
}

async function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) {
    installProblemMessage =
      "Install is unavailable because this browser does not support service workers.";
    return;
  }

  try {
    const registration = await navigator.serviceWorker.register("/sw.js");
    await navigator.serviceWorker.ready;
    registration.update();
  } catch (error) {
    installProblemMessage =
      "Install is unavailable because the app could not start offline support.";
  }
}

async function initializeInstallState() {
  if (!manifestLink) {
    installProblemMessage =
      "Install is unavailable because the app manifest could not be found on this page.";
    return;
  }

  try {
    manifestUrl = new URL(manifestLink.getAttribute("href"), window.location.href);
    const response = await fetch(manifestUrl.href, { cache: "no-cache" });

    if (!response.ok) {
      installProblemMessage =
        "Install is unavailable because the app manifest could not be loaded.";
      return;
    }

    const manifest = await response.json();
    if (manifest.start_url) {
      appStartUrl = new URL(manifest.start_url, manifestUrl.href).href;
    }
  } catch (error) {
    installProblemMessage =
      "Install is unavailable because the app configuration could not be read.";
  }
}

async function checkIfInstalled() {
  try {
    if (navigator.getInstalledRelatedApps && manifestUrl) {
      const relatedApps = await navigator.getInstalledRelatedApps();
      const found = relatedApps.some(
        (app) => app.platform === "webapp" && app.url === manifestUrl.href,
      );

      if (found) {
        setOpenMode();
        return;
      }
    }
  } catch (_) {}

  if (
    window.matchMedia("(display-mode: standalone)").matches ||
    window.navigator.standalone === true
  ) {
    setOpenMode();
  }
}

function setOpenMode() {
  isOpenMode = true;
  setButtonText("Open App");
}

function setButtonText(text) {
  installButtons.forEach((button) => {
    button.textContent = text;
  });
}
