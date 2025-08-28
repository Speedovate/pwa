// ignore_for_file: undefined_prefixed_name, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/button.widget.dart';

class WebViewWidget extends StatefulWidget {
  const WebViewWidget({
    required this.title,
    required this.selectedUrl,
    super.key,
  });

  final String title;
  final Uri selectedUrl;

  @override
  WebViewWidgetState createState() => WebViewWidgetState();
}

class WebViewWidgetState extends State<WebViewWidget> {
  bool showError = false;
  bool isLoading = true;
  late String viewType;

  @override
  void initState() {
    super.initState();
    _registerIframe();
  }

  void _registerIframe() {
    viewType = "iframe-${DateTime.now().microsecondsSinceEpoch}";
    ui.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.selectedUrl.toString()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'auto'
          ..style.userSelect = 'auto'
          ..style.pointerEvents = 'auto';
        iframe.setAttribute('frameborder', '0');
        iframe.setAttribute('allowfullscreen', 'true');
        iframe.setAttribute('title', widget.title);
        iframe.onLoad.listen((event) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                isLoading = false;
                showError = false;
              });
            }
          });
        });

        iframe.onError.listen((event) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                showError = true;
                isLoading = false;
              });
            }
          });
        });
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = const Color(0xFF030744).withOpacity(0.1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 74,
        centerTitle: false,
        backgroundColor: Colors.white,
        leading: Center(
          child: WidgetButton(
            onTap: () {
              Get.back();
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
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            height: 1,
            fontSize: 25,
            fontWeight: FontWeight.w500,
            color: Color(0xFF030744),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (!showError)
            HtmlElementView(viewType: viewType, key: ValueKey(viewType)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Divider(height: 1, thickness: 1, color: dividerColor),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 24,
                    ),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 16,
                                left: 16,
                                right: 16,
                                bottom: 18,
                              ),
                              child: Image.asset(
                                AppImages.logo,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Center(
                            child: SizedBox(
                              width: 150,
                              height: 150,
                              child: CircularProgressIndicator(
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                                color: const Color(
                                  0xFF007BFF,
                                ),
                                backgroundColor: const Color(
                                  0xFF007BFF,
                                ).withOpacity(0.25),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (showError)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.web_asset_off,
                        size: 75, color: Color(0xFF007BFF)),
                    SizedBox(height: 20),
                    Text(
                      "An error occurred. Try again later",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0x80030744),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
