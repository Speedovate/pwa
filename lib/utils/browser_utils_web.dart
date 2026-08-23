// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';

String browserUserAgent() => html.window.navigator.userAgent.toLowerCase();

int browserMaxTouchPoints() {
  try {
    final touchPoints = globalContext
        .getProperty<JSObject>('navigator'.toJS)
        .getProperty<JSNumber?>('maxTouchPoints'.toJS);
    return touchPoints?.toDartInt ?? 0;
  } catch (_) {
    return 0;
  }
}

double browserScreenWidth() {
  return html.window.screen?.width?.toDouble() ??
      html.window.innerWidth?.toDouble() ??
      0;
}

double browserScreenHeight() {
  return html.window.screen?.height?.toDouble() ??
      html.window.innerHeight?.toDouble() ??
      0;
}

bool isTouchCapableBrowser() => browserMaxTouchPoints() > 0;

bool isPhoneLikeBrowser() {
  if (!isTouchCapableBrowser()) {
    return false;
  }
  final screenWidth = browserScreenWidth();
  final screenHeight = browserScreenHeight();
  if (screenWidth <= 0 || screenHeight <= 0) {
    return false;
  }
  final shortSide = math.min(screenWidth, screenHeight);
  final longSide = math.max(screenWidth, screenHeight);
  return shortSide <= 500 && longSide <= 1200;
}

double forcedMobileViewportWidth() {
  if (!isPhoneLikeBrowser()) {
    return html.window.innerWidth?.toDouble() ?? 0;
  }
  final shortSide = math.min(browserScreenWidth(), browserScreenHeight());
  final currentWidth = html.window.innerWidth?.toDouble() ?? shortSide;
  if (shortSide <= 0) {
    return currentWidth;
  }
  return math.min(currentWidth, shortSide);
}

bool isHuaweiLikeBrowser() {
  final userAgent = browserUserAgent();
  return userAgent.contains('huaweibrowser') || userAgent.contains('hmscore');
}

bool isIOSLikeBrowser() {
  final userAgent = browserUserAgent();
  if (userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod')) {
    return true;
  }
  if (userAgent.contains('macintosh')) {
    return browserMaxTouchPoints() > 1;
  }
  return false;
}

bool isGoogleAuthLikelySupported() => !isIOSLikeBrowser();

bool isWebPushLikelySupported() => html.window.navigator.serviceWorker != null;

bool isBrowserOnline() => html.window.navigator.onLine ?? true;

Future<bool> tryNativeShare({
  required String title,
  required String text,
  String? url,
}) async {
  try {
    await html.window.navigator.share(
      {
        'title': title,
        'text': text,
        if (url != null && url.isNotEmpty) 'url': url,
      },
    );
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> openExternalUrl(
  String url, {
  bool sameTab = false,
}) async {
  try {
    if (sameTab) {
      html.window.location.assign(url);
      return;
    }
    html.window.open(url, '_blank');
  } catch (error) {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
}

Object? prepareExternalUrlWindow({
  bool sameTab = false,
}) {
  if (sameTab) {
    return null;
  }
  try {
    return html.window.open('', '_blank');
  } catch (_) {
    return null;
  }
}

Future<void> navigatePreparedExternalUrl(
  Object? handle,
  String url, {
  bool sameTab = false,
}) async {
  if (sameTab) {
    html.window.location.assign(url);
    return;
  }
  try {
    final preparedWindow = handle as html.WindowBase?;
    if (preparedWindow != null) {
      preparedWindow.location.href = url;
      return;
    }
  } catch (_) {}
  await openExternalUrl(
    url,
    sameTab: sameTab,
  );
}

void closePreparedExternalUrl(Object? handle) {
  try {
    final preparedWindow = handle as html.WindowBase?;
    preparedWindow?.close();
  } catch (_) {}
}

Future<void> refreshWebAppWithCacheBust() async {
  final location = html.window.location;
  final currentUri = Uri.parse(location.href);
  final updatedParams = Map<String, String>.from(currentUri.queryParameters);
  updatedParams['v'] = DateTime.now().millisecondsSinceEpoch.toString();
  final refreshedUri = currentUri.replace(queryParameters: updatedParams);
  location.assign(refreshedUri.toString());
}
