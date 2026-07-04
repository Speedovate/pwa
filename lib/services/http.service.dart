import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/utils/browser_utils.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/services/connection_banner.service.dart';
import 'package:dio_http_cache_lts/dio_http_cache_lts.dart';
import 'package:rx_shared_preferences/rx_shared_preferences.dart';

class HttpService {
  String host = Api.baseUrl;

  late Dio dio;
  late BaseOptions baseOptions;
  late SharedPreferences prefs;

  Future<Map<String, String>> getHeaders() async {
    return {
      HttpHeaders.authorizationHeader: "Bearer ${AuthService.bearerToken}",
      HttpHeaders.acceptHeader: "application/json",
      "platform": AuthService.device(),
      "build_number": version ?? "",
      "code": versionCode ?? "",
      "role": "client",
      "lang": "en",
    };
  }

  HttpService() {
    StorageService.getPrefs();
    baseOptions = BaseOptions(
      baseUrl: host,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 90),
      validateStatus: (status) => status! <= 500,
    );
    dio = Dio(
      baseOptions,
    );
    dio.interceptors.add(getCacheManager().interceptor);
  }

  DioCacheManager getCacheManager() {
    return DioCacheManager(
      CacheConfig(
        baseUrl: host,
        defaultMaxAge: const Duration(hours: 1),
      ),
    );
  }

  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool includeHeaders = true,
  }) async {
    final uri = _buildUri(url);
    final options = includeHeaders
        ? Options(
            headers: await getHeaders(),
          )
        : null;
    final requestStartedAt = DateTime.now();
    _logRequestStart("GET", uri, requestStartedAt);
    final slowRequestTimer = _startSlowRequestTimer(
      "GET",
      uri,
      requestStartedAt,
    );

    try {
      return _handleResponse(
        await dio.get(
          uri,
          options: options,
          queryParameters: queryParameters,
        ),
        requestStartedAt: requestStartedAt,
      );
    } on DioException catch (e) {
      return await _formatDioException(
        e,
        requestStartedAt: requestStartedAt,
      );
    } finally {
      slowRequestTimer.cancel();
    }
  }

  Future<Response> post(
    String url,
    dynamic body, {
    bool includeHeaders = true,
  }) async {
    final uri = _buildUri(url);
    final options = includeHeaders
        ? Options(
            headers: await getHeaders(),
          )
        : null;
    final requestStartedAt = DateTime.now();
    _logRequestStart("POST", uri, requestStartedAt);
    final slowRequestTimer = _startSlowRequestTimer(
      "POST",
      uri,
      requestStartedAt,
    );

    try {
      return _handleResponse(
        await dio.post(
          uri,
          data: _convertBool(body),
          options: options,
        ),
        requestStartedAt: requestStartedAt,
      );
    } on DioException catch (e) {
      return await _formatDioException(
        e,
        requestStartedAt: requestStartedAt,
      );
    } finally {
      slowRequestTimer.cancel();
    }
  }

  Future<Response> postWithFiles(
    String url,
    dynamic body, {
    bool includeHeaders = true,
  }) async {
    final uri = _buildUri(url);
    final options = includeHeaders
        ? Options(
            headers: await getHeaders(),
          )
        : null;
    final requestStartedAt = DateTime.now();
    _logRequestStart("POST_FILES", uri, requestStartedAt);
    final slowRequestTimer = _startSlowRequestTimer(
      "POST_FILES",
      uri,
      requestStartedAt,
    );

    try {
      return _handleResponse(
        await dio.post(
          uri,
          data: FormData.fromMap(_convertBool(body)),
          options: options,
        ),
        requestStartedAt: requestStartedAt,
      );
    } on DioException catch (e) {
      return await _formatDioException(
        e,
        requestStartedAt: requestStartedAt,
      );
    } finally {
      slowRequestTimer.cancel();
    }
  }

  Future<Response> postCustomFiles(
    String url,
    dynamic body, {
    FormData? formData,
    bool includeHeaders = true,
  }) async {
    final uri = _buildUri(url);
    final options = includeHeaders
        ? Options(
            headers: await getHeaders(),
          )
        : null;
    final requestStartedAt = DateTime.now();
    _logRequestStart("POST_CUSTOM_FILES", uri, requestStartedAt);
    final slowRequestTimer = _startSlowRequestTimer(
      "POST_CUSTOM_FILES",
      uri,
      requestStartedAt,
    );

    try {
      final effectiveFormData =
          formData ?? FormData.fromMap(_convertBool(body ?? {}));
      return _handleResponse(
        await dio.post(
          uri,
          data: effectiveFormData,
          options: options,
        ),
        requestStartedAt: requestStartedAt,
      );
    } on DioException catch (e) {
      return await _formatDioException(
        e,
        requestStartedAt: requestStartedAt,
      );
    } catch (e) {
      throw "An unexpected error occurred: $e";
    } finally {
      slowRequestTimer.cancel();
    }
  }

  Future<Response> patch(String url, Map<String, dynamic> body) async {
    final uri = _buildUri(url);
    final requestStartedAt = DateTime.now();
    _logRequestStart("PATCH", uri, requestStartedAt);
    final slowRequestTimer = _startSlowRequestTimer(
      "PATCH",
      uri,
      requestStartedAt,
    );

    try {
      return _handleResponse(
        await dio.patch(
          uri,
          data: _convertBool(body),
          options: Options(
            headers: await getHeaders(),
          ),
        ),
        requestStartedAt: requestStartedAt,
      );
    } on DioException catch (e) {
      return await _formatDioException(
        e,
        requestStartedAt: requestStartedAt,
      );
    } finally {
      slowRequestTimer.cancel();
    }
  }

  Future<Response> delete(String url) async {
    final uri = _buildUri(url);
    final requestStartedAt = DateTime.now();
    _logRequestStart("DELETE", uri, requestStartedAt);
    final slowRequestTimer = _startSlowRequestTimer(
      "DELETE",
      uri,
      requestStartedAt,
    );

    try {
      return _handleResponse(
        await dio.delete(
          uri,
          options: Options(
            headers: await getHeaders(),
          ),
        ),
        requestStartedAt: requestStartedAt,
      );
    } on DioException catch (e) {
      return await _formatDioException(
        e,
        requestStartedAt: requestStartedAt,
      );
    } finally {
      slowRequestTimer.cancel();
    }
  }

  Future<Response> getExternal(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final requestStartedAt = DateTime.now();
    _logRequestStart("GET_EXTERNAL", url, requestStartedAt);
    final slowRequestTimer = _startSlowRequestTimer(
      "GET_EXTERNAL",
      url,
      requestStartedAt,
    );
    try {
      return _handleResponse(
        await dio.get(
          url,
          queryParameters: queryParameters,
        ),
        requestStartedAt: requestStartedAt,
      );
    } on DioException catch (e) {
      return await _formatDioException(
        e,
        requestStartedAt: requestStartedAt,
      );
    } finally {
      slowRequestTimer.cancel();
    }
  }

  Map<String, dynamic> _convertBool(dynamic body) {
    if (body is Map<String, dynamic>) {
      body.forEach((key, value) {
        if (value is bool) {
          body[key] = value ? "1" : "0";
        }
      });
    }
    return body;
  }

  String _buildUri(String url) {
    return url.startsWith("https")
        ? url
        : "$host${url.startsWith("/") ? "" : "/"}$url";
  }

  void _logRequestStart(
    String method,
    String url,
    DateTime requestStartedAt,
  ) {}

  Timer _startSlowRequestTimer(
    String method,
    String url,
    DateTime requestStartedAt,
  ) {
    return Timer(
      const Duration(seconds: 30),
      () {
        if (ConnectionBannerService.isServerBannerVisible) {
          return;
        }
        ConnectionBannerService.show(
          ConnectionBannerType.weakConnection,
          requestStartedAt: requestStartedAt,
        );
      },
    );
  }

  Response _handleResponse(
    Response response, {
    required DateTime requestStartedAt,
  }) {
    final statusCode = response.statusCode ?? 0;
    final appServerResponse = _isAppServerUri(response.requestOptions.uri);
    final ignoresServerBanner = _ignoresServerBanner(response);
    if (statusCode >= 500 && !ignoresServerBanner) {
      ConnectionBannerService.show(
        ConnectionBannerType.server,
        requestStartedAt: requestStartedAt,
      );
    } else if (statusCode >= 200 && statusCode < 400 && appServerResponse) {
      ConnectionBannerService.dismissAfterSuccessfulResponse(
        appServerResponse: appServerResponse,
      );
    }
    return response;
  }

  bool _ignoresServerBanner(Response response) {
    if ((response.statusCode ?? 0) < 500) {
      return false;
    }
    return _ignoresServerBannerRequest(
      response.requestOptions.method,
      response.requestOptions.uri,
    );
  }

  bool _ignoresServerBannerRequest(String method, Uri uri) {
    final apiUri = Uri.parse(Api.baseUrl);
    final fcmPath = "${apiUri.path}${Api.fcm}";
    if (_isAppServerUri(uri) && uri.path == fcmPath) {
      return true;
    }
    final currentOrderPath = "${apiUri.path}${Api.bookingCurrent}";
    final currentOrderDriverPath = "${apiUri.path}${Api.bookingDriver}";
    final lastOrderPath = "${apiUri.path}${Api.bookingLast}";
    return method.toUpperCase() == "GET" &&
        _isAppServerUri(uri) &&
        (uri.path == currentOrderPath ||
            uri.path == currentOrderDriverPath ||
            uri.path == lastOrderPath);
  }

  bool _isAppServerRequest(DioException ex) {
    return _isAppServerUri(ex.requestOptions.uri);
  }

  bool _isAppServerUri(Uri requestUri) {
    try {
      final serverUri = Uri.parse(Api.baseUrl);
      return requestUri.host == serverUri.host;
    } catch (_) {
      return false;
    }
  }

  Future<Response> _formatDioException(
    DioException ex, {
    required DateTime requestStartedAt,
  }) async {
    if (ex.response != null) {
      return _handleResponse(
        ex.response!,
        requestStartedAt: requestStartedAt,
      );
    }

    final response = Response(requestOptions: ex.requestOptions)
      ..statusCode = 0;

    if (ex.type == DioExceptionType.connectionTimeout ||
        ex.type == DioExceptionType.sendTimeout ||
        ex.type == DioExceptionType.receiveTimeout) {
      final appServerRequest = _isAppServerRequest(ex);
      final online = isBrowserOnline();
      final ignoresServerBanner = _ignoresServerBannerRequest(
        ex.requestOptions.method,
        ex.requestOptions.uri,
      );
      if (appServerRequest && online && ignoresServerBanner) {
        response.statusCode = 503;
        response.data = {
          "message": "Service temporarily unavailable.",
        };
      } else if (appServerRequest && online) {
        ConnectionBannerService.show(
          ConnectionBannerType.server,
          requestStartedAt: requestStartedAt,
        );
        response.statusCode = 503;
        response.data = {
          "message": "Service temporarily unavailable.",
        };
      } else {
        ConnectionBannerService.show(
          ConnectionBannerType.weakConnection,
          requestStartedAt: requestStartedAt,
        );
        response.statusCode = 408;
        response.data = {
          "message": "Weak connection.",
        };
      }
    } else if (ex.type == DioExceptionType.connectionError ||
        ex.type == DioExceptionType.unknown) {
      ConnectionBannerService.show(
        ConnectionBannerType.connection,
        requestStartedAt: requestStartedAt,
      );
      response.data = {
        "message": "No connection.",
      };
    } else {
      response.statusCode = 400;
      response.data = {
        "message":
            ex.message ?? "An unexpected error occurred. Please try again.",
      };
    }

    return response;
  }
}
