function openInBrowser() {
        const url = window.location.href;

        if (/android/i.test(navigator.userAgent)) {
          window.location.href =
            "intent://" +
            url.replace(/^https?:\/\//, "") +
            "#Intent;scheme=https;package=com.android.chrome;end";
        } else if (/iphone|ipad|ipod/i.test(navigator.userAgent)) {
          window.location.href = url;
        }
      }

      function detectWebview() {
        const ua =
          navigator.userAgent || navigator.vendor || window.opera || "";

        return /(Telegram|WebView|wv|FBAN|FBAV|Instagram|Line|TikTok|Twitter)/i.test(
          ua,
        );
      }

      if (detectWebview() && !sessionStorage.getItem("redirected")) {
        sessionStorage.setItem("redirected", "true");
        openInBrowser();
      }