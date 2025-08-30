import "package:pwa/models/driver.model.dart";
import "package:pwa/utils/data.dart";
import "package:pwa/utils/functions.dart";
import "package:flutter/material.dart";

class AvailableDriver {
  double? kmDistance;
  double? pickupDropoffSubtotal;
  double? pickupChargeFee;
  double? pickupExceedKm;
  double? pickupKm;
  double? pickupPerExceedKm;
  double? total;
  String? eta;
  Driver? driver;

  AvailableDriver({
    this.kmDistance,
    this.pickupDropoffSubtotal,
    this.pickupChargeFee,
    this.pickupExceedKm,
    this.pickupKm,
    this.pickupPerExceedKm,
    this.total,
    this.eta,
    this.driver,
  });

  factory AvailableDriver.fromJson(Map<String, dynamic>? json) {
    try {
      if (showParseText) {
        debugPrint("Parsing AvailableDriver from JSON...");
      }
      return AvailableDriver(
        kmDistance: parseDouble(
          json?["km_distance"],
          "km_distance",
        ),
        pickupDropoffSubtotal: parseDouble(
          json?["pickup_dropoff_subtotal"],
          "pickup_dropoff_subtotal",
        ),
        pickupChargeFee: parseDouble(
          json?["pickup_charge_fee"],
          "pickup_charge_fee",
        ),
        pickupExceedKm: parseDouble(
          json?["pickup_exceed_km"],
          "pickup_exceed_km",
        ),
        pickupKm: parseDouble(
          json?["pickup_km"],
          "pickup_km",
        ),
        pickupPerExceedKm: parseDouble(
          json?["pickup_per_exceed_km"],
          "pickup_per_exceed_km",
        ),
        total: parseDouble(
          json?["total"],
          "total",
        ),
        eta: parseString(
          json?["eta"],
          "eta",
        ),
        driver: json?["available_driver"]?["vehicle"]?["driver"] == null
            ? null
            : Driver.fromJson(json?["available_driver"]?["vehicle"]?["driver"]),
      );
    } catch (e) {
      if (showParseText) {
        debugPrint("Error parsing AvailableDriver: $e");
        debugPrint("AvailableDriver: $json");
      }
      return AvailableDriver();
    }
  }

  Map<String, dynamic> toJson() => {
        "km_distance": kmDistance,
        "pickup_dropoff_subtotal": pickupDropoffSubtotal,
        "pickup_charge_fee": pickupChargeFee,
        "pickup_exceed_km": pickupExceedKm,
        "pickup_km": pickupKm,
        "pickup_per_exceed_km": pickupPerExceedKm,
        "total": total,
        "eta": eta,
        "driver": driver?.toJson(),
      };
}
