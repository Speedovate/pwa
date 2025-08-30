import "dart:convert";
import "package:pwa/utils/data.dart";
import "package:flutter/material.dart";
import "package:pwa/utils/functions.dart";
import "package:pwa/models/trip_details.model.dart";
import "package:pwa/models/vehicle_type.model.dart";
import 'package:google_maps/google_maps.dart' as gmaps;

TaxiOrder taxiOrderFromJson(String str) => TaxiOrder.fromJson(json.decode(str));

String taxiOrderToJson(TaxiOrder data) => json.encode(data.toJson());

class TaxiOrder {
  int? id;
  int? orderId;
  int? vehicleTypeId;
  double? pickupKm;
  double? pickupFee;
  double? pickupExceedKm;
  double? pickupPerExceedKm;
  bool? isWalkIn;
  bool? isQuickBook;
  String? pickupAddress;
  double? pickupLatitude;
  double? pickupLongitude;
  String? dropoffAddress;
  double? dropoffLatitude;
  double? dropoffLongitude;
  double? driverAcceptLatitude;
  double? driverAcceptLongitude;
  DateTime? createdAt;
  DateTime? updatedAt;
  VehicleType? vehicleType;
  TripDetails? tripDetails;

  TaxiOrder({
    this.id,
    this.orderId,
    this.vehicleTypeId,
    this.pickupKm,
    this.pickupFee,
    this.pickupExceedKm,
    this.pickupPerExceedKm,
    this.isWalkIn,
    this.isQuickBook,
    this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffAddress,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.driverAcceptLatitude,
    this.driverAcceptLongitude,
    this.createdAt,
    this.updatedAt,
    this.tripDetails,
    this.vehicleType,
  });

  factory TaxiOrder.fromJson(Map<String, dynamic>? json) {
    try {
      if (showParseText) {
        debugPrint("Parsing TaxiOrder from JSON...");
      }
      return TaxiOrder(
        id: parseInt(json?["id"], "id"),
        orderId: parseInt(json?["order_id"], "order_id"),
        vehicleTypeId: parseInt(json?["vehicle_type_id"], "vehicle_type_id"),
        pickupKm: parseDouble(json?["pickup_km"], "pickup_km"),
        pickupFee: parseDouble(json?["pickup_fee"], "pickup_fee"),
        pickupExceedKm:
            parseDouble(json?["pickup_exceed_km"], "pickup_exceed_km"),
        pickupPerExceedKm:
            parseDouble(json?["pickup_per_exceed_km"], "pickup_per_exceed_km"),
        isWalkIn: parseBool(json?["is_walk_in"], "is_walk_in"),
        isQuickBook: parseBool(json?["is_quick_book"], "is_quick_book"),
        pickupAddress: parseString(json?["pickup_address"], "pickup_address"),
        pickupLatitude:
            parseDouble(json?["pickup_latitude"], "pickup_latitude"),
        pickupLongitude:
            parseDouble(json?["pickup_longitude"], "pickup_longitude"),
        dropoffAddress:
            parseString(json?["dropoff_address"], "dropoff_address"),
        dropoffLatitude:
            parseDouble(json?["dropoff_latitude"], "dropoff_latitude"),
        dropoffLongitude:
            parseDouble(json?["dropoff_longitude"], "dropoff_longitude"),
        driverAcceptLatitude: parseDouble(
            json?["driver_accept_latitude"], "driver_accept_latitude"),
        driverAcceptLongitude: parseDouble(
            json?["driver_accept_longitude"], "driver_accept_longitude"),
        createdAt: parseDateTime(json?["created_at"], "created_at"),
        updatedAt: parseDateTime(json?["updated_at"], "updated_at"),
        tripDetails: json?["trip_details"] == null
            ? null
            : TripDetails.fromJson(json?["trip_details"]),
        vehicleType: json?["vehicle_type"] == null
            ? null
            : VehicleType.fromJson(json?["vehicle_type"]),
      );
    } catch (e) {
      if (showParseText) {
        debugPrint("Error parsing TaxiOrder: $e");
        debugPrint("TaxiOrder JSON: $json");
      }
      return TaxiOrder();
    }
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "order_id": orderId,
        "vehicle_type_id": vehicleTypeId,
        "pickup_km": pickupKm,
        "pickup_fee": pickupFee,
        "pickup_exceed_km": pickupExceedKm,
        "pickup_per_exceed_km": pickupPerExceedKm,
        "is_walk_in": isWalkIn,
        "is_quick_book": isQuickBook,
        "pickup_address": pickupAddress,
        "pickup_latitude": pickupLatitude,
        "pickup_longitude": pickupLongitude,
        "dropoff_address": dropoffAddress,
        "dropoff_latitude": dropoffLatitude,
        "dropoff_longitude": dropoffLongitude,
        "driver_accept_latitude": driverAcceptLatitude,
        "driver_accept_longitude": driverAcceptLongitude,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "trip_details": tripDetails?.toJson(),
        "vehicle_type": vehicleType?.toJson(),
      };

  gmaps.LatLng get pickupLatLng => gmaps.LatLng(
        pickupLatitude!,
        pickupLongitude!,
      );

  gmaps.LatLng get dropoffLatLng => gmaps.LatLng(
        dropoffLatitude!,
        dropoffLongitude!,
      );

  gmaps.LatLng get driverAcceptLatLng {
    return gmaps.LatLng(
      driverAcceptLatitude ?? 0.0,
      driverAcceptLongitude ?? 0.0,
    );
  }
}
