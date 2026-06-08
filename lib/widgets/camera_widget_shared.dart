import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/widgets/button.widget.dart';

Uint8List? webChatBytes;
Uint8List? webProfileBytes;
Uint8List? pickedImageBytes;

String cameraTitleForType(String cameraType) {
  if (cameraType == "chat") {
    return "Capture Photo";
  } else if (cameraType == "vehicle") {
    return "Vehicle Photo";
  } else if (cameraType == "vPapers") {
    return "Vehicle Papers";
  } else if (cameraType == "license") {
    return "driver's License";
  } else {
    return "Profile Photo";
  }
}

String cameraInstructionTextForType(
  String cameraType, {
  required bool isCapturedPreview,
}) {
  if (isCapturedPreview) {
    return "Please review your captured photo.";
  }

  if (cameraType == "profile") {
    return "Center your face within the frame.";
  } else if (cameraType == "vehicle") {
    return "Center your vehicle within the frame.";
  } else if (cameraType == "vPapers") {
    return "Position the document within the frame.";
  } else if (cameraType == "license") {
    return "Center your license within the frame.";
  } else {
    return "Center your subject within the frame.";
  }
}

class CameraShellLayout extends StatelessWidget {
  final String title;
  final bool isMobile;
  final VoidCallback onBack;
  final Widget stage;
  final Widget bottomChild;
  final bool hideBottomArea;

