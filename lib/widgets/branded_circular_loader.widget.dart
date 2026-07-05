import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/utils/order_status_style.dart';
import 'package:pwa/widgets/network_image.widget.dart';

class BrandedCircularLoader extends StatelessWidget {
  const BrandedCircularLoader({
    super.key,
    this.imageUrl = AppImages.loading,
    this.imageColor,
    this.loaderSize = 120,
    this.ringSize = 150,
    this.imagePadding = const EdgeInsets.only(
      top: 16,
      left: 16,
      right: 16,
      bottom: 18,
    ),
  });

  final String imageUrl;
  final Color? imageColor;
  final double loaderSize;
  final double ringSize;
  final EdgeInsets imagePadding;

  bool get _isAssetImage => imageUrl.startsWith(AppImages.assetBasePath);

  Widget _buildImage() {
    if (_isAssetImage) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        color: imageColor,
        colorBlendMode: imageColor == null ? null : BlendMode.srcIn,
      );
    }

    final networkImage = NetworkImageWidget(
      imageUrl: imageUrl,
      memCacheWidth: 600,
      fit: BoxFit.cover,
    );

    if (imageColor == null) {
      return networkImage;
    }

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        imageColor!,
        BlendMode.srcIn,
      ),
      child: networkImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: loaderSize,
      height: loaderSize,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: imagePadding,
              child: _buildImage(),
            ),
          ),
          Center(
            child: SizedBox(
              width: ringSize,
              height: ringSize,
              child: CircularProgressIndicator(
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                color: orderStatusActiveColor,
                backgroundColor: orderStatusActiveColor.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
