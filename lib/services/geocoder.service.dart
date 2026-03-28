import 'dart:math';
import 'dart:convert';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:singleton/singleton.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;

class GeocoderService extends HttpService {
  factory GeocoderService() => Singleton.lazy(() => GeocoderService._());

  GeocoderService._();

  Future<List<Address>> findAddressesFromCoordinates(
      Coordinates coordinates) async {
    final useExternal = isBool(
      AppStrings.appSettingsObject?["strings"][useExt] ?? true,
    );
    final apiResult = await get(
      !useExternal
          ? Api.geoCoordinates
          : "https://backrideph.online/api/geocoder/forward",
      queryParameters: {
        "lat": coordinates.latitude,
        "lng": coordinates.longitude,
      },
      includeHeaders: !useExternal,
    ).timeout(const Duration(seconds: 30));

    final apiResponse = ApiResponse.fromResponse(apiResult);
    if (apiResponse.allGood) {
      return (apiResponse.data).map((e) => Address.fromServerMap(e)).toList();
    }
    return [];
  }

  bool isReadableAddress(String? address) {
    if (address == null || address.trim().isEmpty) return false;
    final plusCodePattern = RegExp(
        r'^[23456789CFGHJMPQRVWX]{4,}\+?[23456789CFGHJMPQRVWX]{2,}',
        caseSensitive: false);
    final coordinatePattern = RegExp(r'^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$');
    if (plusCodePattern.hasMatch(address.trim().split(',').first)) return false;
    if (coordinatePattern.hasMatch(address.trim())) return false;
    return true;
  }

  Future<List<Address>> findAddressesFromQuery(String keyword) async {
    String latLng = "${initLatLng?.lat},${initLatLng?.lng}";
    bool useExternal = isBool(
      AppStrings.appSettingsObject?["strings"][useExt] ?? true,
    );
    List<Address> results = [];
    if (useExternal) {
      try {
        final response = await get(
          "https://backrideph.online/api/geocoder/reserve",
          queryParameters: {
            "keyword": keyword,
            "location": latLng,
          },
          includeHeaders: false,
        ).timeout(const Duration(seconds: 30));
        final apiResponse = ApiResponse.fromResponse(response);
        if (apiResponse.allGood) {
          return (apiResponse.data).map((e) {
            final address = Address.fromServerMap(e);
            address.gMapPlaceId = e["place_id"] ?? "";
            return address;
          }).toList();
        }
      } catch (_) {}
      return [];
    }
    try {
      final mainResponse = await get(
        Api.geoAddresses,
        queryParameters: {
          "keyword": keyword,
          "location": latLng,
        },
      ).timeout(const Duration(seconds: 30));
      final apiResponse = ApiResponse.fromResponse(mainResponse);
      if (apiResponse.allGood) {
        results.addAll(
          (apiResponse.data).map((e) {
            final address = Address.fromServerMap(e);
            address.gMapPlaceId = e["place_id"] ?? "";
            return address;
          }),
        );
      }
    } catch (_) {}
    try {
      final backrideResponse = await get(
        "https://backrideph.online/api/geocoder/reserve",
        queryParameters: {
          "keyword": keyword,
          "location": latLng,
        },
        includeHeaders: false,
      ).timeout(const Duration(seconds: 30));

      final apiResponse = ApiResponse.fromResponse(backrideResponse);
      if (apiResponse.allGood) {
        results.addAll(
          (apiResponse.data).map((e) {
            final address = Address.fromServerMap(e);
            address.gMapPlaceId = e["place_id"] ?? "";
            return address;
          }),
        );
      }
    } catch (_) {}
    return results;
  }

  Future<Address> fetchPlaceDetails(Address address) async {
    final useExternal = isBool(
      AppStrings.appSettingsObject?["strings"][useExt] ?? true,
    );
    final apiResult = await get(
      !useExternal
          ? Api.baseUrl + Api.geoAddresses
          : "https://backrideph.online/api/geocoder/reserve",
      queryParameters: {
        "place_id": address.gMapPlaceId,
      },
      includeHeaders: !useExternal,
    ).timeout(const Duration(seconds: 30));
    final apiResponse = ApiResponse.fromResponse(apiResult);
    if (apiResponse.allGood) {
      try {
        return Address.fromServerMap(apiResponse.body as Map<String, dynamic>);
      } catch (_) {
        return address;
      }
    }
    return address;
  }

  Future<List<List<double>>> getPolyline(
    gmaps.LatLng pointA,
    gmaps.LatLng pointB,
    String purpose,
  ) async {
    final useExternal = isBool(
      AppStrings.appSettingsObject?["strings"][useExt] ?? true,
    );
    final apiResult = await get(
      !useExternal
          ? Api.geoPolylines
          : "https://backrideph.online/api/polylines",
      queryParameters: {
        "purpose": purpose,
        "key": AppStrings.googleMapApiKey,
        "origin": "${pointA.lat},${pointA.lng}",
        "destination": "${pointB.lat},${pointB.lng}",
      },
      includeHeaders: !useExternal,
    ).timeout(const Duration(seconds: 30));
    final apiResponse = ApiResponse.fromResponse(apiResult);
    if (apiResponse.allGood) {
      final decoded = decodeEncodedPolyline(
        apiResponse.body["data"].toString(),
      );
      return decoded;
    }
    throw apiResponse.message;
  }

  List<List<double>> decodeEncodedPolyline(String encoded) {
    try {
      encoded = jsonDecode('"$encoded"');
    } catch (_) {}
    try {
      encoded = Uri.decodeFull(encoded);
    } catch (_) {}
    List<List<double>> poly = [];
    int index = 0;
    final int len = encoded.length;
    double lat = 0.0;
    double lng = 0.0;
    while (index < len) {
      double result = 0.0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += (b & 0x1F) * pow(2, shift);
        shift += 5;
      } while (b >= 0x20);
      double dlat =
          (result % 2 != 0) ? -(result / 2 + 1).floorToDouble() : (result / 2);
      lat += dlat;
      result = 0.0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += (b & 0x1F) * pow(2, shift);
        shift += 5;
      } while (b >= 0x20);
      double dlng =
          (result % 2 != 0) ? -(result / 2 + 1).floorToDouble() : (result / 2);
      lng += dlng;
      poly.add([lat, lng]);
    }
    if (poly.isEmpty) return [];
    final isPolyline6 = poly.any(
      (p) => p[0].abs() > 9e6 || p[1].abs() > 18e6,
    );
    final precision = isPolyline6 ? 1e6 : 1e5;
    return poly.map((p) => [p[0] / precision, p[1] / precision]).toList();
  }
}
