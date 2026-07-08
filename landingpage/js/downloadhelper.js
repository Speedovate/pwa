
document.querySelectorAll(".button-cta").forEach(button => {
    button.addEventListener("click", function () {

        const ua = navigator.userAgent;

        const isIOS = /iPhone|iPad|iPod/.test(ua) 
            || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

        const isAndroid = /android/i.test(ua);

        if (isIOS) {
            window.location.href = "https://apps.apple.com/us/app/ppc-toda/id6743928831";
        } else if (isAndroid) {
            window.location.href = "https://ppc-toda.com/download";
        } else {
            window.location.href = "https://ppc-toda.com";
        }

    });
});
