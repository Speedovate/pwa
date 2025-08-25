class LoadTransaction {
  int? id;
  double? amount;
  String? reason;
  String? ref;
  String? sessionId;
  int? walletId;
  String? paymentMethodId;
  String? status;
  int? isCredit;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? deletedAt;
  String? formattedDate;
  String? formattedUpdatedDate;
  String? photo;

  LoadTransaction({
    this.id,
    this.amount,
    this.reason,
    this.ref,
    this.sessionId,
    this.walletId,
    this.paymentMethodId,
    this.status,
    this.isCredit,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.formattedDate,
    this.formattedUpdatedDate,
    this.photo,
  });

  factory LoadTransaction.fromJson(Map<String, dynamic>? json) =>
      LoadTransaction(
        id: json?["id"] == null ? null : int.parse("${json?["id"]}"),
        amount:
            json?["amount"] == null ? null : double.parse("${json?["amount"]}"),
        reason: json?["reason"]?.toString(),
        ref: json?["ref"]?.toString(),
        sessionId: json?["session_id"]?.toString(),
        walletId: json?["wallet_id"] == null
            ? null
            : int.parse("${json?["wallet_id"]}"),
        paymentMethodId: json?["payment_method_id"]?.toString(),
        status: json?["status"]?.toString(),
        isCredit: json?["is_credit"] == null
            ? null
            : int.parse("${json?["is_credit"]}"),
        createdAt: json?["created_at"] == null
            ? null
            : DateTime.tryParse(json?["created_at"]),
        updatedAt: json?["updated_at"] == null
            ? null
            : DateTime.tryParse(json?["updated_at"]),
        deletedAt: json?["deleted_at"],
        formattedDate: json?["formatted_date"]?.toString(),
        formattedUpdatedDate: json?["formatted_updated_date"]?.toString(),
        photo: json?["photo"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "amount": amount,
        "reason": reason,
        "ref": ref,
        "session_id": sessionId,
        "wallet_id": walletId,
        "payment_method_id": paymentMethodId,
        "status": status,
        "is_credit": isCredit,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "deleted_at": deletedAt,
        "formatted_date": formattedDate,
        "formatted_updated_date": formattedUpdatedDate,
        "photo": photo,
      };
}
