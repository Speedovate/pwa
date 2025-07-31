import 'package:pwa/utils/functions.dart';

class Wallet {
  double? balance;
  DateTime? updatedAt;

  Wallet({
    this.balance,
    this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic>? json) => Wallet(
        balance: parseDouble(json?["bal"], "bal"),
        updatedAt: parseDateTime(json?["u_date"], "u_date"),
      );

  Map<String, dynamic> toJson() => {
        "bal": balance ?? 0.0,
        "u_date": updatedAt?.toIso8601String(),
      };
}
