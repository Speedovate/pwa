import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/chat_media.model.dart';
import 'package:pwa/models/api_response.model.dart';

class OrderRequest extends HttpService {
  String _chatUploadExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return "png";
    }
    return "jpg";
  }

  Future<List<Order>> getOrdersRequest({required int page}) async {
    try {
      final apiResult = await get(
        Api.bookingOrders,
        queryParameters: {
          "page": page,
        },
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
    final chatUploadExt = _chatUploadExtension(chatFile!);
    dynamic body = {
      "uploaded_by": uploadedBy,
    };
    FormData formData = FormData.fromMap(body);
    formData.files.add(
      MapEntry(
        "media",
        MultipartFile.fromBytes(
          chatFile!,
          filename: "image_${Random().nextInt(900000)}.$chatUploadExt",
        ),
      ),
    );
    try {
      final apiResult = await postCustomFiles(
        "${Api.bookingOrders}/$id/media",
        null,
        formData: formData,
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
        throw status == 500
            ? "The photo failed to upload. Please try a smaller image."
            : "The photo failed to upload. ${apiResponse.message}";
      }
      return apiResponse;
    } catch (e) {
      throw e.toString();
    }
  }
}
