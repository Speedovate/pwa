import 'package:share_plus/share_plus.dart' as share_plugin;
import 'package:url_launcher/url_launcher.dart';

String browserUserAgent() => '';

bool isHuaweiLikeBrowser() => false;

bool isIOSLikeBrowser() => false;

bool isGoogleAuthLikelySupported() => true;

bool isWebPushLikelySupported() => false;

Future<bool> tryNativeShare({
  required String title,
  required String text,
  String? url,
}) async {
  final payload = [text, if (url != null && url.isNotEmpty) url].join(' ').trim();
  if (payload.isEmpty) {
    return false;
  }
  await share_plugin.Share.share(
    payload,
    subject: title,
  );
  return true;
}

Future<void> openExternalUrl(String url) async {
  await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> refreshWebAppWithCacheBust() async {}
