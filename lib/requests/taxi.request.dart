// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/models/driver.model.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/models/vehicle.model.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/vehicle_type.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/models/available_driver.model.dart';

class TaxiRequest extends HttpService {
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

  Future<ApiResponse> syncDriverLocationRequest() async {
    if (AuthService.isLoggedIn()) {
      orderDriver = orderDriver + 1;
      try {
        final apiResult = await get(
          Api.bookingDriver,
        ).timeout(
          const Duration(
            seconds: 30,
          ),
        );
        final apiResponse = ApiResponse.fromResponse(apiResult);
        if (apiResponse.allGood) {
          debugPrint(
            "${DateFormat("dd MMM yyyy, h:mm:ss a").format(DateTime.now()).toString()} LatLng(${apiResponse.body["lat"]}, ${apiResponse.body["long"]}) $orderDriver Calls",
          );
        }
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
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return Order.fromJson(apiResponse.body["order"]);
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Order?> lastOrderRequest() async {
    try {
      final apiResult = await get(
        Api.bookingLast,
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return Order.fromJson(apiResponse.body["order"]);
      } else {
        throw apiResponse.message;
      }
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

  Future<List<VehicleType>> vehicleTypesRequest() async {
    try {
      final apiResult = await get(
        Api.bookingVehicles,
      ).timeout(
        const Duration(
          seconds: 30,
        ),
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
      ).timeout(
        const Duration(
          seconds: 30,
        ),
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

  Future<ApiResponse> placeNewOrderRequest({
    required Map<String, dynamic> params,
  }) async {
    try {
      final apiResult = await post(
        Api.bookingSubmit,
        params,
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

  Future<Driver> getDriverInfo(int? id) async {
    try {
      final apiResult = await get(
        "${Api.bookingDriverInfo}/$id",
      ).timeout(
        const Duration(
          seconds: 30,
        ),
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
        final apiResult = await get(
          "/vehicle/$vehicleTypeId/find_available",
          queryParameters: {
            "type": "ride",
            "pickup":
                "${pickup.coordinates.latitude},${pickup.coordinates.longitude}",
            "dropoff":
                "${dropoff.coordinates.latitude},${dropoff.coordinates.longitude}",
          },
        ).timeout(
          const Duration(
            seconds: 30,
          ),
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
          availableDriver = null;
          otherVehicleOpen = false;
          availableVehicles = [];
          for (VehicleType type in types) {
            if (type.id != vehicleTypeId) {
              try {
                final apiResult = await get(
                  "/vehicle/${type.id}/find_available",
                  queryParameters: {
                    "type": "ride",
                    "pickup": "${pickup.coordinates.latitude},"
                        "${pickup.coordinates.longitude}",
                    "dropoff": "${dropoff.coordinates.latitude},"
                        "${dropoff.coordinates.longitude}",
                  },
                ).timeout(
                  const Duration(
                    seconds: 30,
                  ),
                );
                final apiResponse = ApiResponse.fromResponse(apiResult);
                if (apiResponse.allGood) {
                  availableVehicles.add(type);
                }
              } catch (e) {
                throw e.toString();
              }
            }
          }
          if (availableVehicles.isEmpty) {
            otherVehicleOpen = false;
          } else {
            otherVehicleOpen = true;
            return null;
          }
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
