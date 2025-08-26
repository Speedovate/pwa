// ignore_for_file: undefined_prefixed_name, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'package:flutter/material.dart';

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
  @override
  void initState() {
    super.initState();
    // Open URL in a new tab as soon as this screen is loaded
    html.window.open(widget.selectedUrl.toString(), "_blank");

    // Close this screen after opening the new tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
