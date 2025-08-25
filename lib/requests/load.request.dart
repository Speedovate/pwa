import 'package:pwa/constants/api.dart';
import 'package:pwa/models/load.model.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/models/load_transaction.model.dart';

class LoadRequest extends HttpService {
  Future<Load> loadBalanceRequest() async {
    try {
      final apiResult = await get(
        Api.loadBalance,
        includeHeaders: true,
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        Load? load;
        load = Load.fromJson(apiResponse.body);
        if (load.balance == null) {
          load = Load.fromJson(apiResponse.body["data"]);
        }
        return load;
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<String> loadTopupRequest(String amount) async {
    try {
      final apiResult = await post(
        Api.loadBuy,
        {
          "amount": amount,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return apiResponse.body["link"];
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<LoadTransaction>> loadTransactions({
    int page = 1,
  }) async {
    try {
      final apiResult = await get(
        Api.loadTransactions,
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
        return (apiResponse.body["data"] as List)
            .map((e) => LoadTransaction.fromJson(e))
            .toList();
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> transferBalanceRequest({
    required int userId,
    required String amount,
  }) async {
    try {
      final apiResult = await post(
        Api.loadTransfer,
        {
          "user_id": userId,
          "amount": amount,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }
}
