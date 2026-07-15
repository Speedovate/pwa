let deferredPrompt = null;
const installBtn = document.getElementById("installPwa");
const manifestLink = document.querySelector('link[rel="manifest"]');
let isOpenMode = false;
let manifestUrl = null;
let appStartUrl = "/";
let installProblemMessage = "Install is not available yet. Use your browser menu and choose 'Add to Home screen' if supported.";

initializeInstallState();

if (!installBtn) {
  console.warn("Install button with id 'installPwa' was not found.");
} else {
  installBtn.onclick = async () => {
    if (isOpenMode) {
      const isStandalone =
        window.matchMedia("(display-mode: standalone)").matches ||
        window.navigator.standalone === true;

      if (isStandalone) {
        alert("The app is already installed. You can open it from your home screen or app launcher.");
        return;
      }

      window.location.href = appStartUrl;
      return;
    }

    if (deferredPrompt) {
      deferredPrompt.prompt();
      await deferredPrompt.userChoice;
      deferredPrompt = null;
      return;
    }

    // Fallback for browsers that don't fire beforeinstallprompt.
    if (/iphone|ipad|ipod/i.test(navigator.userAgent)) {
      alert("To install: tap Share, then 'Add to Home Screen'.");
      return;
    }

    alert(installProblemMessage);
  };

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    deferredPrompt = event;
    installBtn.textContent = "Install";
  });

  window.addEventListener("appinstalled", () => {
    deferredPrompt = null;
    setOpenApp();
  });

  checkIfInstalled();
  setInterval(checkIfInstalled, 5000);
}

async function initializeInstallState() {
  if (!manifestLink) {
    installProblemMessage = "Install is unavailable because the app manifest could not be found on this page.";
    return;
  }

  try {
    manifestUrl = new URL(manifestLink.getAttribute("href"), window.location.href);
    const response = await fetch(manifestUrl.href, { cache: "no-cache" });
    if (!response.ok) {
      installProblemMessage = "Install is unavailable because the app manifest could not be loaded.";
      return;
    }

    const manifest = await response.json();
    if (manifest.start_url) {
      appStartUrl = new URL(manifest.start_url, manifestUrl.href).href;
    }
  } catch (error) {
    installProblemMessage = "Install is unavailable because the app configuration could not be read.";
  }
}

async function checkIfInstalled() {
  try {
    if (navigator.getInstalledRelatedApps && manifestUrl) {
      const relatedApps = await navigator.getInstalledRelatedApps();
      const found = relatedApps.some(
        (app) => app.platform === "webapp" && app.url === manifestUrl.href
      );
      if (found) {
        setOpenApp();
        return;
      }
    }
  } catch (_) {}

  if (
    window.matchMedia("(display-mode: standalone)").matches ||
    window.navigator.standalone === true
  ) {
    setOpenApp();
  }
}

function setOpenApp() {
  isOpenMode = true;
  installBtn.style.display = "flex";
  installBtn.style.backgroundColor = "#1A73E8";
  installBtn.style.color = "#ffffff";
  installBtn.textContent = "Open App";
}
