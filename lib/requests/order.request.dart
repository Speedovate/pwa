import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/chat_media.model.dart';
import 'package:pwa/models/api_response.model.dart';

class OrderRequest extends HttpService {
  Future<List<Order>> getOrdersRequest({required int page}) async {
    try {
      final apiResult = await get(
        Api.bookingOrders,
        queryParameters: {
          "page": page,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return apiResponse.data.map(
          (jsonObject) {
            return Order.fromJson(jsonObject);
          },
        ).toList();
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<ChatMedia>> getMedia(int id) async {
    try {
      final apiResult = await get(
        "${Api.bookingOrders}/$id/media",
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        mediaList = apiResponse.data.map(
          (jsonObject) {
            return ChatMedia.fromJson(jsonObject);
          },
        ).toList();
        return mediaList;
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> postMedia(
    int id,
    String uploadedBy,
  ) async {
    if (chatFile == null || chatFile!.isEmpty) {
      throw "No image selected.";
    }
    dynamic body = {
      "uploaded_by": uploadedBy,
    };
    FormData formData = FormData.fromMap(body);
    formData.files.add(
      MapEntry(
        "media",
        MultipartFile.fromBytes(
          chatFile!,
          filename: "image_${Random().nextInt(900000)}.jpg",
        ),
      ),
    );
    try {
      final apiResult = await postCustomFiles(
        "${Api.bookingOrders}/$id/media",
        null,
        formData: formData,
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResult.statusCode == 200 && apiResult.data is String) {
        return ApiResponse(
          code: 200,
          message: (apiResult.data as String).trim().isEmpty
              ? "Upload completed."
              : (apiResult.data as String).trim(),
          body: apiResult.data,
        );
      }
      if (!apiResponse.allGood) {
        final status = apiResult.statusCode;
        final rawBody = apiResult.data;
        throw "Upload failed${status == null ? "" : " [$status]"}: ${apiResponse.message}${rawBody == null ? "" : " | Response: $rawBody"}";
      }
      return apiResponse;
    } catch (e) {
      debugPrint("postMedia error for order $id uploaded_by=$uploadedBy: $e");
      throw e.toString();
    }
  }
}
