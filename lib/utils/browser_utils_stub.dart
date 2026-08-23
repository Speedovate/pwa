import 'package:share_plus/share_plus.dart' as share_plugin;
import 'package:url_launcher/url_launcher.dart';

String browserUserAgent() => '';

bool isHuaweiLikeBrowser() => false;

bool isIOSLikeBrowser() => false;

bool isGoogleAuthLikelySupported() => true;

bool isWebPushLikelySupported() => false;

bool isBrowserOnline() => true;

Future<bool> tryNativeShare({
  required String title,
  required String text,
  String? url,
}) async {
  final payload =
      [text, if (url != null && url.isNotEmpty) url].join(' ').trim();
  if (payload.isEmpty) {
    return false;
  }
  await share_plugin.Share.share(
    payload,
    subject: title,
  );
  return true;
}

Future<void> openExternalUrl(
  String url, {
  bool sameTab = false,
}) async {
  await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
}

Object? prepareExternalUrlWindow({
  bool sameTab = false,
}) {
  return null;
}

Future<void> navigatePreparedExternalUrl(
  Object? handle,
  String url, {
  bool sameTab = false,
}) async {
  await openExternalUrl(
    url,
    sameTab: sameTab,
  );
}

void closePreparedExternalUrl(Object? handle) {}

Future<void> refreshWebAppWithCacheBust() async {}