  const CameraShellLayout({
    required this.title,
    required this.isMobile,
    required this.onBack,
    required this.stage,
    required this.bottomChild,
    this.hideBottomArea = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return SizedBox(
      height: mediaQuery.size.height,
      child: Padding(
        padding: EdgeInsets.only(
          top: mediaQuery.padding.top,
          bottom: mediaQuery.padding.bottom,
        ),
        child: Column(
          children: [
            Container(
              width: mediaQuery.size.width,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 2,
                    spreadRadius: 2,
                    offset: Offset(0, 2),
                    color: Colors.white,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      WidgetButton(
                        onTap: onBack,
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
                        title,
                        style: const TextStyle(
                          height: 1,
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF030744),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: stage,
              ),
            ),
            if (!hideBottomArea)
              Container(
                width: mediaQuery.size.width,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 2,
                      spreadRadius: 2,
                      offset: Offset(0, -2),
                      color: Colors.white,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: bottomChild,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CameraUnavailableState extends StatelessWidget {
  const CameraUnavailableState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.no_photography_outlined,
          color: const Color(0xFF030744).withValues(alpha: 0.5),
          size: 75,
        ),
        const SizedBox(height: 12),
        Text(
          "Camera unavailable",
          style: TextStyle(
            height: 1,
            fontSize: 20,
            color: const Color(0xFF030744).withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Please check your camera and try again",
          textAlign: TextAlign.center,
          style: TextStyle(
            height: 1,
            color: const Color(0xFF030744).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class CameraOverlayGuide extends StatelessWidget {
  final String cameraType;
  final bool isCapturedPreview;
  final bool isProfile;

  const CameraOverlayGuide({
    required this.cameraType,
    required this.isCapturedPreview,
    required this.isProfile,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 0,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 2,
                          spreadRadius: 2,
                          offset: Offset(2, 0),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            isProfile ? AppImages.selfie : AppImages.camera,
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                        Flexible(
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 2,
                                  spreadRadius: 2,
                                  offset: Offset(0, -2),
                                  color: Colors.white,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFF030744).withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  cameraInstructionTextForType(
                                    cameraType,
                                    isCapturedPreview: isCapturedPreview,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF030744),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 0,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 2,
                          spreadRadius: 2,
                          offset: Offset(-2, 0),
                          color: Colors.white,
                        ),
                      ],
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

class CameraStageLayout extends StatelessWidget {
  final Widget child;
  final bool isProfile;
  final String cameraType;
  final bool isCapturedPreview;
  final double maxWidth;
  final double aspectRatio;

  const CameraStageLayout({
    required this.child,
    required this.isProfile,
    required this.cameraType,
    required this.isCapturedPreview,
    required this.maxWidth,
    required this.aspectRatio,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final safeAspectRatio = aspectRatio <= 0 ? 1.0 : aspectRatio;
        final boundedWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : maxWidth;
        final boundedHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;

        double resolvedWidth =
            maxWidth < boundedWidth ? maxWidth : boundedWidth;
        if (boundedHeight.isFinite) {
          final maxWidthFromHeight = boundedHeight * safeAspectRatio;
          if (resolvedWidth > maxWidthFromHeight) {
            resolvedWidth = maxWidthFromHeight;
          }
        }
        if (resolvedWidth <= 0) {
          resolvedWidth = boundedWidth > 0 ? boundedWidth : maxWidth;
        }

        return SizedBox(
          width: resolvedWidth,
          child: AspectRatio(
            aspectRatio: safeAspectRatio,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isProfile ? 0 : 10),
                    child: child,
                  ),
                ),
                Positioned.fill(
                  child: CameraOverlayGuide(
                    cameraType: cameraType,
                    isCapturedPreview: isCapturedPreview,
                    isProfile: isProfile,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CameraGuideOverlay extends StatelessWidget {
  final bool isProfile;
  final double width;

  const CameraGuideOverlay({
    required this.isProfile,
    required this.width,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: SizedBox(
        width: width,
        child: Stack(
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                isProfile ? AppImages.selfie : AppImages.camera,
                width: width,
                fit: BoxFit.fitWidth,
              ),
            ),
            if (isProfile)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            if (isProfile)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white,
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            if (isProfile)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            if (isProfile)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.white,
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CameraPreviewStage extends StatelessWidget {
  final Widget child;
  final bool isProfile;
  final double width;
  final double height;

  const CameraPreviewStage({
    required this.child,
    required this.isProfile,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isProfile ? 0 : 10),
              child: child,
            ),
          ),
          CameraGuideOverlay(
            isProfile: isProfile,
            width: width,
          ),
        ],
      ),
    );
  }
}

Future<Uint8List> normalizeImageToJpegWeb(
  Uint8List imageBytes, {
  bool mirror = false,
}) async {
  return imageBytes;
}

class CameraImageWidget extends StatelessWidget {
  final Uint8List imageBytes;
  final bool isEdit;
  final String cameraType;
  final bool replacedCaptureRoute;
  final VoidCallback? onRetake;

  const CameraImageWidget({
    required this.imageBytes,
    required this.isEdit,
    required this.cameraType,
    this.replacedCaptureRoute = false,
    this.onRetake,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
    final previewWidth = isMobile
        ? mediaQuery.size.width
        : (mediaQuery.size.width - 40).clamp(0.0, 720.0);
    final isProfile = cameraType == "profile";
    void handleBack() {
      AlertService().showAppAlert(
        title: "Are you sure?",
        content: "You're about to leave this page",
        hideCancel: false,
        confirmText: "Leave",
        confirmColor: Colors.red,
        confirmAction: () {
          Get.back(result: true);
          Get.back(result: true);
          if (!replacedCaptureRoute) {
            Get.back(result: true);
          }
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CameraShellLayout(
          title: cameraTitleForType(cameraType),
          isMobile: isMobile,
          onBack: handleBack,
          stage: CameraStageLayout(
            maxWidth: previewWidth,
            aspectRatio: 1 / 1.7777777777777777,
            isProfile: isProfile,
            cameraType: cameraType,
            isCapturedPreview: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: MemoryImage(imageBytes),
                ),
              ),
            ),
          ),
          bottomChild: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: WidgetButton(
                  borderRadius: 16,
                  mainColor: Colors.transparent,
                  isTransparentColor: true,
                  useDefaultHoverColor: false,
                  interactionColor: const Color(0x14030744),
                  onTap: () {
                    Get.back();
                    onRetake?.call();
                  },
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFF030744),
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            blurRadius: 2,
                            spreadRadius: 2,
                            offset: Offset(0, 2),
                            color: Colors.white,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.replay,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                height: 80,
                child: WidgetButton(
                  borderRadius: 16,
                  mainColor: Colors.transparent,
                  isTransparentColor: true,
                  useDefaultHoverColor: false,
                  interactionColor: const Color(0xFF007BFF).withValues(
                    alpha: 0.16,
                  ),
                  onTap: _onConfirm,
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFF007BFF),
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            blurRadius: 2,
                            spreadRadius: 2,
                            offset: Offset(0, 2),
                            color: Colors.white,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onConfirm() {
    if (cameraType == "chat") {
      setChatFile(imageBytes);
      Get.back();
      Get.back();
    } else {
      selfieFile = imageBytes;
      selfieFileNeedsHorizontalFlip = false;
      selfieFileFromMobileCamera = isEdit && cameraType == "profile";
      Get.forceAppUpdate();
      Get.back(result: true);
      Get.back(result: true);
    }
  }
}
