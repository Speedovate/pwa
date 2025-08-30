import "package:pwa/utils/data.dart";
import "package:flutter/material.dart";
import "package:pwa/utils/functions.dart";

class VehicleType {
  int? id;
  int? zoneId;
  String? name;
  String? mode;
  String? slug;
  double? baseFare;
  double? baseDistance;
  double? distanceFare;
  double? pickupFare;
  double? timeFare;
  double? minFare;
  double? total;
  double? kmDistance;
  bool? isActive;
  bool? isNew;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? formattedDate;
  String? photo;
  String? encrypted;
  double? pickupKmLimit;
  int? maxSeat;
  bool? isP2P;
  int? p2pID;
  String? p2pDetectedIn;
  double? prevTotal;

  VehicleType({
    this.id,
    this.zoneId,
    this.name,
    this.mode,
    this.slug,
    this.baseFare,
    this.baseDistance,
    this.distanceFare,
    this.pickupFare,
    this.timeFare,
    this.minFare,
    this.total,
    this.kmDistance,
    this.isActive,
    this.isNew,
    this.createdAt,
    this.updatedAt,
    this.formattedDate,
    this.photo,
    this.encrypted,
    this.pickupKmLimit,
    this.maxSeat,
    this.isP2P,
    this.p2pID,
    this.p2pDetectedIn,
    this.prevTotal,
  });

  factory VehicleType.fromJson(Map<String, dynamic>? json) {
    try {
      if (showParseText) {
        debugPrint("Parsing VehicleType from JSON...");
      }
      return VehicleType(
        id: parseInt(json?["id"], "id"),
        zoneId: parseInt(json?["zone_id"], "zone_id"),
        name: parseString(json?["name"], "name"),
        mode: parseString(json?["mode"], "mode"),
        slug: parseString(json?["slug"], "slug"),
        baseFare: parseDouble(json?["base_fare"], "base_fare"),
        baseDistance: parseDouble(json?["base_km_limit"], "base_km_limit"),
        distanceFare: parseDouble(json?["distance_fare"], "distance_fare"),
        pickupFare: parseDouble(json?["pickup_km_rate"], "pickup_km_rate"),
        timeFare: parseDouble(json?["time_fare"], "time_fare"),
        minFare: parseDouble(json?["min_fare"], "min_fare"),
        total: parseDouble(json?["total"], "total"),
        kmDistance: parseDouble(json?["km_distance"], "km_distance"),
        isActive: parseBool(json?["is_active"], "is_active"),
        isNew: parseBool(json?["is_new"], "is_new"),
        createdAt: parseDateTime(json?["created_at"], "created_at"),
        updatedAt: parseDateTime(json?["updated_at"], "updated_at"),
        formattedDate: parseString(json?["formatted_date"], "formatted_date"),
        photo: parseString(json?["photo"], "photo"),
        encrypted: parseString(json?["encrypted"], "encrypted"),
        pickupKmLimit: parseDouble(json?["pickup_km_limit"], "pickup_km_limit"),
        maxSeat: parseInt(json?["max_seat"], "max_seat"),
        isP2P: parseBool(json?["is_p2p"], "is_p2p"),
        p2pID: parseInt(json?["p2p_id"], "p2p_id"),
        p2pDetectedIn: parseString(json?["p2p_detected_in"], "p2p_detected_in"),
        prevTotal: parseDouble(json?["prev_total"], "prev_total"),
      );
    } catch (e) {
      if (showParseText) {
        debugPrint("Error parsing VehicleType: $e");
        debugPrint("VehicleType JSON: $json");
      }
      return VehicleType();
    }
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "zone_id": zoneId,
        "name": name,
        "mode": mode,
        "slug": slug,
        "base_fare": baseFare,
        "base_km_limit": baseDistance,
        "distance_fare": distanceFare,
        "pickup_km_rate": pickupFare,
        "time_fare": timeFare,
        "min_fare": minFare,
        "total": total,
        "km_distance": kmDistance,
        "is_active": isActive,
        "is_new": isNew,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "formatted_date": formattedDate,
        "photo": photo,
        "encrypted": encrypted,
        "pickup_km_limit": pickupKmLimit,
        "max_seat": maxSeat,
        "is_p2p": isP2P,
        "p2p_id": p2pID,
        "p2p_detected_in": p2pDetectedIn,
        "prev_total": prevTotal,
      };
}
