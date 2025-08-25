import 'package:pwa/utils/functions.dart';

class Load {
  double? balance;
  DateTime? updatedAt;

  Load({
    this.balance,
    this.updatedAt,
  });

  factory Load.fromJson(Map<String, dynamic>? json) => Load(
        balance: parseDouble(json?["bal"], "bal"),
        updatedAt: parseDateTime(json?["u_date"], "u_date"),
      );

  Map<String, dynamic> toJson() => {
        "bal": balance ?? 0.0,
        "u_date": updatedAt?.toIso8601String(),
      };
}
