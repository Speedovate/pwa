// ignore_for_file: must_be_immutable, undefined_prefixed_name, avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/camera_widget_shared.dart';

export 'camera_widget_shared.dart';

Future<Uint8List> normalizeImageToJpegWeb(
  Uint8List imageBytes, {
  bool mirror = false,
}) async {
  final img = html.ImageElement();
  final completer = Completer<Uint8List>();
  final imageUrl = html.Url.createObjectUrlFromBlob(html.Blob([imageBytes]));

  img.onLoad.listen((_) async {
    try {
      final canvas = html.CanvasElement(width: img.width!, height: img.height!);
      final ctx = canvas.context2D;
      if (mirror) {
        ctx.translate(img.width!.toDouble(), 0);
        ctx.scale(-1, 1);
      }
      ctx.drawImage(img, 0, 0);
      final blob = await canvas.toBlob('image/jpeg', 0.92);
      final reader = html.FileReader();
      reader.onLoad.listen((_) {
        completer.complete(reader.result as Uint8List);
      });
      reader.onError.listen((_) {
        completer.completeError('Unable to read processed image.');
      });
      reader.readAsArrayBuffer(blob);
    } catch (e) {
      completer.completeError(e);
    } finally {
      html.Url.revokeObjectUrl(imageUrl);
    }
  });

  img.onError.listen((_) {
    html.Url.revokeObjectUrl(imageUrl);
    completer.completeError('Unsupported image format.');
  });

  img.src = imageUrl;
  return completer.future;
}

class CameraWidget extends StatefulWidget {
  final bool isEdit;
  String cameraType;

  CameraWidget({
    required this.isEdit,
    required this.cameraType,
    super.key,
  });

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  late final String _viewType;
  bool _isReady = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewType =
        'web-camera-${widget.cameraType}-${DateTime.now().microsecondsSinceEpoch}';
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';
      _videoElement!.setAttribute('playsinline', 'true');

      ui.platformViewRegistry
          .registerViewFactory(_viewType, (int viewId) => _videoElement!);

      final constraints = {
        'video': {
          'facingMode': widget.cameraType == 'profile' ? 'user' : 'environment'
        },
        'audio': false,
      };

      _mediaStream =
          await html.window.navigator.mediaDevices?.getUserMedia(constraints);
      if (_mediaStream == null) throw 'Media stream unavailable';

      _videoElement!.srcObject = _mediaStream;
      unawaited(_videoElement!.play());

      _videoElement!.onLoadedMetadata.listen((_) {
        if (mounted && !_isReady) {
          setState(() {
            _isReady = true;
            _errorMessage = null;
          });
        }
      });

      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
      _showError(e.toString());
    }
  }

  Future<void> _captureImage() async {
    if (_videoElement == null || !_isReady) return;
    setState(() => _isCapturing = true);
    try {
      final vw = _videoElement!.videoWidth;
      final vh = _videoElement!.videoHeight;
      if (vw <= 0 || vh <= 0) throw 'Camera not ready';
      final canvas = html.CanvasElement(width: vw, height: vh);
      final ctx = canvas.context2D;
      if (widget.cameraType == 'profile') {
        ctx.translate(vw.toDouble(), 0);
        ctx.scale(-1, 1);
      }
      ctx.drawImage(_videoElement!, 0, 0);
      final blob = await canvas.toBlob('image/jpeg', 0.92);
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      reader.onLoad
          .listen((_) => completer.complete(reader.result as Uint8List));
      reader.readAsArrayBuffer(blob);
      pickedImageBytes = await completer.future;
      if (!mounted) return;
      _stopMediaStream();
      setState(() => _isCapturing = false);
      Navigator.push(
        context,
        PageRouteBuilder(
          reverseTransitionDuration: Duration.zero,
          transitionDuration: Duration.zero,
          pageBuilder: (context, a, b) => CameraImageWidget(
            imageBytes: pickedImageBytes!,
            isEdit: widget.isEdit,
            cameraType: widget.cameraType,
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
      if (mounted) setState(() => _isCapturing = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    final ctx = Get.context;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _popCameraRoute() {
    if (widget.cameraType == "chat") {
      Get.back();
      return;
    }
    Get.back(result: true);
  }

  void _handleBack() {
    _popCameraRoute();
  }

  void _stopMediaStream() {
    try {
      _mediaStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    _mediaStream = null;
    _isReady = false;
  }

  @override
  void dispose() {
    _stopMediaStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
    final isProfile = widget.cameraType == "profile";
    final previewWidth = (mediaQuery.size.width - 40).clamp(0.0, 720.0);
    final hasCameraError = _errorMessage != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CameraShellLayout(
        title: cameraTitleForType(widget.cameraType),
        isMobile: isMobile,
        onBack: _handleBack,
        hideBottomArea: hasCameraError,
        stage: hasCameraError
            ? const CameraUnavailableState()
            : CameraStageLayout(
                maxWidth: previewWidth,
                aspectRatio: 1 / 1.7777777777777777,
                isProfile: isProfile,
                cameraType: widget.cameraType,
                isCapturedPreview: false,
                child: _videoElement == null
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeCap: StrokeCap.round,
                          color: const Color(0xFF007BFF),
                          backgroundColor:
                              const Color(0xFF007BFF).withValues(alpha: 0.25),
                        ),
                      )
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scaleByDouble(
                            isProfile ? -1.0 : 1.0,
                            1.0,
                            1.0,
                            1.0,
                          ),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: HtmlElementView(
                            viewType: _viewType,
                            key: ValueKey(_viewType),
                          ),
                        ),
                      ),
              ),
        bottomChild: hasCameraError
            ? const SizedBox.shrink()
            : SizedBox(
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
                  onTap: _isReady && !_isCapturing ? _captureImage : () {},
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
  }
}
