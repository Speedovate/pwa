import "dart:convert";
import "package:pwa/utils/data.dart";
import "package:flutter/material.dart";
import "package:pwa/utils/functions.dart";
import "package:pwa/models/vehicle_type.model.dart";

TripDetails tripDetailsFromJson(String str) =>
    TripDetails.fromJson(json.decode(str));

String tripDetailsToJson(TripDetails data) => json.encode(data.toJson());

class TripDetails {
  double? kmDistance;
  double? pickupDropoffSubtotal;
  double? pickupExceedKm;
  double? pickupChargeFee;
  double? pickupKm;
  double? pickupPerExceedKm;
  double? luggageFee;
  double? total;
  String? originalPickupLatLng;
  String? eta;
  VehicleType? vehicleType;
  int? stopTimer;
  bool? isAutoCancel;
  bool? isRebookCancel;
  int? cancelInitiatorId;

  TripDetails({
    this.kmDistance,
    this.pickupDropoffSubtotal,
    this.pickupExceedKm,
    this.pickupChargeFee,
    this.pickupKm,
    this.pickupPerExceedKm,
    this.luggageFee,
    this.total,
    this.originalPickupLatLng,
    this.eta,
    this.vehicleType,
    this.stopTimer,
    this.isAutoCancel,
    this.isRebookCancel,
    this.cancelInitiatorId,
  });

  factory TripDetails.fromJson(Map<String, dynamic> json) {
    try {
      if (showParseText) {
        debugPrint("Parsing TripDetails from JSON...");
      }
      return TripDetails(
        kmDistance: parseDouble(json["km_distance"], "km_distance"),
        pickupDropoffSubtotal: parseDouble(
            json["pickup_dropoff_subtotal"], "pickup_dropoff_subtotal"),
        pickupExceedKm:
            parseDouble(json["pickup_exceed_km"], "pickup_exceed_km"),
        pickupChargeFee:
            parseDouble(json["pickup_charge_fee"], "pickup_charge_fee"),
        pickupKm: parseDouble(json["pickup_km"], "pickup_km"),
        pickupPerExceedKm:
            parseDouble(json["pickup_per_exceed_km"], "pickup_per_exceed_km"),
        luggageFee: parseDouble(json["luggage_fee"], "luggage_fee"),
        total: parseDouble(json["total"], "total"),
        originalPickupLatLng: parseString(
            json["original_pickup_latlng"], "original_pickup_latlng"),
        eta: parseString(json["eta"], "eta"),
        vehicleType: json["vehicle_type"] == null
            ? null
            : VehicleType.fromJson(json["vehicle_type"]),
        stopTimer: parseInt(json["stop_timer"], "stop_timer"),
        isAutoCancel: parseBool(json["is_auto_cancel"], "is_auto_cancel"),
        isRebookCancel: parseBool(json["rebook_cancel"], "rebook_cancel"),
        cancelInitiatorId:
            parseInt(json["cancel_initiator_id"], "cancel_initiator_id"),
      );
    } catch (e) {
      if (showParseText) {
        debugPrint("Error parsing TripDetails: $e");
        debugPrint("TripDetails JSON: $json");
      }
      return TripDetails();
    }
  }

  Map<String, dynamic> toJson() => {
        "km_distance": kmDistance,
        "pickup_dropoff_subtotal": pickupDropoffSubtotal,
        "pickup_exceed_km": pickupExceedKm,
        "pickup_charge_fee": pickupChargeFee,
        "pickup_km": pickupKm,
        "pickup_per_exceed_km": pickupPerExceedKm,
        "luggage_fee": luggageFee,
        "total": total,
        "original_pickup_latlng": originalPickupLatLng,
        "eta": eta,
        "vehicle_type": vehicleType?.toJson(),
        "stop_timer": stopTimer,
        "is_auto_cancel": isAutoCancel,
        "rebook_cancel": isRebookCancel,
        "cancel_initiator_id": cancelInitiatorId,
      };
}
