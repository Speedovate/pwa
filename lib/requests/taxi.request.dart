// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/models/driver.model.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/models/coupon.model.dart';
import 'package:pwa/models/vehicle.model.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/vehicle_type.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/models/available_driver.model.dart';

class TaxiRequest extends HttpService {
  String _normalizeCouponMessage(String message) {
    return message
        .replaceAll("Coupons", "Promo Codes")
        .replaceAll("Coupon", "Promo Code")
        .replaceAll("coupons", "promo codes")
        .replaceAll("coupon", "promo code")
        .replaceAll("code code", "code")
        .replaceAll("codes code", "codes")
        .replaceAll("code codes", "codes");
  }

  Future<ApiResponse> locationAvailableRequest(
    double latitude,
    double longitude,
  ) async {
    try {
      final apiResult = await get(
        Api.bookingAvailability,
        queryParameters: {
          "latitude": latitude,
          "longitude": longitude,
        },
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> syncDriverLocationRequest() async {
    if (AuthService.isLoggedIn()) {
      orderDriver = orderDriver + 1;
      try {
        final apiResult = await get(
          Api.bookingDriver,
        );
        final apiResponse = ApiResponse.fromResponse(apiResult);
        if (apiResponse.allGood) {}
        return apiResponse;
      } catch (e) {
        throw e.toString();
      }
    } else {
      globalTimer?.cancel();
      throw "!AuthService.isLoggedIn()";
    }
  }

  Future<Order?> ongoingOrderRequest() async {
    try {
      final apiResult = await get(
        Api.bookingCurrent,
        includeHeaders: true,
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      final orderData = apiResponse.body["order"];
      if (apiResponse.allGood) {
        final order = orderData;
        if (order == null) {
          return null;
        }
        return Order.fromJson(order);
      }
      if (apiResponse.code == 500) {
        return null;
      }
      throw apiResponse.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Order?> lastOrderRequest() async {
    try {
      final apiResult = await get(
        Api.bookingLast,
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        final order = apiResponse.body["order"];
        if (order == null) {
          return null;
        }
        return Order.fromJson(order);
      }
      if (apiResponse.code == 500) {
        return null;
      }
      throw apiResponse.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> syncLocationRequest({
    required double lat,
    required double lng,
    required bool isMocked,
    required double earthDistance,
  }) async {
    try {
      final apiResult = await get(
        Api.bookingLocation,
        queryParameters: {
          "lat": lat,
          "lng": lng,
          "is_mocked": isMocked,
          "earth_distance": earthDistance,
        },
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<VehicleType>> vehicleTypesRequest() async {
    try {
      final apiResult = await get(
        Api.bookingVehicles,
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return (apiResponse.body as List<dynamic>)
            .map((object) => VehicleType.fromJson(object))
            .toList();
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<VehicleType>> vehicleTypesPricingRequest(
    Address pickup,
    Address dropoff,
  ) async {
    try {
      final apiResult = await get(
        Api.bookingPricing,
        queryParameters: {
          "type": "ride",
          "pickup":
              "${pickup.coordinates.latitude},${pickup.coordinates.longitude}",
          "dropoff":
              "${dropoff.coordinates.latitude},${dropoff.coordinates.longitude}",
          "country_code": "PH",
          "is_pick_and_drop": false,
        },
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return (apiResponse.body as List)
            .map((object) => VehicleType.fromJson(object))
            .toList();
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Coupon> coupon(String code) async {
    try {
      final apiResult = await get(
        "${Api.coupons}/$code",
        queryParameters: {},
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return Coupon.fromJson(apiResponse.body);
      } else {
        throw _normalizeCouponMessage(apiResponse.message);
      }
    } catch (e) {
      throw _normalizeCouponMessage(e.toString());
    }
  }

  Future<ApiResponse> placeNewOrderRequest({
    required Map<String, dynamic> params,
  }) async {
    try {
      final apiResult = await post(
        Api.bookingSubmit,
        params,
      );
      final response = ApiResponse.fromResponse(apiResult);
      return response;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Driver> getDriverInfo(int? id) async {
    try {
      final apiResult = await get(
        "${Api.bookingDriverInfo}/$id",
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        final driver = Driver.fromJson(apiResponse.body["driver"]);
        driver.vehicle = Vehicle.fromJson(apiResponse.body["vehicle"]);
        return driver;
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<AvailableDriver?> findAvailableDriver({
    required Address? pickup,
    required Address? dropoff,
    required int vehicleTypeId,
    required List<VehicleType> types,
  }) async {
    try {
      if (pickup == null) {
        availableDriver = null;
        otherVehicleOpen = false;
        availableVehicles = [];
        throw "There was a problem with your pickup address";
      } else if (dropoff == null) {
        availableDriver = null;
        otherVehicleOpen = false;
        availableVehicles = [];
        throw "There was a problem with your dropoff location";
      } else {
        final queryParameters = {
          "type": "ride",
          "pickup":
              "${pickup.coordinates.latitude},${pickup.coordinates.longitude}",
          "dropoff":
              "${dropoff.coordinates.latitude},${dropoff.coordinates.longitude}",
        };
        final apiResult = await get(
          "/vehicle/$vehicleTypeId/find_available",
          queryParameters: queryParameters,
        );
        final apiResponse = ApiResponse.fromResponse(
          apiResult,
        );
        if (apiResponse.allGood) {
          availableVehicles = [];
          otherVehicleOpen = false;
          availableDriver = AvailableDriver.fromJson(
            apiResponse.body,
          );
          return availableDriver;
        } else {
          // availableDriver = null;
          // otherVehicleOpen = false;
          // availableVehicles = [];
          // for (VehicleType type in types) {
          //   if (type.id != vehicleTypeId) {
          //     try {
          //       final apiResult = await get(
          //         "/vehicle/${type.id}/find_available",
          //         queryParameters: {
          //           "type": "ride",
          //           "pickup": "${pickup.coordinates.latitude},"
          //               "${pickup.coordinates.longitude}",
          //           "dropoff": "${dropoff.coordinates.latitude},"
          //               "${dropoff.coordinates.longitude}",
          //         },
          //       );
          //       final apiResponse = ApiResponse.fromResponse(apiResult);
          //       if (apiResponse.allGood) {
          //         availableVehicles.add(type);
          //       }
          //     } catch (e) {
          //       throw e.toString();
          //     }
          //   }
          // }
          // if (availableVehicles.isEmpty) {
          //   otherVehicleOpen = false;
          // } else {
          otherVehicleOpen = true;
          return null;
          // }
        }
      }
    } catch (e) {
      availableDriver = null;
      availableVehicles = [];
      otherVehicleOpen = false;
    }
    return null;
  }

  Future<ApiResponse> cancelOrderRequest({
    required int id,
    required bool rebook,
    required String reason,
  }) async {
    try {
      final apiResult = await get(
        "${Api.bookingCancel}/$id?rebook=${rebook ? 1 : 0}",
        queryParameters: {
          "reason": reason,
        },
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> passOrderRequest({
    required int id,
    required int targetDriverId,
    String? reason,
  }) async {
    try {
      final apiResult = await post(
        "${Api.baseUrl}/booking/order/$id/pass",
        {
          "target_driver_id": targetDriverId,
          "reason": reason ?? "pass",
        },
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw "$e";
    }
  }

  Future<ApiResponse> rateDriverRequest({
    required int? orderId,
    required int? driverId,
    required double? rating,
    required String? review,
  }) async {
    try {
      final apiResult = await post(
        Api.bookingRating,
        {
          "rating": rating,
          "review": review,
          "order_id": orderId,
          "driver_id": driverId,
        },
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> reportDriverRequest({
    required String? message,
    required int? orderId,
  }) async {
    dynamic body = {
      "message": message,
      "order_id": orderId,
    };
    try {
      FormData formData = FormData.fromMap(body);
      final apiResult = await postCustomFiles(
        Api.bookingReport,
        null,
        formData: formData,
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }
}
