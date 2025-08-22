// ignore_for_file: must_be_immutable, undefined_prefixed_name

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/views/register.view.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

Uint8List? webProfileBytes;
Uint8List? webChatBytes;
Uint8List? pickedImageBytes;

class CameraWidget extends StatefulWidget {
  final bool isEdit;
  String cameraType;

  CameraWidget({this.isEdit = false, this.cameraType = "profile", super.key});

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
      if (_mediaStream == null) throw Exception('Media stream unavailable');

      _videoElement!.srcObject = _mediaStream;
      unawaited(
        _videoElement!.play(),
      );

      _videoElement!.onLoadedMetadata.listen((_) {
        if (mounted && !_isReady) setState(() => _isReady = true);
      });

      ui.platformViewRegistry
          .registerViewFactory(_viewType, (int viewId) => _videoElement!);
      setState(() {});
    } catch (e) {
      _showError(
        e.toString(),
      );
    }
  }

  Future<void> _captureImage() async {
    if (_videoElement == null || !_isReady) return;
    setState(() => _isCapturing = true);

    try {
      final vw = _videoElement!.videoWidth;
      final vh = _videoElement!.videoHeight;
      if (vw <= 0 || vh <= 0) throw Exception('Camera not ready');

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
      Get.to(
        () => CameraImageWidget(
            imageBytes: pickedImageBytes!,
            isEdit: widget.isEdit,
            cameraType: widget.cameraType),
      );
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
      _showError(
        e.toString(),
      );
    }
  }

  void _showError(String msg) {
    final ctx = Get.overlayContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    try {
      _mediaStream?.getTracks().forEach(
            (t) => t.stop(),
          );
    } catch (_) {}
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const themeBlue = Color(0xFF007BFF);
    const themeText = Color(0xFF030744);
    final isProfile = widget.cameraType == "profile";

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 85, left: 35, right: 35),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isProfile ? 1000 : 10),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 70,
                  height: MediaQuery.of(context).size.width - 75,
                  child: _videoElement == null
                      ? const Center(child: CircularProgressIndicator())
                      : HtmlElementView(viewType: _viewType),
                ),
              ),
            ),
          ),
          _buildTopBar(themeText),
          _buildBottomBar(themeBlue, themeText),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color themeText) => Positioned(
        top: 20,
        left: 10,
        child: Row(children: [
          IconButton(
              icon:
                  Icon(MingCuteIcons.mgc_left_line, color: themeText, size: 38),
              onPressed: () => Get.back())
        ]),
      );

  Widget _buildBottomBar(Color themeBlue, Color themeText) => Positioned(
        bottom: 40,
        left: 0,
        right: 0,
        child: Center(
          child: InkWell(
            onTap: _isReady && !_isCapturing ? _captureImage : null,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: themeBlue,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: themeText.withOpacity(0.1), blurRadius: 4)
                  ]),
              child: _isCapturing
                  ? const Center(child: CircularProgressIndicator())
                  : const Icon(MingCuteIcons.mgc_camera_2_fill,
                      color: Colors.white, size: 35),
            ),
          ),
        ),
      );
}

class CameraImageWidget extends StatelessWidget {
  final Uint8List imageBytes;
  final bool isEdit;
  final String cameraType;

  const CameraImageWidget({
    required this.imageBytes,
    this.isEdit = false,
    this.cameraType = "profile",
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isProfile = cameraType == "profile";
    const themeBlue = Color(0xFF007BFF);
    const themeText = Color(0xFF030744);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            cameraType == "chat" ? "Chat Photo" : "Profile Photo",
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
          ),
          const Expanded(
            child: SizedBox(),
          ),
          Container(
            width: MediaQuery.of(context).size.width - 70,
            height: MediaQuery.of(context).size.width - 75,
            decoration: BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.cover,
                image: MemoryImage(imageBytes),
              ),
              borderRadius: BorderRadius.circular(isProfile ? 1000 : 10),
            ),
          ),
          const Expanded(
            child: SizedBox(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundedIconButton(
                MingCuteIcons.mgc_back_2_fill,
                themeText,
                () {
                  Get.back();
                  Get.to(
                    () => CameraWidget(cameraType: cameraType, isEdit: isEdit),
                  );
                },
              ),
              const SizedBox(width: 8),
              _roundedIconButton(
                  MingCuteIcons.mgc_check_fill, themeBlue, _onConfirm),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _roundedIconButton(IconData icon, Color bg, VoidCallback onTap) {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 35),
            ),
          ),
        ),
      ),
    );
  }

  void _onConfirm() {
    if (cameraType == "chat") {
      chatFile = imageBytes;
      Get.back();
    } else {
      selfieFile = imageBytes;
      Get.until((route) => route.isFirst);
      if (!isEdit) {
        Get.to(
          () => const LoginView(),
        );
        Get.to(
          () => const RegisterView(),
        );
      }
    }
  }
}
