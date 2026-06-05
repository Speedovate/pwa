import 'package:flutter/material.dart';

String sanitizeImageUrl(dynamic rawUrl) {
  final value = rawUrl?.toString().trim() ?? "";
  if (value.isEmpty || value.toLowerCase() == "null") {
    return "";
  }

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return "";
  }

  const supportedSchemes = {"http", "https", "data", "blob"};
  if (!supportedSchemes.contains(uri.scheme.toLowerCase())) {
    return "";
  }

  return value;
}

ImageProvider? safeNetworkImageProvider(
  dynamic rawUrl, {
  int? cacheWidth,
}) {
  final imageUrl = sanitizeImageUrl(rawUrl);
  if (imageUrl.isEmpty) {
    return null;
  }

  final provider = NetworkImage(
    imageUrl,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
  );
  if (cacheWidth == null) {
    return provider;
  }

  return ResizeImage.resizeIfNeeded(
    cacheWidth,
    null,
    provider,
  );
}

typedef ProgressIndicatorBuilder = Widget Function(
  BuildContext context,
  String url,
  double? progress,
);
typedef ErrorWidgetBuilder = Widget Function(
  BuildContext context,
  String url,
  dynamic error,
);

class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final ProgressIndicatorBuilder? progressIndicatorBuilder;
  final ErrorWidgetBuilder? errorWidget;

  const NetworkImageWidget({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 600,
    this.progressIndicatorBuilder,
    this.errorWidget,
    super.key,
  });

  Widget _buildFramedState(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : null);
        final resolvedHeight = height ??
            (constraints.hasBoundedHeight ? constraints.maxHeight : null);

        return SizedBox(
          width: resolvedWidth,
          height: resolvedHeight,
          child: Center(
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeImageUrl = sanitizeImageUrl(imageUrl);

    if (safeImageUrl.isEmpty) {
      return _buildFramedState(
        errorWidget != null
            ? errorWidget!(context, imageUrl, "Invalid image URL")
            : const Center(
                child: Icon(Icons.error),
              ),
      );
    }

    return Image.network(
      safeImageUrl,
      cacheWidth: memCacheWidth,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildFramedState(
          progressIndicatorBuilder != null
              ? progressIndicatorBuilder!(
                  context,
                  safeImageUrl,
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                )
              : Center(
                  child: CircularProgressIndicator(
                    strokeCap: StrokeCap.round,
                    color: const Color(
                      0xFF007BFF,
                    ),
                    backgroundColor: const Color(
                      0xFF007BFF,
                    ).withValues(alpha: 0.25),
                  ),
                ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildFramedState(
          errorWidget != null
              ? errorWidget!(context, safeImageUrl, error)
              : const Center(
                  child: Icon(Icons.error),
                ),
        );
      },
    );
  }
}
