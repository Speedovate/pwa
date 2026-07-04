// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

String browserUserAgent() => html.window.navigator.userAgent.toLowerCase();

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
    try {
      final touchPoints = globalContext
          .getProperty<JSObject>('navigator'.toJS)
          .getProperty<JSNumber?>('maxTouchPoints'.toJS);
      return (touchPoints?.toDartInt ?? 0) > 1;
    } catch (_) {
      return false;
    }
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
    final parsedUrl = Uri.tryParse(url);
    debugPrint(
      "[TEMP][OPEN_EXTERNAL_URL] sameTab=$sameTab url=$url currentHref=${html.window.location.href} currentOrigin=${html.window.location.origin} targetOrigin=${parsedUrl?.origin}",
    );
    if (sameTab) {
      debugPrint(
        "[TEMP][OPEN_EXTERNAL_URL_BRANCH] action=location.assign url=$url",
      );
      html.window.location.assign(url);
      debugPrint(
        "[TEMP][OPEN_EXTERNAL_URL_RESULT] action=location.assign status=dispatched url=$url",
      );
      return;
    }
    debugPrint("[TEMP][OPEN_EXTERNAL_URL_BRANCH] action=window.open url=$url");
    final openedWindow = html.window.open(url, '_blank');
    debugPrint(
      "[TEMP][OPEN_EXTERNAL_URL_RESULT] action=window.open status=dispatched url=$url windowHandleType=${openedWindow.runtimeType}",
    );
  } catch (error) {
    debugPrint(
      "[TEMP][OPEN_EXTERNAL_URL_BRANCH] action=launchUrlFallback url=$url error=$error",
    );
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    debugPrint(
      "[TEMP][OPEN_EXTERNAL_URL_RESULT] action=launchUrlFallback status=completed url=$url",
    );
  }
}

Future<void> refreshWebAppWithCacheBust() async {
  final location = html.window.location;
  final currentUri = Uri.parse(location.href);
  final updatedParams = Map<String, String>.from(currentUri.queryParameters);
  updatedParams['v'] = DateTime.now().millisecondsSinceEpoch.toString();
  final refreshedUri = currentUri.replace(queryParameters: updatedParams);
  location.assign(refreshedUri.toString());
}
