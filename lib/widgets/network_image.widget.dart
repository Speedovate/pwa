import 'package:flutter/material.dart';

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
    this.memCacheWidth,
    this.progressIndicatorBuilder,
    this.errorWidget,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget != null
          ? errorWidget!(context, imageUrl, "Empty URL")
          : SizedBox(
              width: width,
              height: height,
              child: const Center(child: Icon(Icons.error)),
            );
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return progressIndicatorBuilder != null
            ? progressIndicatorBuilder!(
                context,
                imageUrl,
                loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              )
            : SizedBox(
                width: width,
                height: height,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeCap: StrokeCap.round,
                    color: Color(
                      0xFF007BFF,
                    ),
                    backgroundColor: Color(
                      0xFF007BFF,
                    ).withOpacity(0.25),
                  ),
                ),
              );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget != null
            ? errorWidget!(context, imageUrl, error)
            : SizedBox(
                width: width,
                height: height,
                child: const Center(child: Icon(Icons.error)),
              );
      },
    );
  }
}
