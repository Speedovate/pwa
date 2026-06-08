import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_android;
import 'package:webview_flutter/webview_flutter.dart' as webview;

class WebViewWidget extends StatefulWidget {
  const WebViewWidget({
    required this.title,
    this.isFromWallet = false,
    required this.selectedUrl,
    super.key,
  });

  final String title;
  final bool isFromWallet;
  final Uri selectedUrl;

  @override
  State<WebViewWidget> createState() => _WebViewWidgetState();
}

class _WebViewWidgetState extends State<WebViewWidget> {
  bool showError = false;
  bool isLoading = true;
  late final webview.WebViewController _controller;
  static const String _gcashRumIngestHost = "rum-ingest.us1.signalfx.com";
  static const String _androidMobileChromeUserAgent =
      "Mozilla/5.0 (Linux; Android 14; 23076RN4BI) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";

  void _handlePaymentStateMessage(String message) {
    final normalizedMessage = message.toLowerCase();
    final shouldShowLoading =
        normalizedMessage.contains("payment processing issue") ||
            normalizedMessage.contains("processing your top-up") ||
            (normalizedMessage.contains("fetch start") &&
                normalizedMessage.contains("payment.wallet-top-up-livewire"));
    if (!shouldShowLoading) {
      return;
    }
    if (!mounted || isLoading) {
      return;
    }
    setState(() {
      isLoading = true;
      showError = false;
    });
  }

