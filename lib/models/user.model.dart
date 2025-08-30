import "package:pwa/utils/data.dart";
import "package:flutter/material.dart";
import "package:pwa/utils/functions.dart";

class User {
  int? id;
  int? branchID;
  int? prevBranchID;
  int? actualBranchID;
  String? code;
  String? licenseNumber;
  String? franchiseNumber;
  String? name;
  String? email;
  String? phone;
  String? rawPhone;
  String? countryCode;
  String? photo;
  String? role;
  List<String>? bookingServices;
  String? branchName;
  String? prevBranchName;
  String? walletAddress;
  String? cPhoto;
  String? idUrl;
  int? cancelCount;
  double? lat;
  double? lng;
  double? rating;
  bool? isTest;
  int? maxCancelCount;
  bool? isVerified;
  bool isSuspended;
  bool isActive;
  bool isOnline;

  User({
    this.id,
    this.branchID,
    this.prevBranchID,
    this.actualBranchID,
    this.code,
    this.licenseNumber,
    this.franchiseNumber,
    this.name,
    this.email,
    this.phone,
    this.rawPhone,
    this.countryCode,
    this.photo,
    this.role,
    this.bookingServices,
    this.branchName,
    this.prevBranchName,
    this.walletAddress,
    this.cPhoto,
    this.idUrl,
    this.cancelCount,
    this.lat,
    this.lng,
    this.rating,
    this.isTest,
    this.maxCancelCount,
    this.isVerified,
    this.isSuspended = false,
    this.isActive = true,
    this.isOnline = false,
  });

  factory User.fromJson(Map<String, dynamic>? json) {
    try {
      if (showParseText) {
        debugPrint("Parsing User from JSON...");
      }
      return User(
        id: parseInt(
          json?["id"],
          "id",
        ),
        branchID: parseInt(
          json?["branch_id"] ?? json?["curr_area_id"],
          "curr_area_id",
        ),
        prevBranchID: parseInt(
          json?["prev_branch_id"] ?? json?["last_area_id"],
          "last_area_id",
        ),
        actualBranchID: parseInt(
          json?["actual_branch_id"] ?? json?["real_area_id"],
          "real_area_id",
        ),
        code: parseString(
          json?["code"] ?? json?["referral_code"],
          "referral_code",
        ),
        licenseNumber: parseString(
          json?["license_number"] ?? json?["d_license_number"],
          "d_license_number",
        ),
        franchiseNumber: parseString(
          json?["franchise_number"],
          "franchise_number",
        ),
        name: parseString(
          json?["name"],
          "name",
        ),
        email: parseString(
          json?["email"],
          "email",
        ),
        phone: parseString(
          json?["phone"] ?? json?["plus_phone"],
          "plus_phone",
        ),
        rawPhone: parseString(
          json?["raw_phone"] ?? json?["zero_phone"],
          "zero_phone",
        ),
        walletAddress: parseString(
          json?["wallet_address"] ?? json?["load_address"],
          "load_address",
        ),
        countryCode: parseString(
          json?["country_code"] ?? json?["area_code"],
          "area_code",
        ),
        photo: parseString(
          json?["photo"] ?? json?["real_photo"],
          "real_photo",
        ),
        role: parseString(
          json?["role"],
          "role",
        ),
        bookingServices: parseList<String>(
          json?["booking_services"] ?? json?["features"],
          "features",
          transform: (x) => x.toString(),
        ),
        branchName: parseString(
          json?["branch_name"] ?? json?["curr_area_name"],
          "curr_area_name",
        ),
        prevBranchName: parseString(
          json?["prev_branch_name"] ?? json?["last_area_name"],
          "last_area_name",
        ),
        cPhoto: parseString(
          json?["customizable_photo"] ?? json?["custom_photo"],
          "custom_photo",
        ),
        idUrl: parseString(
          json?["id_url"] ?? json?["id_photo"],
          "id_photo",
        ),
        cancelCount: parseInt(
          json?["cancel_count"] ?? json?["cancellations"],
          "cancellations",
        ),
        lat: parseDouble(
          json?["lat"],
          "lat",
        ),
        lng: parseDouble(
          json?["lng"],
          "lng",
        ),
        rating: parseDouble(
          json?["rating"],
          "rating",
        ),
        isTest: parseBool(
          json?["is_test"] ?? json?["is_dev"],
          "is_dev",
        ),
        maxCancelCount: parseInt(
          json?["max_cancel_count"] ?? json?["cancellation_limit"],
          "cancellation_limit",
        ),
        isVerified: parseBool(
          json?["is_verified"] ?? json?["is_kyc"],
          "is_kyc",
        ),
        isSuspended: parseBool(
          json?["is_suspended"] ?? json?["is_sus"],
          "is_sus",
        ),
        isActive: parseBool(
          json?["is_active"] ?? json?["is_act"],
          "is_act",
        ),
        isOnline: parseBool(
          json?["is_online"] ?? json?["is_onl"],
          "is_onl",
        ),
      );
    } catch (e) {
      if (showParseText) {
        debugPrint("Error parsing User: $e");
        debugPrint("User: $json");
      }
      return User();
    }
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "branch_id": branchID,
        "curr_area_id": branchID,
        "last_area_id": prevBranchID,
        "real_area_id": actualBranchID,
        "prev_branch_id": prevBranchID,
        "actual_branch_id": actualBranchID,
        "code": code,
        "referral_code": code,
        "license_number": licenseNumber,
        "d_license_number": licenseNumber,
        "franchise_number": franchiseNumber,
        "name": name,
        "email": email,
        "phone": phone,
        "plus_phone": phone,
        "raw_phone": rawPhone,
        "zero_phone": rawPhone,
        "area_code": countryCode,
        "country_code": countryCode,
        "photo": photo,
        "real_photo": photo,
        "role": role,
        "features": bookingServices,
        "booking_services": bookingServices,
        "branch_name": branchName,
        "curr_area_name": branchName,
        "last_area_name": prevBranchName,
        "prev_branch_name": prevBranchName,
        "load_address": walletAddress,
        "wallet_address": walletAddress,
        "custom_photo": cPhoto,
        "customizable_photo": cPhoto,
        "id_url": idUrl,
        "id_photo": idUrl,
        "cancel_count": cancelCount,
        "cancellations": cancelCount,
        "lat": lat,
        "lng": lng,
        "rating": rating,
        "is_dev": isBool(isTest),
        "is_test": isBool(isTest),
        "max_cancel_count": maxCancelCount,
        "cancellation_limit": maxCancelCount,
        "is_kyc": isBool(isVerified),
        "is_verified": isBool(isVerified),
        "is_sus": isBool(isSuspended),
        "is_suspended": isBool(isSuspended),
        "is_act": isBool(isActive),
        "is_active": isBool(isActive),
        "is_onl": isBool(isOnline),
        "is_online": isBool(isOnline),
      };
}
