import "dart:convert";
import "package:pwa/utils/data.dart";
import "package:pwa/utils/functions.dart";
import "package:pwa/models/user.model.dart";
import "package:pwa/models/driver.model.dart";
import "package:pwa/models/taxi_order.model.dart";
import 'package:pwa/utils/map_types.dart' as gmaps;

Order orderFromJson(String str) => Order.fromJson(json.decode(str));

String orderToJson(Order data) => json.encode(data.toJson());

class Order {
  int? id;
  int? userId;
  int? driverId;
  int? paymentMethodId;
  double? tip;
  double? total;
  double? discount;
  double? subTotal;
  double? markupAmount;
  bool? canRate;
  bool? canRateDriver;
  String? type;
  String? code;
  String? note;
  String? status;
  String? reason;
  String? formattedDate;
  String? paymentStatus;
  String? cancelledByWho;
  String? verificationCode;
  DateTime? createdAt;
  DateTime? updatedAt;
  User? user;
  Driver? driver;
  TaxiOrder? taxiOrder;
  List<OrderStatus> statuses;

  Order({
    this.id,
    this.userId,
    this.driverId,
    this.paymentMethodId,
    this.tip,
    this.total,
    this.discount,
    this.subTotal,
    this.markupAmount,
    this.canRate,
    this.canRateDriver,
    this.type,
    this.code,
    this.note,
    this.status,
    this.reason,
    this.formattedDate,
    this.paymentStatus,
    this.cancelledByWho,
    this.verificationCode,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.driver,
    this.taxiOrder,
    this.statuses = const [],
  });

  factory Order.fromJson(Map<String, dynamic>? json) {
    try {
      if (showParseText) {}
      return Order(
        id: parseInt(json?["id"], "id"),
        userId: parseInt(json?["user_id"], "user_id"),
        driverId: parseInt(json?["driver_id"], "driver_id"),
        paymentMethodId:
            parseInt(json?["payment_method_id"], "payment_method_id"),
        tip: parseDouble(json?["tip"], "tip"),
        total: parseDouble(json?["total"], "total"),
        discount: parseDouble(json?["discount"], "discount"),
        subTotal: parseDouble(json?["sub_total"], "sub_total"),
        markupAmount: parseDouble(json?["markup_amount"], "markup_amount"),
        canRate: parseBool(json?["can_rate"], "can_rate"),
        canRateDriver: parseBool(json?["can_rate_driver"], "can_rate_driver"),
        type: parseString(json?["type"], "type"),
        code: parseString(json?["code"], "code"),
        note: parseString(json?["note"], "note"),
        status: parseString(json?["status"], "status"),
        reason: parseString(json?["reason"], "reason"),
        formattedDate: parseString(json?["formatted_date"], "formatted_date"),
        paymentStatus: parseString(json?["payment_status"], "payment_status"),
        cancelledByWho:
            parseString(json?["cancelled_by_who"], "cancelled_by_who"),
        verificationCode:
            parseString(json?["verification_code"], "verification_code"),
        createdAt: parseDateTime(json?["created_at"], "created_at"),
        updatedAt: parseDateTime(json?["updated_at"], "updated_at"),
        user: json?["user"] == null ? null : User.fromJson(json?["user"]),
        driver:
            json?["driver"] == null ? null : Driver.fromJson(json?["driver"]),
        taxiOrder: json?["taxi_order"] == null
            ? null
            : TaxiOrder.fromJson(json?["taxi_order"]),
        statuses: json?["statuses"] is List
            ? (json?["statuses"] as List)
                .map((status) => OrderStatus.fromJson(status))
                .toList()
            : [],
      );
    } catch (e) {
      if (showParseText) {}
      return Order();
    }
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "user_id": userId,
        "driver_id": driverId,
        "payment_method_id": paymentMethodId,
        "tip": tip,
        "total": total,
        "discount": discount,
        "sub_total": subTotal,
        "markup_amount": markupAmount,
        "can_rate": canRate,
        "can_rate_driver": canRateDriver,
        "type": type,
        "code": code,
        "note": note,
        "status": status,
        "reason": reason,
        "formatted_date": formattedDate,
        "payment_status": paymentStatus,
        "cancelled_by_who": cancelledByWho,
        "verification_code": verificationCode,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "user": user?.toJson(),
        "driver": driver?.toJson(),
        "taxi_order": taxiOrder?.toJson(),
        "statuses": statuses.map((status) => status.toJson()).toList(),
      };

  bool get isCompleted =>
      ["delivered", "completed", "successful"].contains(status);

  bool get cancanRateDriver {
    return canRate == true &&
        driverId != null &&
        ["cancelled", "delivered"].contains(status);
  }

  bool get hasAssignedDriver {
    if (driver != null) {
      return true;
    }
    final normalizedDriverId = "${driverId ?? ""}".trim().toLowerCase();
    return normalizedDriverId.isNotEmpty && normalizedDriverId != "null";
  }

  double get resolvedMarkupAmount {
    return markupAmount ?? 0;
  }

  bool get appearsToBeProviderGuestFare {
    if (resolvedMarkupAmount > 0) {
      return true;
    }
    final totalValue = total ?? 0;
    final subTotalValue = subTotal ?? 0;
    if (totalValue <= 0 || subTotalValue <= 0) {
      return false;
    }
    return totalValue - subTotalValue > 20.0001;
  }

  bool get appearsToBeProviderStaffFare {
    if (resolvedMarkupAmount > 0) {
      return false;
    }
    final totalValue = total ?? 0;
    final subTotalValue = subTotal ?? 0;
    if (totalValue <= 0 || subTotalValue <= 0) {
      return false;
    }
    final delta = totalValue - subTotalValue;
    return delta.abs() <= 0.0001 || (delta - 20).abs() <= 0.0001;
  }

  gmaps.LatLng get driverLatLng => gmaps.LatLng(
        driver?.lat ?? 0.0,
        driver?.lng ?? 0.0,
      );
}

class OrderStatus {
  int? id;
  String? name;
  String? reason;
  String? modelType;
  int? modelId;
  DateTime? createdAt;
  DateTime? updatedAt;

  OrderStatus({
    this.id,
    this.name,
    this.reason,
    this.modelType,
    this.modelId,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderStatus.fromJson(Map<String, dynamic>? json) {
    try {
      return OrderStatus(
        id: parseInt(json?["id"], "id"),
        name: parseString(json?["name"], "name"),
        reason: parseString(json?["reason"], "reason"),
        modelType: parseString(json?["model_type"], "model_type"),
        modelId: parseInt(json?["model_id"], "model_id"),
        createdAt: parseDateTime(json?["created_at"], "created_at"),
        updatedAt: parseDateTime(json?["updated_at"], "updated_at"),
      );
    } catch (_) {
      return OrderStatus();
    }
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "reason": reason,
        "model_type": modelType,
        "model_id": modelId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}
