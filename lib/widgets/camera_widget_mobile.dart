import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/camera_widget_shared.dart';

class CameraWidget extends StatefulWidget {
  final bool isEdit;
  final String cameraType;

  const CameraWidget({
    required this.isEdit,
    required this.cameraType,
    super.key,
  });

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCapturing = false;
  String? _errorMessage;

  bool get _useFrontCamera => widget.cameraType == 'profile';
  bool get _isProfile => widget.cameraType == 'profile';

  String get _title {
    if (widget.cameraType == "chat") {
      return "Capture Photo";
    } else if (widget.cameraType == "vehicle") {
      return "Vehicle Photo";
    } else if (widget.cameraType == "vPapers") {
      return "Vehicle Papers";
    } else if (widget.cameraType == "license") {
      return "driver's License";
    } else {
      return "Profile Photo";
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_disposeController());
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    _initializeControllerFuture = null;
    if (controller == null) {
      return;
    }
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _setupCamera() async {
    CameraController? controller;
    try {
      final cachedCameras = cameras is List<CameraDescription>
          ? cameras as List<CameraDescription>
          : null;
      final cameraList = cachedCameras ??
          await availableCameras().timeout(
            const Duration(seconds: 10),
          );
      cameras = cameraList;
      if (cameraList.isEmpty) {
        throw 'No camera available';
      }

      CameraDescription selectedCamera = cameraList.first;
      for (final camera in cameraList) {
        if (_useFrontCamera &&
            camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
        if (!_useFrontCamera &&
            camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      controller = CameraController(
        selectedCamera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      final initializeFuture = controller.initialize().timeout(
            const Duration(seconds: 15),
          );
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializeControllerFuture = initializeFuture;
        _errorMessage = null;
      });
      await initializeFuture;
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Some iOS devices do not support flash on the selected camera.
      }
    } catch (e) {
      await controller?.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = cleanErrorMessage(e);
      });
    }
  }

