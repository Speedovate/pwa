import 'package:flutter/material.dart';
import 'package:pwa/widgets/button.widget.dart';

enum ConnectionBannerType {
  connection,
  weakConnection,
  server,
  restored,
}

class _ConnectionBannerState {
  final String message;
  final ConnectionBannerType type;

  const _ConnectionBannerState({
    required this.message,
    required this.type,
  });
}

class ConnectionBannerService {
  static DateTime? _lastShownAt;
  static DateTime? _lastRestoredAt;
  static String? _currentMessage;
  static bool _supportDialogOpen = false;
  static Future<void> Function(BuildContext context)? _showSupportDialog;
  static final ValueNotifier<_ConnectionBannerState?> _banner =
      ValueNotifier(null);
  static const _cooldown = Duration(seconds: 8);

  static bool get isServerBannerVisible =>
      _banner.value?.type == ConnectionBannerType.server;

  static void setSupportDialogHandler(
    Future<void> Function(BuildContext context) handler,
  ) {
    _showSupportDialog = handler;
  }

  static void show(
    ConnectionBannerType type, {
    DateTime? requestStartedAt,
  }) {
    final message = switch (type) {
      ConnectionBannerType.connection => "No connection.",
      ConnectionBannerType.weakConnection => "Weak connection.",
      ConnectionBannerType.server => "Fix in progress.",
      ConnectionBannerType.restored => "Back Online",
    };
    final now = DateTime.now();
    if (type != ConnectionBannerType.restored &&
        requestStartedAt != null &&
        _lastRestoredAt != null &&
        !requestStartedAt.isAfter(_lastRestoredAt!)) {
      return;
    }
    if (_currentMessage == message &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < _cooldown) {
      return;
    }

    _lastShownAt = now;
    if (type == ConnectionBannerType.restored) {
      _lastRestoredAt = now;
    }
    _currentMessage = message;
    _banner.value = _ConnectionBannerState(
      message: message,
      type: type,
    );
  }

  static void dismiss() {
    if (_banner.value?.type == ConnectionBannerType.server) {
      return;
    }
    _currentMessage = null;
    _banner.value = null;
  }

  static void dismissAfterSuccessfulResponse({
    required bool appServerResponse,
  }) {
    final currentType = _banner.value?.type;
    if (currentType == null || currentType == ConnectionBannerType.restored) {
      return;
    }
    if (currentType == ConnectionBannerType.server && !appServerResponse) {
      return;
    }
    show(ConnectionBannerType.restored);
  }

  static Future<void> _handleAction(
    BuildContext context,
    ConnectionBannerType type,
  ) async {
    if (type == ConnectionBannerType.server) {
      if (_supportDialogOpen) {
        return;
      }
      _supportDialogOpen = true;
      try {
        await _showSupportDialog?.call(context);
      } finally {
        _supportDialogOpen = false;
      }
      return;
    }
    dismiss();
  }

  static Widget buildOverlay() {
    return ValueListenableBuilder<_ConnectionBannerState?>(
      valueListenable: _banner,
      builder: (context, state, _) {
        if (state == null) {
          return const SizedBox.shrink();
        }
        final mediaQuery = MediaQuery.of(context);
        final color = switch (state.type) {
          ConnectionBannerType.weakConnection => Colors.orange,
          ConnectionBannerType.connection => Colors.red,
          ConnectionBannerType.server => const Color(0xFF007BFF),
          ConnectionBannerType.restored => Colors.green,
        };
        return Positioned(
          top: mediaQuery.padding.top + 24,
          left: 24,
          right: 24,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(
                      switch (state.type) {
                        ConnectionBannerType.server => Icons.build_outlined,
                        ConnectionBannerType.restored =>
                          Icons.check_circle_outline,
                        _ => Icons.wifi_off_outlined,
                      },
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    WidgetButton(
                      onTap: () => _handleAction(context, state.type),
                      mainColor: Colors.transparent,
                      isTransparentColor: true,
                      useDefaultHoverColor: false,
                      suppressInteraction: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          state.type == ConnectionBannerType.server
                              ? "Get help"
                              : "Dismiss",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
