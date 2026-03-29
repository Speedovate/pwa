import 'package:dio_http_cache_lts/dio_http_cache_lts.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/models/banner.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/api_response.model.dart';

class SettingsRequest extends HttpService {
  Future<ApiResponse> homeSettingsRequest() async {
    try {
      final apiResult = await dio.get(
        Api.homeConfigs,
        options: buildCacheOptions(
          const Duration(hours: 1),
          forceRefresh: true,
        ),
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      return apiResponse;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> appSettingsRequest() async {
    try {
      final apiResult = await dio.get(
        Api.appConfigs,
        options: buildCacheOptions(
          const Duration(hours: 1),
          forceRefresh: true,
        ),
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      return apiResponse;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<Banner>> bannersRequest() async {
    try {
      final apiResult = await get(
        "${Api.baseUrl}${Api.banners}",
      ).timeout(
        const Duration(seconds: 30),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return apiResponse.data.map((item) => Banner.fromJson(item)).toList();
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
