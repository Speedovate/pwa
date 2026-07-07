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

class _RequestBannerSchedule {
  _RequestBannerSchedule(this._timers);

  final List<Timer> _timers;

  void cancel() {
    for (final timer in _timers) {
      timer.cancel();
    }
  }
}

class HttpService {
  static const Duration _weakConnectionBannerDelay = Duration(seconds: 45);
  static const Duration _noConnectionBannerDelay = Duration(seconds: 90);
  static const Duration _serverBannerDelay = Duration(seconds: 180);
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
    final bannerSchedule = _startRequestBannerSchedule(
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
      bannerSchedule.cancel();
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
    final bannerSchedule = _startRequestBannerSchedule(
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
      bannerSchedule.cancel();
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
    final bannerSchedule = _startRequestBannerSchedule(
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
      bannerSchedule.cancel();
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
    final bannerSchedule = _startRequestBannerSchedule(
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
      bannerSchedule.cancel();
    }
  }

  Future<Response> patch(String url, Map<String, dynamic> body) async {
    final uri = _buildUri(url);
    final requestStartedAt = DateTime.now();
    _logRequestStart("PATCH", uri, requestStartedAt);
    final bannerSchedule = _startRequestBannerSchedule(
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
      bannerSchedule.cancel();
    }
  }

  Future<Response> delete(String url) async {
    final uri = _buildUri(url);
    final requestStartedAt = DateTime.now();
    _logRequestStart("DELETE", uri, requestStartedAt);
    final bannerSchedule = _startRequestBannerSchedule(
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
      bannerSchedule.cancel();
    }
  }

  Future<Response> getExternal(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final requestStartedAt = DateTime.now();
    _logRequestStart("GET_EXTERNAL", url, requestStartedAt);
    final bannerSchedule = _startRequestBannerSchedule(
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
      bannerSchedule.cancel();
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

  _RequestBannerSchedule _startRequestBannerSchedule(
    String method,
    String url,
    DateTime requestStartedAt,
  ) {
    final requestUri = Uri.tryParse(url);
    final isAppServerRequest =
        requestUri != null && _isAppServerUri(requestUri);
    final ignoresServerBanner = requestUri != null &&
        _ignoresServerBannerRequest(
          method,
          requestUri,
        );

    return _RequestBannerSchedule(
      [
        Timer(
          _weakConnectionBannerDelay,
          () {
            if (ConnectionBannerService.isServerBannerVisible) {
              return;
            }
            ConnectionBannerService.show(
              ConnectionBannerType.weakConnection,
              requestStartedAt: requestStartedAt,
            );
          },
        ),
        Timer(
          _noConnectionBannerDelay,
          () {
            if (ConnectionBannerService.isServerBannerVisible) {
              return;
            }
            ConnectionBannerService.show(
              ConnectionBannerType.connection,
              requestStartedAt: requestStartedAt,
            );
          },
        ),
        if (isAppServerRequest && !ignoresServerBanner)
          Timer(
            _serverBannerDelay,
            () {
              ConnectionBannerService.show(
                ConnectionBannerType.server,
                requestStartedAt: requestStartedAt,
              );
            },
          ),
      ],
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
          "message": _resolveDioExceptionMessage(
            ex,
            fallback: "Service temporarily unavailable.",
          ),
        };
      } else if (appServerRequest && online) {
        ConnectionBannerService.show(
          ConnectionBannerType.server,
          requestStartedAt: requestStartedAt,
        );
        response.statusCode = 503;
        response.data = {
          "message": _resolveDioExceptionMessage(
            ex,
            fallback: "Service temporarily unavailable.",
          ),
        };
      } else {
        ConnectionBannerService.show(
          ConnectionBannerType.weakConnection,
          requestStartedAt: requestStartedAt,
        );
        response.statusCode = 408;
        response.data = {
          "message": _resolveDioExceptionMessage(
            ex,
            fallback: "Weak connection.",
          ),
        };
      }
    } else if (ex.type == DioExceptionType.connectionError ||
        ex.type == DioExceptionType.unknown) {
      ConnectionBannerService.show(
        ConnectionBannerType.connection,
        requestStartedAt: requestStartedAt,
      );
      response.data = {
        "message": _resolveDioExceptionMessage(
          ex,
          fallback: "No connection.",
        ),
      };
    } else {
      response.statusCode = 400;
      response.data = {
        "message": _resolveDioExceptionMessage(
          ex,
          fallback: "An unexpected error occurred. Please try again.",
        ),
      };
    }

    return response;
  }

  String _resolveDioExceptionMessage(
    DioException ex, {
    required String fallback,
  }) {
    final responseData = ex.response?.data;
    if (responseData is Map<String, dynamic>) {
      final responseMessage = "${responseData["message"] ?? ""}".trim();
      if (responseMessage.isNotEmpty &&
          responseMessage.toLowerCase() != "null") {
        return responseMessage;
      }
    } else if (responseData is String) {
      final responseMessage = responseData.trim();
      if (responseMessage.isNotEmpty &&
          responseMessage.toLowerCase() != "null") {
        return responseMessage;
      }
    }

    final errorMessage = "${ex.error ?? ""}".trim();
    if (errorMessage.isNotEmpty && errorMessage.toLowerCase() != "null") {
      return errorMessage;
    }

    final dioMessage = (ex.message ?? "").trim();
    if (dioMessage.isNotEmpty && dioMessage.toLowerCase() != "null") {
      return dioMessage;
    }

    return fallback;
  }
}
