// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
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

Future<void> openExternalUrl(String url) async {
  try {
    html.window.open(url, '_blank');
  } catch (_) {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
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
