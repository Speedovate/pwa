import 'dart:math';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:singleton/singleton.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

class GeocoderService extends HttpService {
  factory GeocoderService() => Singleton.lazy(() => GeocoderService._());

  GeocoderService._();

  Future<List<Address>> findAddressesFromCoordinates(
      Coordinates coordinates) async {
    final apiResult = await get(
      Api.geoCoordinates,
      queryParameters: {
        "lat": coordinates.latitude,
        "lng": coordinates.longitude,
      },
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
    if (isBool(AppStrings.homeSettingsObject?["use_external"] ?? true)) {
      final apiResult = await getExternal(
        "https://cors-anywhere.com/https://maps.googleapis.com/maps/api/place/textsearch/json?query=$keyword%20puerto%20princesa&location=${initLatLng?.lat ?? 9.7392},${initLatLng?.lat ?? 118.7353}&radius=15000&key=AIza${AppStrings.homeSettingsObject?["external_api"] ?? "SyAZ_QLjsiFZnrZr33sCqW-SlTtkIV7PTeM"}",
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        List<dynamic> results = apiResponse.body["results"];
        List<Address> finalAddresses = [];
        for (var e in results) {
          double? lat = e["geometry"]?["location"]?["lat"];
          double? lng = e["geometry"]?["location"]?["lng"];
          if (lat == null || lng == null) continue;
          String? rawAddress = e["formatted_address"];
          if (isReadableAddress(rawAddress)) {
            final address = Address.fromServerMap(e);
            address.gMapPlaceId = e["place_id"] ?? "";
            finalAddresses.add(address);
          } else {
            final fallbackAddresses =
                await findAddressesFromCoordinates(Coordinates(lat, lng));
            if (fallbackAddresses.isNotEmpty) {
              final address = fallbackAddresses.first;
              address.gMapPlaceId = e["place_id"] ?? "";
              finalAddresses.add(address);
            }
          }
        }
        return finalAddresses;
      }
      return [];
    } else {
      String myLatLng = "${initLatLng?.lat},${initLatLng?.lat}";
      final apiResult = await get(
        Api.geoAddresses,
        queryParameters: {
          "keyword": keyword,
          "location": myLatLng,
        },
      ).timeout(const Duration(seconds: 30));
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return (apiResponse.data).map((e) {
          final address = Address.fromServerMap(e);
          address.gMapPlaceId = e["place_id"] ?? "";
          return address;
        }).toList();
      }
      return [];
    }
  }

  Future<Address> fetchPlaceDetails(Address address) async {
    final apiResult = await get(
      Api.geoAddresses,
      queryParameters: {
        "place_id": address.gMapPlaceId,
      },
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
    final apiResult = await get(
      Api.geoPolylines,
      queryParameters: {
        "purpose": purpose,
        "key": AppStrings.googleMapApiKey,
        "origin": "${pointA.lat},${pointA.lng}",
        "destination": "${pointB.lat},${pointB.lng}",
      },
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
      double dlat = ((result % 2 != 0)
          ? -(result / 2 + 1).floorToDouble()
          : (result / 2));
      lat += dlat;
      result = 0.0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += (b & 0x1F) * pow(2, shift);
        shift += 5;
      } while (b >= 0x20);
      double dlng = ((result % 2 != 0)
          ? -(result / 2 + 1).floorToDouble()
          : (result / 2));
      lng += dlng;
      poly.add([lat / 1e5, lng / 1e5]);
    }
    return poly;
  }
}
