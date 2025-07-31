import 'package:pwa/models/coordinates.model.dart';

class Address {
  final Coordinates coordinates;
  final String? addressLine;
  final String? countryName;
  final String? countryCode;
  final String? featureName;
  final String? postalCode;
  final String? adminArea;
  final String? subAdminArea;
  final String? locality;
  final String? subLocality;
  final String? thoroughfare;
  final String? subThoroughfare;
  String? gMapPlaceId;

  Address({
    required this.coordinates,
    this.addressLine,
    this.countryName,
    this.countryCode,
    this.featureName,
    this.postalCode,
    this.adminArea,
    this.subAdminArea,
    this.locality,
    this.subLocality,
    this.thoroughfare,
    this.subThoroughfare,
    this.gMapPlaceId,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      coordinates: Coordinates.fromMap(map["geometry"]["location"]),
      addressLine: map['formatted_address'],
      countryName: _getTypeFromAddressComponents("country", map),
      countryCode: _getTypeFromAddressComponents(
        "country",
        map,
        nameType: "short_name",
      ),
      featureName: _getTypeFromAddressComponents("formatted_address", map),
      postalCode: _getTypeFromAddressComponents("postal_code", map),
      locality: _getTypeFromAddressComponents("locality", map),
      subLocality: _getTypeFromAddressComponents("sublocality", map),
      adminArea: _getTypeFromAddressComponents(
        "administrative_area_level_1",
        map,
      ),
      subAdminArea: _getTypeFromAddressComponents(
        "administrative_area_level_2",
        map,
      ),
      thoroughfare: _getTypeFromAddressComponents("thorough_fare", map),
      subThoroughfare: _getTypeFromAddressComponents(
        "sub_thorough_fare",
        map,
      ),
    );
  }

  factory Address.fromServerMap(Map<String, dynamic> map) {
    return Address(
      coordinates: Coordinates.fromMap(map["geometry"]["location"]),
      addressLine: map['formatted_address'],
      countryName: map['country'],
      countryCode: map['country_code'],
      featureName: map['feature_name'] ?? map['formatted_address'],
      postalCode: map["postal_code"],
      locality: map["locality"],
      subLocality: map["sublocality"],
      adminArea: map["administrative_area_level_1"],
      subAdminArea: map["administrative_area_level_2"],
      thoroughfare: map["thorough_fare"],
      subThoroughfare: map["sub_thorough_fare"],
    );
  }

  Map<String, dynamic> toMap() => {
        "coordinates": coordinates.toMap(),
        "addressLine": addressLine,
        "countryName": countryName,
        "countryCode": countryCode,
        "featureName": featureName,
        "postalCode": postalCode,
        "locality": locality,
        "subLocality": subLocality,
        "adminArea": adminArea,
        "subAdminArea": subAdminArea,
        "thoroughfare": thoroughfare,
        "subThoroughfare": subThoroughfare,
      };

  static String? _getTypeFromAddressComponents(
    String type,
    Map<String, dynamic> searchResult, {
    String nameType = "long_name",
  }) {
    for (var component in searchResult["address_components"] as List) {
      if ((component["types"] as List).contains(type)) {
        return component[nameType];
      }
    }
    return null;
  }
}