  Future<void> _capture() async {
    if (_isCapturing ||
        _controller == null ||
        _initializeControllerFuture == null) {
      return;
    }

    try {
      setState(() {
        _isCapturing = true;
      });
      await _initializeControllerFuture;
      final previewAspectRatio = _portraitAspectRatio();
      final image = await _controller!.takePicture();
      if (!mounted) {
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          reverseTransitionDuration: Duration.zero,
          transitionDuration: Duration.zero,
          pageBuilder: (context, a, b) => _MobileCameraImageWidget(
            imageBytes: bytes,
            imagePath: image.path,
            isEdit: widget.isEdit,
            cameraType: widget.cameraType,
            previewAspectRatio: previewAspectRatio,
            replacedCaptureRoute: true,
            onRetake: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  reverseTransitionDuration: Duration.zero,
                  transitionDuration: Duration.zero,
                  pageBuilder: (context, a, b) => CameraWidget(
                    isEdit: widget.isEdit,
                    cameraType: widget.cameraType,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      AlertService().showAppAlert(
        title: 'Error',
        content: cleanErrorMessage(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _handleBack() {
    _popCameraRoute();
  }

  void _popCameraRoute() {
    if (widget.cameraType == "chat") {
      Get.back();
      return;
    }
    Get.back(result: true);
  }

  double _portraitAspectRatio() {
    final controller = _controller;
    final aspectRatio = controller?.value.aspectRatio ?? 1.0;
    if (aspectRatio <= 0) {
      return 1.0;
    }
    final invertedAspectRatio = 1 / aspectRatio;
    return aspectRatio < invertedAspectRatio
        ? aspectRatio
        : invertedAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
    final previewWidth = mediaQuery.size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (_errorMessage != null) {
              return _MobileCameraShell(
                title: _title,
                isMobile: isMobile,
                onBack: _handleBack,
                stage: const Expanded(
                  child: CameraUnavailableState(),
                ),
                bottomChild: const SizedBox.shrink(),
                hideBottomArea: true,
              );
            }

            if (snapshot.connectionState != ConnectionState.done ||
                _controller == null) {
              return _MobileCameraShell(
                title: _title,
                isMobile: isMobile,
                onBack: _handleBack,
                stage: const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Color(0xFF007BFF),
                    ),
                  ),
                ),
                bottomChild: const SizedBox.shrink(),
                hideBottomArea: true,
              );
            }

            return _MobileCameraShell(
              title: _title,
              isMobile: isMobile,
              onBack: _handleBack,
              stage: _MobileCameraStage(
                width: previewWidth,
                aspectRatio: _portraitAspectRatio(),
                isProfile: _isProfile,
                cameraType: widget.cameraType,
                isCapturedPreview: false,
                child: CameraPreview(_controller!),
              ),
              bottomChild: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SizedBox(
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
                    onTap: _isCapturing ? () {} : _capture,
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
                        child: _isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 4,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.photo_camera,
                                color: Colors.white,
                                size: 35,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MobileCameraImageWidget extends StatelessWidget {
  final Uint8List imageBytes;
  final String imagePath;
  final bool isEdit;
  final String cameraType;
  final double previewAspectRatio;
  final bool replacedCaptureRoute;
  final VoidCallback? onRetake;

  const _MobileCameraImageWidget({
    required this.imageBytes,
    required this.imagePath,
    required this.isEdit,
    required this.cameraType,
    required this.previewAspectRatio,
    required this.replacedCaptureRoute,
    this.onRetake,
  });

  bool get _isProfile => cameraType == 'profile';

  String get _title {
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

  Future<Uint8List> _prepareChatImageBytes() async {
    if (cameraType != "chat") {
      return imageBytes;
    }
    return _resizeImageBytesForChat(
      imageBytes,
      maxLongSide: 1080,
    );
  }

  void _handleBack() {
    if (cameraType == "chat") {
      Get.back(result: true);
      return;
    }
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

  Future<void> _confirm() async {
    if (cameraType == "chat") {
      final preparedBytes = await _prepareChatImageBytes();
      setChatFile(preparedBytes);
      Get.back(result: true);
      return;
    }

    selfieFile = imageBytes;
    selfieFileNeedsHorizontalFlip = _isProfile;
    selfieFileFromMobileCamera = true;
    Get.forceAppUpdate();
    Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
    final previewWidth = mediaQuery.size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _MobileCameraShell(
          title: _title,
          isMobile: isMobile,
          onBack: _handleBack,
          stage: _MobileCameraStage(
            width: previewWidth,
            aspectRatio: previewAspectRatio,
            isProfile: _isProfile,
            cameraType: cameraType,
            isCapturedPreview: true,
            child: Transform(
              alignment: Alignment.center,
              filterQuality: FilterQuality.none,
              transform: Matrix4.identity()
                ..scaleByDouble(
                  _isProfile ? -1.0 : 1.0,
                  1.0,
                  1.0,
                  1.0,
                ),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
                gaplessPlayback: true,
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
                  onTap: _confirm,
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
}

Future<Uint8List> _resizeImageBytesForChat(
  Uint8List bytes, {
  int maxLongSide = 1080,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final width = image.width;
  final height = image.height;
  final longSide = width > height ? width : height;

  if (longSide <= maxLongSide) {
    return bytes;
  }

  final scale = maxLongSide / longSide;
  final targetWidth = (width * scale).round();
  final targetHeight = (height * scale).round();

  final resizedCodec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
  final resizedFrame = await resizedCodec.getNextFrame();
  final resizedImage = resizedFrame.image;
  final byteData = await resizedImage.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return byteData!.buffer.asUint8List();
}

class _MobileCameraShell extends StatelessWidget {
  final String title;
  final bool isMobile;
  final VoidCallback onBack;
  final Widget stage;
  final Widget bottomChild;
  final bool hideBottomArea;

  const _MobileCameraShell({
    required this.title,
    required this.isMobile,
    required this.onBack,
    required this.stage,
    required this.bottomChild,
    this.hideBottomArea = false,
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
            stage,
            if (!hideBottomArea)
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
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
                  child: Center(
                    child: bottomChild,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileCameraStage extends StatelessWidget {
  final Widget child;
  final bool isProfile;
  final String cameraType;
  final bool isCapturedPreview;
  final double width;
  final double aspectRatio;

  const _MobileCameraStage({
    required this.child,
    required this.isProfile,
    required this.cameraType,
    required this.isCapturedPreview,
    required this.width,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isProfile ? 0 : 10),
                child: child,
              ),
            ),
            Positioned.fill(
              child: _MobileCameraGuideOverlay(
                cameraType: cameraType,
                isCapturedPreview: isCapturedPreview,
                isProfile: isProfile,
                width: width,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCameraGuideOverlay extends StatelessWidget {
  final String cameraType;
  final bool isCapturedPreview;
  final bool isProfile;
  final double width;

  const _MobileCameraGuideOverlay({
    required this.cameraType,
    required this.isCapturedPreview,
    required this.isProfile,
    required this.width,
  });

  String get _instructionText {
    if (isCapturedPreview) {
      {
        return "Please review your captured photo.";
      }
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
                    width: 40,
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
                                  _instructionText,
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
                    width: 40,
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
            if (isProfile)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
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
                  width: 2,
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
                  height: 2,
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
                  height: 2,
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
