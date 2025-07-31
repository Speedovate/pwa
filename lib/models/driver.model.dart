import "package:flutter/material.dart";
import "package:pwa/utils/functions.dart";
import "package:pwa/models/user.model.dart";
import "package:pwa/models/vehicle.model.dart";

class Driver extends User {
  Vehicle? vehicle;

  Driver({
    super.id,
    super.branchID,
    super.prevBranchID,
    super.actualBranchID,
    super.code,
    super.licenseNumber,
    super.franchiseNumber,
    super.name,
    super.email,
    super.phone,
    super.rawPhone,
    super.countryCode,
    super.photo,
    super.rating = 5.0,
    super.bookingServices,
    super.branchName,
    super.prevBranchName,
    super.walletAddress,
    super.cPhoto,
    super.idUrl,
    super.cancelCount,
    super.lat,
    super.lng,
    super.isTest,
    super.maxCancelCount,
    super.isVerified,
    super.isSuspended,
    super.isActive,
    this.vehicle,
    String? role,
  }) : super(
          role: role ?? "driver",
        );

  factory Driver.fromJson(Map<String, dynamic>? json) {
    try {
      debugPrint("Parsing Driver from JSON...");
      return Driver(
        id: parseInt(
          json?['id'],
          'id',
        ),
        branchID: parseInt(
          json?['branch_id'],
          'branch_id',
        ),
        prevBranchID: parseInt(
          json?['prev_branch_id'],
          'prev_branch_id',
        ),
        actualBranchID: parseInt(
          json?['actual_branch_id'],
          'actual_branch_id',
        ),
        code: parseString(
          json?['code'],
          'code',
        ),
        licenseNumber: parseString(json?["license_number"], "license_number"),
        franchiseNumber:
            parseString(json?["franchise_number"], "franchise_number"),
        name: parseString(
          json?['name'],
          'name',
        ),
        email: parseString(
          json?['email'],
          'email',
        ),
        phone: parseString(
          json?['phone'],
          'phone',
        ),
        rawPhone: parseString(
          json?['raw_phone'],
          'raw_phone',
        ),
        countryCode: parseString(
          json?['country_code'],
          'country_code',
        ),
        cPhoto: parseString(
          json?['customizable_photo'],
          'customizable_photo',
        ),
        photo: parseString(
          json?['photo'],
          'photo',
        ),
        role: parseString(
          json?['role_name'],
          'role_name',
        ),
        rating: parseDouble(
          json?['rating'],
          'rating',
        ),
        vehicle: json?['vehicle'] != null
            ? Vehicle.fromJson(json?['vehicle'])
            : null,
        lat: parseDouble(
          json?['lat'],
          'lat',
        ),
        lng: parseDouble(
          json?['lng'],
          'lng',
        ),
        bookingServices: json?['booking_services'] == null
            ? []
            : List<String>.from(
                json?['booking_services']
                    .map((x) => parseString(x, 'booking_service')!),
              ),
        branchName: parseString(
          json?['branch_name'],
          'branch_name',
        ),
        prevBranchName: parseString(
          json?['prev_branch_name'],
          'prev_branch_name',
        ),
        walletAddress: parseString(
          json?['wallet_address'],
          'wallet_address',
        ),
        cancelCount: parseInt(
          json?['cancel_count'],
          'cancel_count',
        ),
        isTest: parseBool(
          json?['is_test'],
          'is_test',
        ),
        maxCancelCount: parseInt(
          json?['max_cancel_count'],
          'max_cancel_count',
        ),
        isVerified: parseBool(
          json?['is_verified'],
          'is_verified',
        ),
        isSuspended: parseBool(
          json?['is_suspended'],
          'is_suspended',
        ),
        isActive: parseBool(
          json?['is_active'],
          'is_active',
        ),
      );
    } catch (e) {
      debugPrint("Error parsing Driver: $e");
      debugPrint("Driver JSON: $json");
      return Driver();
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        "rating": rating,
        "vehicle": vehicle?.toJson(),
      };
}