  @override
  void initState() {
    super.initState();
    final controller = webview.WebViewController.fromPlatformCreationParams(
      const webview.PlatformWebViewControllerCreationParams(),
    );
    if (controller.platform is webview_android.AndroidWebViewController) {
      (controller.platform as webview_android.AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
      unawaited(controller.setUserAgent(_androidMobileChromeUserAgent));
    }
    _controller = controller
      ..setJavaScriptMode(webview.JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        "PaymentState",
        onMessageReceived: (message) {
          _handlePaymentStateMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        webview.NavigationDelegate(
          onNavigationRequest: (webview.NavigationRequest request) {
            final requestUrl = request.url.trim();
            final uri = Uri.tryParse(requestUrl);
            final scheme = uri?.scheme.toLowerCase() ?? "";
            if (scheme == "gcash" ||
                requestUrl.toLowerCase().startsWith("gcash://")) {
              unawaited(_launchExternalUri(uri));
              return webview.NavigationDecision.prevent;
            }
            if (scheme == "intent" &&
                requestUrl.toLowerCase().contains("gcash")) {
              final fallback = _extractIntentBrowserFallbackUrl(requestUrl);
              if (fallback != null) {
                unawaited(_launchExternalUri(Uri.parse(fallback)));
              }
              return webview.NavigationDecision.prevent;
            }
            return webview.NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            unawaited(_applyWebviewCorsWorkaround());
            unawaited(_applyPaymentUiStateProbe());
            if (mounted) {
              setState(() {
                isLoading = true;
                showError = false;
              });
            }
          },
          onPageFinished: (url) {
            unawaited(_applyWebviewCorsWorkaround());
            unawaited(_applyPaymentUiStateProbe());
            if (mounted) {
              setState(() {
                isLoading = false;
                showError = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                showError = true;
                isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(widget.selectedUrl);
  }

  Future<void> _launchExternalUri(Uri? uri) async {
    if (uri == null) {
      return;
    }
    try {
      if (!await _confirmGcashLaunchIfNeeded()) {
        return;
      }
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<bool> _confirmGcashLaunchIfNeeded() async {
    final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
    if (!isMobile || !widget.isFromWallet) {
      return true;
    }

    bool shouldProceed = false;
    await AlertService().showAppAlert(
      title: "Are you sure?",
      content: "Do you have a screenshot already?",
      hideCancel: false,
      confirmText: "Yes",
      confirmColor: Colors.red,
      cancelText: "No",
      cancelAction: () {
        Get.back();
      },
      confirmAction: () {
        shouldProceed = true;
        Get.back();
      },
    );
    return shouldProceed;
  }

  String? _extractIntentBrowserFallbackUrl(String intentUrl) {
    const marker = "S.browser_fallback_url=";
    final start = intentUrl.indexOf(marker);
    if (start < 0) {
      return null;
    }
    final valueStart = start + marker.length;
    final end = intentUrl.indexOf(';', valueStart);
    final rawValue = end >= 0
        ? intentUrl.substring(valueStart, end)
        : intentUrl.substring(valueStart);
    return Uri.decodeComponent(rawValue);
  }

  Future<void> _applyWebviewCorsWorkaround() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          if (window.__ppcTodaGcashRumPatched) {
            return;
          }
          window.__ppcTodaGcashRumPatched = true;
          var blockedHost = "$_gcashRumIngestHost";
          var shouldBlock = function(input) {
            try {
              var raw = "";
              if (typeof input === "string") {
                raw = input;
              } else if (input && typeof input.url === "string") {
                raw = input.url;
              }
              return raw.indexOf(blockedHost) !== -1;
            } catch (e) {
              return false;
            }
          };

          if (window.fetch) {
            var originalFetch = window.fetch.bind(window);
            window.fetch = function(input, init) {
              if (shouldBlock(input)) {
                return Promise.resolve(
                  new Response("", {
                    status: 204,
                    statusText: "No Content"
                  })
                );
              }
              return originalFetch(input, init);
            };
          }

          if (window.XMLHttpRequest) {
            var OriginalXHR = window.XMLHttpRequest;
            function PatchedXHR() {
              var xhr = new OriginalXHR();
              var targetUrl = "";
              var originalOpen = xhr.open;
              var originalSend = xhr.send;

              xhr.open = function(method, url) {
                targetUrl = url || "";
                return originalOpen.apply(xhr, arguments);
              };

              xhr.send = function() {
                if (shouldBlock(targetUrl)) {
                  try {
                    Object.defineProperty(xhr, "readyState", {
                      configurable: true,
                      get: function() { return 4; }
                    });
                    Object.defineProperty(xhr, "status", {
                      configurable: true,
                      get: function() { return 204; }
                    });
                    Object.defineProperty(xhr, "responseText", {
                      configurable: true,
                      get: function() { return ""; }
                    });
                  } catch (e) {}
                  if (typeof xhr.onreadystatechange === "function") {
                    xhr.onreadystatechange();
                  }
                  if (typeof xhr.onload === "function") {
                    xhr.onload();
                  }
                  return;
                }
                return originalSend.apply(xhr, arguments);
              };
              return xhr;
            }
            window.XMLHttpRequest = PatchedXHR;
          }
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _applyPaymentUiStateProbe() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          if (window.__ppcTodaPaymentUiStateProbe) {
            return;
          }
          window.__ppcTodaPaymentUiStateProbe = true;

          var send = function(message) {
            try {
              PaymentState.postMessage(String(message).slice(0, 900));
            } catch (e) {}
          };

          var normalize = function(value) {
            return String(value || "").replace(/\\s+/g, " ").trim();
          };

          var interesting = /payment|processing|issue|error|failed|fail|gcash|maya|paymongo|checkout|wallet|load|top.?up|invalid|declined|success/i;
          var lastText = "";

          var scanVisibleText = function(reason) {
            try {
              var bodyText = normalize(document.body && document.body.innerText);
              if (!bodyText || bodyText === lastText) {
                return;
              }
              lastText = bodyText;
              if (interesting.test(bodyText)) {
                send("visible text changed reason=" + reason + " text=" + bodyText.slice(0, 900));
              }
            } catch (e) {
              send("visible text scan error=" + e);
            }
          };

          var describeElement = function(element) {
            try {
              if (!element) {
                return "null";
              }
              var attrs = [];
              if (element.id) attrs.push("#" + element.id);
              if (element.className && typeof element.className === "string") {
                attrs.push("." + normalize(element.className).replace(/ /g, "."));
              }
              var label = normalize(
                element.innerText ||
                element.value ||
                element.getAttribute("aria-label") ||
                element.getAttribute("name") ||
                element.getAttribute("type") ||
                element.tagName
              );
              return element.tagName + attrs.join("") + " text=" + label.slice(0, 250);
            } catch (e) {
              return "describe error=" + e;
            }
          };

          document.addEventListener("click", function(event) {
            send("click " + describeElement(event.target));
            setTimeout(function() { scanVisibleText("afterClick"); }, 250);
            setTimeout(function() { scanVisibleText("afterClickDelay"); }, 1200);
          }, true);

          document.addEventListener("submit", function(event) {
            send("submit " + describeElement(event.target));
            setTimeout(function() { scanVisibleText("afterSubmit"); }, 250);
          }, true);

          window.addEventListener("error", function(event) {
          });

          window.addEventListener("unhandledrejection", function(event) {
          });

          if (window.fetch && !window.__ppcTodaPaymentFetchStateProbe) {
            window.__ppcTodaPaymentFetchStateProbe = true;
            var originalFetch = window.fetch.bind(window);
            window.fetch = function(input, init) {
              var url = normalize(typeof input === "string" ? input : input && input.url);
              var method = normalize(init && init.method) || "GET";
              if (interesting.test(url)) {
                send("fetch start method=" + method + " url=" + url);
              }
              return originalFetch(input, init).then(function(response) {
                if (interesting.test(url) || !response.ok) {
                  send("fetch done status=" + response.status + " ok=" + response.ok + " url=" + url);
                  try {
                    response.clone().text().then(function(body) {
                      var text = normalize(body);
                      if (interesting.test(text)) {
                        send("fetch body url=" + url + " body=" + text.slice(0, 900));
                      }
                    }).catch(function(error) {
                      send("fetch body read error url=" + url + " error=" + error);
                    });
                  } catch (e) {
                    send("fetch body clone error url=" + url + " error=" + e);
                  }
                }
                return response;
              }).catch(function(error) {
                send("fetch error url=" + url + " error=" + error);
                throw error;
              });
            };
          }

          if (window.XMLHttpRequest && !window.__ppcTodaPaymentXhrStateProbe) {
            window.__ppcTodaPaymentXhrStateProbe = true;
            var OriginalXHR = window.XMLHttpRequest;
            function StateProbeXHR() {
              var xhr = new OriginalXHR();
              var targetUrl = "";
              var method = "";
              var originalOpen = xhr.open;
              xhr.open = function(nextMethod, url) {
                method = normalize(nextMethod);
                targetUrl = normalize(url);
                if (interesting.test(targetUrl)) {
                  send("xhr open method=" + method + " url=" + targetUrl);
                }
                return originalOpen.apply(xhr, arguments);
              };
              xhr.addEventListener("loadend", function() {
                if (interesting.test(targetUrl) || xhr.status >= 400) {
                  send("xhr done status=" + xhr.status + " method=" + method + " url=" + targetUrl);
                  try {
                    var text = normalize(xhr.responseText);
                    if (interesting.test(text)) {
                      send("xhr body url=" + targetUrl + " body=" + text.slice(0, 900));
                    }
                  } catch (e) {
                    send("xhr body read error url=" + targetUrl + " error=" + e);
                  }
                }
              });
              xhr.addEventListener("error", function() {
                send("xhr error method=" + method + " url=" + targetUrl);
              });
              return xhr;
            }
            window.XMLHttpRequest = StateProbeXHR;
          }

          try {
            new MutationObserver(function() {
              scanVisibleText("mutation");
            }).observe(document.documentElement || document.body, {
              childList: true,
              subtree: true,
              characterData: true
            });
          } catch (e) {
          }

          scanVisibleText("install");
          setTimeout(function() { scanVisibleText("installDelay"); }, 1000);
        })();
      ''');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = const Color(0xFF030744).withValues(alpha: 0.1);
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.only(
          top: mediaQuery.padding.top,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 4),
                WidgetButton(
                  onTap: () {
                    Get.back();
                  },
                  child: const SizedBox(
                    width: 58,
                    height: 58,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 2,
                          right: 4,
                          bottom: 2,
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: Color(0xFF030744),
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  widget.title,
                  style: const TextStyle(
                    height: 1,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF030744),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: dividerColor),
            Expanded(
              child: Stack(
                children: [
                  if (!showError)
                    webview.WebViewWidget(
                      controller: _controller,
                    ),
                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              width: 120,
                              height: 120,
                              child: Stack(
                                children: [
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: 16,
                                        left: 16,
                                        right: 16,
                                        bottom: 18,
                                      ),
                                      child: NetworkImageWidget(
                                        imageUrl: AppImages.logo,
                                        memCacheWidth: 600,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: SizedBox(
                                      width: 150,
                                      height: 150,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 10,
                                        strokeCap: StrokeCap.round,
                                        color: const Color(0xFF007BFF),
                                        backgroundColor: const Color(0xFF007BFF)
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showError)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.web_asset_off,
                              size: 75,
                              color: Color(0xFF007BFF),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "An error occurred. Try again later",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0x80030744),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
