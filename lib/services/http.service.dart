import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:dio_http_cache_lts/dio_http_cache_lts.dart';
import 'package:rx_shared_preferences/rx_shared_preferences.dart';

class HttpService {
  String host = Api.baseUrl;

  late Dio dio;
  late BaseOptions baseOptions;
  late SharedPreferences prefs;

  Future<Map<String, String>> getHeaders() async {
    print("pwet "+jsonEncode({
      HttpHeaders.authorizationHeader: "Bearer ${AuthService.bearerToken}",
      HttpHeaders.acceptHeader: "application/json",
      "build_number": version ?? "",
      "platform": AuthService.device(),
      "code": versionCode ?? "",
      "role": "client",
      "lang": "en",
    }));
    return {
      HttpHeaders.authorizationHeader: "Bearer ${AuthService.bearerToken}",
      HttpHeaders.acceptHeader: "application/json",
      "build_number": version ?? "",
      "platform": AuthService.device(),
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

    try {
      return await dio.get(
        uri,
        options: options,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      return _formatDioException(e);
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

    try {
      return await dio.post(
        uri,
        data: _convertBool(body),
        options: options,
      );
    } on DioException catch (e) {
      return _formatDioException(e);
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

    try {
      return await dio.post(
        uri,
        data: FormData.fromMap(_convertBool(body)),
        options: options,
      );
    } on DioException catch (e) {
      return _formatDioException(e);
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

    try {
      final effectiveFormData =
          formData ?? FormData.fromMap(_convertBool(body ?? {}));
      return await dio.post(
        uri,
        data: effectiveFormData,
        options: options,
      );
    } on DioException catch (e) {
      return _formatDioException(e);
    } catch (e) {
      throw "An unexpected error occurred: $e";
    }
  }

  Future<Response> patch(String url, Map<String, dynamic> body) async {
    final uri = _buildUri(url);

    try {
      return await dio.patch(
        uri,
        data: _convertBool(body),
        options: Options(
          headers: await getHeaders(),
        ),
      );
    } on DioException catch (e) {
      return _formatDioException(e);
    }
  }

  Future<Response> delete(String url) async {
    final uri = _buildUri(url);

    try {
      return await dio.delete(uri,
          options: Options(
            headers: await getHeaders(),
          ));
    } on DioException catch (e) {
      return _formatDioException(e);
    }
  }

  Future<Response> getExternal(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get(
        url,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      return _formatDioException(e);
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
    debugPrint(
      "api request ${url.startsWith("https") ? url : "$host${url.startsWith("/") ? "" : "/"}$url"}",
    );
    return url.startsWith("https")
        ? url
        : "$host${url.startsWith("/") ? "" : "/"}$url";
  }

  Response _formatDioException(DioException ex) {
    final response = Response(requestOptions: ex.requestOptions)
      ..statusCode = 400;

    if (ex.type == DioExceptionType.connectionTimeout) {
      response.data = {
        "message":
            "Connection timeout. Please check your internet connection and try again.",
      };
    } else if (ex.type == DioExceptionType.badResponse) {
      response.data = {
        "message": "Received invalid response: ${ex.response?.data}",
      };
    } else {
      response.data = {
        "message":
            ex.message ?? "An unexpected error occurred. Please try again.",
      };
    }

    return response;
  }
}
