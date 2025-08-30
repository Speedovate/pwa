// ignore_for_file: must_be_immutable, undefined_prefixed_name, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/views/profile.view.dart';
import 'package:pwa/views/register.view.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/button.widget.dart';

Uint8List? webChatBytes;
Uint8List? webProfileBytes;
Uint8List? pickedImageBytes;

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
          'facingMode':
              widget.cameraType == 'profile' || widget.cameraType == 'chat'
                  ? 'user'
                  : 'environment'
        },
        'audio': false,
      };

      _mediaStream =
          await html.window.navigator.mediaDevices?.getUserMedia(constraints);
      if (_mediaStream == null) throw 'Media stream unavailable';

      _videoElement!.srcObject = _mediaStream;
      unawaited(_videoElement!.play());

      _videoElement!.onLoadedMetadata.listen((_) {
        if (mounted && !_isReady) setState(() => _isReady = true);
      });

      setState(() {});
    } catch (e) {
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
      if (widget.cameraType == 'profile' || widget.cameraType == 'chat') {
        ctx.translate(vw.toDouble(), 0);
        ctx.scale(-1, 1);
      }
      ctx.drawImage(_videoElement!, 0, 0);
      final blob = await canvas.toBlob('image/jpeg', 0.92);
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      reader.onLoad.listen(
        (_) => completer.complete(reader.result as Uint8List),
      );
      reader.readAsArrayBuffer(blob);
      pickedImageBytes = await completer.future;
      if (!mounted) return;
      setState(() => _isCapturing = false);
      Navigator.push(
        context,
        PageRouteBuilder(
          reverseTransitionDuration: Duration.zero,
          transitionDuration: Duration.zero,
          pageBuilder: (
            context,
            a,
            b,
          ) =>
              CameraImageWidget(
            imageBytes: pickedImageBytes!,
            isEdit: widget.isEdit,
            cameraType: widget.cameraType,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    final ctx = Get.overlayContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    try {
      _mediaStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProfile = widget.cameraType == "profile";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white,
                            spreadRadius: 0.5,
                            blurRadius: 5,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              WidgetButton(
                                onTap: () {
                                  if (widget.cameraType == "chat") {
                                    Get.back();
                                  } else {
                                    AlertService().showAppAlert(
                                      title: "Are you sure?",
                                      content:
                                          "You're about to leave this page",
                                      hideCancel: false,
                                      confirmText: "Go back",
                                      confirmAction: () {
                                        Get.back(result: true);
                                        Get.back(result: true);
                                      },
                                    );
                                  }
                                },
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
                                () {
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
                                }(),
                                style: const TextStyle(
                                  height: 1,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 32,
                    ),
                    child: Center(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(isProfile ? 1000 : 10),
                        child: SizedBox(
                          width: (MediaQuery.of(context).size.width - 70).clamp(
                            0,
                            450,
                          ),
                          height:
                              (MediaQuery.of(context).size.width - 75).clamp(
                            0,
                            450,
                          ),
                          child: _videoElement == null
                              ? Center(
                                  child: CircularProgressIndicator(
                                    strokeCap: StrokeCap.round,
                                    color: const Color(
                                      0xFF007BFF,
                                    ),
                                    backgroundColor: const Color(
                                      0xFF007BFF,
                                    ).withOpacity(0.25),
                                  ),
                                )
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..scale(
                                      -1.0,
                                      1.0,
                                      1.0,
                                    ),
                                  child: SizedBox(
                                    width: double.infinity.clamp(
                                      0,
                                      450,
                                    ),
                                    height: double.infinity.clamp(
                                      0,
                                      450,
                                    ),
                                    child: HtmlElementView(
                                      viewType: _viewType,
                                      key: ValueKey(
                                        _viewType,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      width: MediaQuery.of(context).size.width,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: 40,
                          ),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: WidgetButton(
                              borderRadius: 16,
                              onTap: _isReady && !_isCapturing
                                  ? _captureImage
                                  : () {},
                              child: Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007BFF),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            const Color(0xFF030744).withOpacity(
                                          0.1,
                                        ),
                                        spreadRadius: 0,
                                        blurRadius: 4,
                                        offset: const Offset(
                                          0,
                                          2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera,
                                    color: Colors.white,
                                    size: 35,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraImageWidget extends StatelessWidget {
  final Uint8List imageBytes;
  final bool isEdit;
  final String cameraType;

  const CameraImageWidget({
    required this.imageBytes,
    required this.isEdit,
    required this.cameraType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 4),
                  WidgetButton(
                    onTap: () {
                      AlertService().showAppAlert(
                        title: "Are you sure?",
                        content: "You're about to leave this page",
                        hideCancel: false,
                        confirmText: "Go back",
                        confirmAction: () {
                          Get.back(result: true);
                          Get.back(result: true);
                          Get.back(result: true);
                        },
                      );
                    },
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
                    () {
                      if (cameraType == "vehicle") {
                        return "Vehicle Photo";
                      } else if (cameraType == "vPapers") {
                        return "Vehicle Papers";
                      } else if (cameraType == "license") {
                        return "driver's License";
                      } else {
                        return "Profile Photo";
                      }
                    }(),
                    style: const TextStyle(
                      height: 1,
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF030744),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Expanded(
                child: SizedBox.shrink(),
              ),
              Container(
                width: (MediaQuery.of(context).size.width - 70).clamp(
                  0,
                  450,
                ),
                height: (MediaQuery.of(context).size.width - 75).clamp(
                  0,
                  450,
                ),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: MemoryImage(imageBytes),
                  ),
                  borderRadius: BorderRadius.all(
                    Radius.circular(
                      cameraType != "profile" ? 10 : 1000,
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      child: WidgetButton(
                        borderRadius: 16,
                        onTap: () {
                          Get.back();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              reverseTransitionDuration: Duration.zero,
                              transitionDuration: Duration.zero,
                              pageBuilder: (
                                context,
                                a,
                                b,
                              ) =>
                                  CameraWidget(
                                isEdit: isEdit,
                                cameraType: cameraType,
                              ),
                            ),
                          );
                        },
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF030744),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF030744).withOpacity(
                                    0.1,
                                  ),
                                  spreadRadius: 0,
                                  blurRadius: 4,
                                  offset: const Offset(
                                    0,
                                    2,
                                  ),
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
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      child: WidgetButton(
                        borderRadius: 16,
                        onTap: () {
                          _onConfirm();
                        },
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007BFF),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF030744).withOpacity(
                                    0.1,
                                  ),
                                  spreadRadius: 0,
                                  blurRadius: 4,
                                  offset: const Offset(
                                    0,
                                    2,
                                  ),
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
              const Expanded(
                child: SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onConfirm() {
    if (cameraType == "chat") {
      chatFile = imageBytes;
      Get.back();
      Get.back();
    } else {
      selfieFile = imageBytes;
      Get.until((route) => route.isFirst);
      if (!isEdit) {
        Navigator.push(
          Get.overlayContext!,
          PageRouteBuilder(
            reverseTransitionDuration: Duration.zero,
            transitionDuration: Duration.zero,
            pageBuilder: (
              context,
              a,
              b,
            ) =>
                const LoginView(),
          ),
        );
        Navigator.push(
          Get.overlayContext!,
          PageRouteBuilder(
            reverseTransitionDuration: Duration.zero,
            transitionDuration: Duration.zero,
            pageBuilder: (
              context,
              a,
              b,
            ) =>
                const RegisterView(),
          ),
        );
      } else {
        Navigator.push(
          Get.overlayContext!,
          PageRouteBuilder(
            reverseTransitionDuration: Duration.zero,
            transitionDuration: Duration.zero,
            pageBuilder: (
              context,
              a,
              b,
            ) =>
                const ProfileView(),
          ),
        );
      }
    }
  }
}
