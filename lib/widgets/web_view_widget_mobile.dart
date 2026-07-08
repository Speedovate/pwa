import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/utils/data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/branded_circular_loader.widget.dart';
import 'package:webview_flutter/webview_flutter.dart' as webview;
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_android;

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
  Timer? _mayaLoadingStopTimer;
  bool _hasBuyLoadProcessingState = false;
  bool _hasPaymentProcessingIssueState = false;
  String _currentUrl = "";
  static const String _gcashRumIngestHost = "rum-ingest.us1.signalfx.com";
  static const String _androidMobileChromeUserAgent =
      "Mozilla/5.0 (Linux; Android 14; 23076RN4BI) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";

  bool _isMayaCheckoutStopUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == "payments.paymaya.com" ||
        (host == "connect.paymaya.com" && path == "/login");
  }

  bool _isGcashCheckoutStopUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host == "payments.gcash.com" || host.endsWith(".payments.gcash.com");
  }

  bool _isCheckoutStopUrl(String rawUrl) {
    return _isMayaCheckoutStopUrl(rawUrl) || _isGcashCheckoutStopUrl(rawUrl);
  }

  String _normalizedPageUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return rawUrl.trim();
    }
    final normalizedQuery = Map.fromEntries(
      uri.queryParametersAll.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          queryParameters: normalizedQuery.isEmpty ? null : normalizedQuery,
          fragment: null,
        )
        .toString();
  }

  bool _shouldIgnoreStalePaymentLifecycleUrl(String callbackUrl) {
    return _isCheckoutStopUrl(_currentUrl) && !_isCheckoutStopUrl(callbackUrl);
  }

  bool _isDuplicateCheckoutStopLifecycleUrl(String callbackUrl) {
    return _isCheckoutStopUrl(_currentUrl) &&
        _isCheckoutStopUrl(callbackUrl) &&
        _normalizedPageUrl(_currentUrl) == _normalizedPageUrl(callbackUrl);
  }

  bool _isOfficialExternalPaymentPageUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == "payments.gcash.com" ||
        host.endsWith(".payments.gcash.com") ||
        host == "payments.paymaya.com" ||
        (host == "connect.paymaya.com" &&
            (path == "/login" || path == "/authorize")) ||
        host.contains("paymongo.com") ||
        (host.contains("assets.paymaya.com") && path.contains("/app/pwp"));
  }

  bool _shouldShowGenericLoadingForUrl(String rawUrl) {
    final normalized = rawUrl.toLowerCase();
    return normalized.contains("payment.wallet-top-up-livewire") ||
        normalized.contains("paymongo") ||
        normalized.contains("gcash") ||
        normalized.contains("maya");
  }

  void _cancelPendingMayaLoadingStop() {
    if (_mayaLoadingStopTimer != null) {
      tempTimerDebug(
        "webview.maya_loading_stop",
        "cancel",
        details: {
          "instanceId": tempTimerInstanceId(_mayaLoadingStopTimer),
        },
      );
    }
    _mayaLoadingStopTimer?.cancel();
    _mayaLoadingStopTimer = null;
  }

  void _scheduleMayaLoadingStop({required String targetUrl}) {
    final instanceId = nextTempTimerInstanceId("webview.maya_loading_stop");
    tempTimerDebug(
      "webview.maya_loading_stop",
      "schedule",
      details: {
        "instanceId": instanceId,
        "targetUrl": targetUrl,
      },
    );
    _cancelPendingMayaLoadingStop();
    _mayaLoadingStopTimer = Timer(const Duration(seconds: 1), () {
      _mayaLoadingStopTimer = null;
      tempTimerDebug(
        "webview.maya_loading_stop",
        "fire",
        details: {
          "instanceId": instanceId,
          "targetUrl": targetUrl,
          "currentUrl": _currentUrl,
        },
      );
      if (!mounted) {
        return;
      }
      if (_normalizedPageUrl(_currentUrl) != _normalizedPageUrl(targetUrl) ||
          !_isMayaCheckoutStopUrl(_currentUrl)) {
        return;
      }
      setState(() {
        _hasBuyLoadProcessingState = false;
        _hasPaymentProcessingIssueState = false;
        isLoading = false;
        showError = false;
      });
    });
    if (_mayaLoadingStopTimer != null) {
      attachTempTimerInstanceId(_mayaLoadingStopTimer!, instanceId);
    }
  }

  void _handlePaymentStateMessage(String message) {
    final normalizedMessage = message.toLowerCase();
    final isBuyLoadContext = widget.isFromWallet;
    final isTopUpClick = normalizedMessage.startsWith("click ") &&
        (normalizedMessage.contains("text=gcash") ||
            normalizedMessage.contains("text=maya"));
    final isTopUpRequestStart = normalizedMessage.startsWith("fetch start") &&
        normalizedMessage.contains("payment.wallet-top-up-livewire");
    if (isBuyLoadContext && (isTopUpClick || isTopUpRequestStart)) {
      if (!mounted || (isLoading && _hasBuyLoadProcessingState)) {
        return;
      }
      _cancelPendingMayaLoadingStop();
      setState(() {
        _hasBuyLoadProcessingState = true;
        isLoading = true;
        showError = false;
      });
      return;
    }

    final shouldShowLoading = normalizedMessage.contains(
          "processing your top-up",
        ) ||
        normalizedMessage.contains("payment processing issue");
    final hasPaymentProcessingIssue =
        normalizedMessage.contains("payment processing issue");
    if (!mounted || !isBuyLoadContext) {
      return;
    }
    if (normalizedMessage.startsWith("visible text changed")) {
      if (shouldShowLoading || hasPaymentProcessingIssue) {
        _cancelPendingMayaLoadingStop();
      }
      setState(() {
        _hasBuyLoadProcessingState = shouldShowLoading;
        _hasPaymentProcessingIssueState =
            _hasPaymentProcessingIssueState || hasPaymentProcessingIssue;
        isLoading = shouldShowLoading || _hasPaymentProcessingIssueState;
        showError = false;
      });
      return;
    }

    if (!shouldShowLoading || isLoading) {
      return;
    }
    _cancelPendingMayaLoadingStop();
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
            if (!mounted) {
              return;
            }
            if (_shouldIgnoreStalePaymentLifecycleUrl(url)) {
              return;
            }
            _cancelPendingMayaLoadingStop();
            if (_isDuplicateCheckoutStopLifecycleUrl(url)) {
              return;
            }
            final isOfficialExternalPaymentPage =
                _isOfficialExternalPaymentPageUrl(url);
            setState(() {
              _currentUrl = url;
              isLoading = _hasBuyLoadProcessingState ||
                  _hasPaymentProcessingIssueState ||
                  isOfficialExternalPaymentPage ||
                  _shouldShowGenericLoadingForUrl(url);
              showError = false;
            });
          },
          onPageFinished: (url) {
            unawaited(_applyWebviewCorsWorkaround());
            unawaited(_applyPaymentUiStateProbe());
            if (!mounted) {
              return;
            }
            if (_shouldIgnoreStalePaymentLifecycleUrl(url)) {
              return;
            }
            final isOfficialExternalPaymentPage =
                _isOfficialExternalPaymentPageUrl(url);
            final isCheckoutStopUrl = _isCheckoutStopUrl(url);
            final shouldDelayMayaStop = _isMayaCheckoutStopUrl(url);
            setState(() {
              _currentUrl = url;
              if (isCheckoutStopUrl) {
                if (shouldDelayMayaStop) {
                  isLoading = true;
                } else {
                  _hasBuyLoadProcessingState = false;
                  _hasPaymentProcessingIssueState = false;
                  isLoading = false;
                }
              } else if (_hasBuyLoadProcessingState ||
                  _hasPaymentProcessingIssueState) {
                isLoading = true;
              } else if (isOfficialExternalPaymentPage) {
                isLoading = true;
              } else {
                isLoading = false;
              }
              showError = false;
            });
            if (shouldDelayMayaStop) {
              _scheduleMayaLoadingStop(targetUrl: url);
            } else if (isCheckoutStopUrl) {
              _cancelPendingMayaLoadingStop();
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

          if (window.fetch && !window.__ppcTodaPaymentFetchStateProbe) {
            window.__ppcTodaPaymentFetchStateProbe = true;
            var originalFetch = window.fetch.bind(window);
            window.fetch = function(input, init) {
              var url = normalize(typeof input === "string" ? input : input && input.url);
              var method = normalize(init && init.method) || "GET";
              if (interesting.test(url)) {
                send("fetch start method=" + method + " url=" + url);
              }
              return originalFetch(input, init);
            };
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
  void dispose() {
    _cancelPendingMayaLoadingStop();
    super.dispose();
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
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: BrandedCircularLoader(),
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
