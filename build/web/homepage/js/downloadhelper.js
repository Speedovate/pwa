
let deferredPrompt;

window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault(); // stop auto prompt
    deferredPrompt = e; // save it
});

document.querySelectorAll(".button-cta").forEach(button => {
    button.addEventListener("click", async function () {

        const ua = navigator.userAgent;

        const isIOS = /iPhone|iPad|iPod/.test(ua) 
            || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

        const isAndroid = /android/i.test(ua);

        if (isIOS) {
            window.location.href = "https://apps.apple.com/us/app/ppc-toda/id6743928831";

        } else if (isAndroid) {

            if (deferredPrompt) {
                deferredPrompt.prompt();

                const choice = await deferredPrompt.userChoice;
                console.log("User choice:", choice.outcome);

                deferredPrompt = null;
            } else {
                // fallback if not eligible
                window.location.href = "/";
            }

        } else {
            window.location.href = "https://ppc-toda.com";
        }

    });
});
