import "dart:convert";

import "package:pwa/utils/functions.dart";

Coupon couponFromJson(String str) => Coupon.fromJson(json.decode(str));

String couponToJson(Coupon data) => json.encode(data.toJson());

class Coupon {
  final int? id;
  final int? vendorTypeId;
  final String? code;
  final String? description;
  final double? discount;
  final double? minOrderAmount;
  final double? maxCouponAmount;
  final int? percentage;
  final DateTime? expiresOn;
  final dynamic times;
  final int? useLeft;
  final bool? expired;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? formattedExpiresOn;

  const Coupon({
    this.id,
    this.vendorTypeId,
    this.code,
    this.description,
    this.discount,
    this.minOrderAmount,
    this.maxCouponAmount,
    this.percentage,
    this.expiresOn,
    this.times,
    this.useLeft,
    this.expired,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.formattedExpiresOn,
  });

  factory Coupon.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Coupon();

    return Coupon(
      id: parseInt(json["id"], "id"),
      vendorTypeId: parseInt(json["vendor_type_id"], "vendor_type_id"),
      code: parseString(json["code"], "code"),
      description: parseString(json["description"], "description"),
      discount: parseDouble(json["discount"], "discount"),
      minOrderAmount: parseDouble(json["min_order_amount"], "min_order_amount"),
      maxCouponAmount:
          parseDouble(json["max_coupon_amount"], "max_coupon_amount"),
      percentage: parseInt(json["percentage"], "percentage"),
      expiresOn: parseDateTime(json["expires_on"], "expires_on"),
      times: json["times"],
      expired: parseBool(json["expired"], "expired"),
      useLeft: parseInt(json["use_left"], "use_left"),
      isActive: parseBool(json["is_active"], "is_active"),
      createdAt: parseDateTime(json["created_at"], "created_at"),
      updatedAt: parseDateTime(json["updated_at"], "updated_at"),
      formattedExpiresOn:
          parseString(json["formatted_expires_on"], "formatted_expires_on"),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "vendor_type_id": vendorTypeId,
        "code": code,
        "description": description,
        "discount": discount,
        "min_order_amount": minOrderAmount,
        "max_coupon_amount": maxCouponAmount,
        "percentage": percentage,
        "expires_on": expiresOn?.toIso8601String(),
        "times": times,
        "expired": expired,
        "use_left": useLeft,
        "is_active": isActive,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "formatted_expires_on": formattedExpiresOn,
      };

  bool get isExpired =>
      expired == true ||
      (expiresOn != null && DateTime.now().isAfter(expiresOn!));

  bool get isValid =>
      isActive == true && useLeft != null && useLeft! > 0 && !isExpired;

  bool get usesPercentageDiscount => (percentage ?? 0) > 0;

  double get discountValue => discount ?? 0;

  double validateDiscount(double amount, double discountAmount) {
    if (minOrderAmount != null && amount < minOrderAmount!) {
      throw "Order amount is less than coupon minimum allowed order";
    }

    if (maxCouponAmount != null && discountAmount > maxCouponAmount!) {
      return maxCouponAmount!;
    }

    return discountAmount;
  }
}
