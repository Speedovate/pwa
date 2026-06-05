import 'dart:js_interop';
import 'package:web/web.dart' as web;

class WebViewportObserver {
  JSFunction? _resizeListener;
  JSFunction? _scrollListener;

  void start(void Function(double inset) onInsetChanged) {
    final viewport = web.window.visualViewport;
    if (viewport == null) {
      return;
    }
    stop();

    void syncInset() {
      final innerHeight = web.window.innerHeight.toDouble();
      final viewportHeight = viewport.height;
      final viewportOffsetTop = viewport.offsetTop;
      final overlap = innerHeight - viewportHeight - viewportOffsetTop;
      onInsetChanged(overlap > 0 ? overlap : 0);
    }

    syncInset();
    _resizeListener = ((web.Event _) => syncInset()).toJS;
    _scrollListener = ((web.Event _) => syncInset()).toJS;
    viewport.addEventListener('resize', _resizeListener);
    viewport.addEventListener('scroll', _scrollListener);
  }

  void stop() {
    final viewport = web.window.visualViewport;
    if (viewport == null) {
      return;
    }
    if (_resizeListener != null) {
      viewport.removeEventListener('resize', _resizeListener);
    }
    if (_scrollListener != null) {
      viewport.removeEventListener('scroll', _scrollListener);
    }
    _resizeListener = null;
    _scrollListener = null;
  }
}
