// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/text_field.widget.dart';

class PartnerPanelView extends StatefulWidget {
  const PartnerPanelView({super.key});

  @override
  State<PartnerPanelView> createState() => _PartnerPanelViewState();
}

class _PartnerPanelViewState extends State<PartnerPanelView> {
  static const double _panelRadius = 8;
  static const double _panelGap = 12;
  static const double _panelOuterGap = 16;
  static const double _panelInset = 14;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: "en_PH",
    symbol: "P ",
    decimalDigits: 0,
  );
  final TextEditingController _userIdTEC = TextEditingController();
  final TextEditingController _markupTEC = TextEditingController();
  final TextEditingController _partnerListSearchTEC = TextEditingController();
  final TextEditingController _driverListSearchTEC = TextEditingController();
  Timer? _quickPartnerSearchDebounce;
  bool _isSavingQuickSettings = false;
  bool _isSearchingQuickPartner = false;
  Map<String, dynamic>? _quickPartnerUserData;
  String? _quickPartnerUserId;
  String _quickPaymentMode = "load";
  List<Map<String, dynamic>> _quickPartnerSearchResults = [];
  String _selectedSection = "partners";
  final Map<String, Map<String, dynamic>?> _partnerUserCache = {};
  final Set<String> _loadingPartnerUserIds = {};
  final Set<String> _expandedPartnerIds = {};
  final Set<String> _expandedDriverIds = {};

  @override
  void dispose() {
    _quickPartnerSearchDebounce?.cancel();
    _userIdTEC.dispose();
    _markupTEC.dispose();
    _partnerListSearchTEC.dispose();
    _driverListSearchTEC.dispose();
    super.dispose();
  }

  bool _hasPanelAccess(List<dynamic> allowedUserIds) {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      return false;
    }
    final currentUserId = "$userId";
    return allowedUserIds.any(
      (id) => "$id" == currentUserId,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse("$value") ?? 0;
  }

  String _formatMoney(dynamic value) {
    return _currencyFormatter.format(
      _toDouble(value),
    );
  }

  String _monthKeyNow() {
    return DateFormat(
      "yyyy-MM",
    ).format(
      DateTime.now(),
    );
  }

  Timestamp _timestampNow() {
    return Timestamp.now();
  }

  Map<String, double> _toDoubleMap(dynamic value) {
    if (value is! Map) {
      return {};
    }
    return value.map(
      (key, item) => MapEntry(
        "$key",
        _toDouble(item),
      ),
    );
  }

  Map<String, dynamic> _increaseMapValue(
    Map<String, double> source,
    String key,
    double amount,
  ) {
    final next = Map<String, double>.from(source);
    next[key] = (next[key] ?? 0) + amount;
    return next;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocsByUpdatedAt(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aTs = a.data()["updated_at"];
      final bTs = b.data()["updated_at"];
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      return 0;
    });
    return sorted;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocsByCreatedAt(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aTs = a.data()["created_at"];
      final bTs = b.data()["created_at"];
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      return 0;
    });
    return sorted;
  }

  Map<String, dynamic> _defaultPartnerAggregate({
    required String partnerId,
    String partnerName = "",
    dynamic updatedAt,
  }) {
    return {
      "partner_id": partnerId,
      "partner_name": partnerName,
      "today_amount": 0,
      "month_amount": 0,
      "total_amount": 0,
      "monthly_markup_history": {},
      "claimable_cash_markup_amount": 0,
      "claimable_cash_markup_month_amount": 0,
      "monthly_cash_markup_history": {},
      "claimed_cash_markup_amount": 0,
      "monthly_claimed_cash_markup_history": {},
      if (updatedAt != null) "updated_at": updatedAt,
    };
  }

  List<Map<String, dynamic>> _buildPartnerEntries({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> partnerDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> transactionDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> userSettingDocs,
  }) {
    final entries = <String, Map<String, dynamic>>{};

    for (final doc in partnerDocs) {
      final partnerData = Map<String, dynamic>.from(doc.data());
      final partnerId = "${partnerData["partner_id"] ?? doc.id}".trim();
      if (partnerId.isEmpty) {
        continue;
      }
      entries[partnerId] = {
        "partnerId": partnerId,
        "partnerData": {
          ..._defaultPartnerAggregate(
            partnerId: partnerId,
            partnerName: "${partnerData["partner_name"] ?? ""}",
            updatedAt: partnerData["updated_at"] ?? partnerData["created_at"],
          ),
          ...partnerData,
          "partner_id": partnerId,
        },
        "userData": null,
      };
    }

    for (final doc in transactionDocs) {
      final transactionData = doc.data();
      final partnerId =
          "${doc.reference.parent.parent?.id ?? transactionData["user_id"] ?? ""}"
              .trim();
      if (partnerId.isEmpty) {
        continue;
      }
      entries.putIfAbsent(
        partnerId,
        () => {
          "partnerId": partnerId,
          "partnerData": _defaultPartnerAggregate(
            partnerId: partnerId,
            partnerName: "${transactionData["partner_name"] ?? ""}",
            updatedAt: transactionData["created_at"],
          ),
          "userData": null,
        },
      );
      final currentPartnerData =
          Map<String, dynamic>.from(entries[partnerId]!["partnerData"] ?? {});
      if ("${currentPartnerData["partner_name"] ?? ""}".trim().isEmpty) {
        currentPartnerData["partner_name"] =
            "${transactionData["partner_name"] ?? ""}";
      }
      currentPartnerData["partner_id"] = partnerId;
      currentPartnerData["updated_at"] ??= transactionData["created_at"];
      entries[partnerId]!["partnerData"] = currentPartnerData;
    }

    for (final doc in userSettingDocs) {
      final userData = doc.data();
      final partnerId = doc.id.trim();
      if (partnerId.isEmpty) {
        continue;
      }
      final partnerName =
          "${userData["partner_name"] ?? userData["name"] ?? ""}".trim();
      entries.putIfAbsent(
        partnerId,
        () => {
          "partnerId": partnerId,
          "partnerData": _defaultPartnerAggregate(
            partnerId: partnerId,
            partnerName: partnerName,
            updatedAt: userData["updated_at"],
          ),
          "userData": null,
        },
      );
      final currentPartnerData =
          Map<String, dynamic>.from(entries[partnerId]!["partnerData"] ?? {});
      if ("${currentPartnerData["partner_name"] ?? ""}".trim().isEmpty) {
        currentPartnerData["partner_name"] = partnerName;
      }
      currentPartnerData["partner_id"] = partnerId;
      currentPartnerData["updated_at"] ??= userData["updated_at"];
      entries[partnerId]!["partnerData"] = currentPartnerData;
      entries[partnerId]!["userData"] = {
        ...?entries[partnerId]!["userData"] as Map<String, dynamic>?,
        ...userData,
      };
    }

    final merged = entries.values.toList();
    merged.sort((a, b) {
      final aData = a["partnerData"] as Map<String, dynamic>? ?? {};
      final bData = b["partnerData"] as Map<String, dynamic>? ?? {};
      final claimableDiff = _toDouble(
        bData["claimable_cash_markup_amount"],
      ).compareTo(
        _toDouble(aData["claimable_cash_markup_amount"]),
      );
      if (claimableDiff != 0) {
        return claimableDiff;
      }
      final aTs = aData["updated_at"];
      final bTs = bData["updated_at"];
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      if (aTs is Timestamp) {
        return -1;
      }
      if (bTs is Timestamp) {
        return 1;
      }
      return ("${a["partnerId"]}").compareTo("${b["partnerId"]}");
    });
    return merged;
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      return DateFormat(
        "MMM d, yyyy h:mm a",
      ).format(
        value.toDate(),
      );
    }
    return "-";
  }

  String _formatMonthLabel(String key) {
    try {
      return DateFormat(
        "MMM yyyy",
      ).format(
        DateFormat(
          "yyyy-MM",
        ).parse(key),
      );
    } catch (_) {
      return key;
    }
  }

  String _partnerDisplayName({
    required String partnerId,
    Map<String, dynamic>? partnerData,
    Map<String, dynamic>? userData,
  }) {
    final rawName =
        "${partnerData?["partner_name"] ?? userData?["name"] ?? userData?["partner_name"] ?? ""}"
            .trim();
    if (rawName.isEmpty || rawName.toLowerCase() == "null") {
      return "Unnamed Partner ($partnerId)";
    }
    return capitalizeWords(rawName);
  }

  Future<void> _ensurePartnerUsersLoaded(List<String> userIds) async {
    final missingIds = userIds.where((id) {
      return !_partnerUserCache.containsKey(id) &&
          !_loadingPartnerUserIds.contains(id);
    }).toList();
    if (missingIds.isEmpty) {
      return;
    }
    setState(() {
      _loadingPartnerUserIds.addAll(missingIds);
    });
    try {
      final futures = missingIds.map(
        (id) => fbStore.collection("users").doc(id).get(),
      );
      final snapshots = await Future.wait(futures);
      if (!mounted) {
        return;
      }
      setState(() {
        for (var i = 0; i < missingIds.length; i++) {
          _partnerUserCache[missingIds[i]] = snapshots[i].data();
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingPartnerUserIds.removeAll(missingIds);
        });
      }
    }
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade600,
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade600,
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  bool _isNarrowScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 390;
  }

  InputDecoration _dropdownDecoration({
    required String label,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF030744),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0xFF030744),
        ),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0xFF007BFF),
        ),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Future<void> _savePartnerSettings({
    required String userId,
    required double markupAmount,
    required String paymentMode,
  }) async {
    final trimmedId = userId.trim();
    if (trimmedId.isEmpty) {
      throw "Enter a user ID.";
    }
    final userRef = fbStore.collection("users").doc(trimmedId);
    final userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
      throw "User ID not found.";
    }
    final userData = userSnapshot.data() ?? {};
    final partnerRef = fbStore.collection("partners").doc(trimmedId);
    final partnerSnapshot = await partnerRef.get();
    final timestamp = _timestampNow();
    final normalizedPaymentMode =
        paymentMode.toLowerCase() == "cash" ? "cash" : "load";
    final rawPartnerName =
        "${userData["name"] ?? userData["partner_name"] ?? ""}".trim();
    final partnerName =
        rawPartnerName.isEmpty || rawPartnerName.toLowerCase() == "null"
            ? null
            : capitalizeWords(rawPartnerName, alt: rawPartnerName);

    final batch = fbStore.batch();
    batch.set(
      userRef,
      {
        "markup_amount": markupAmount,
        "payment_mode": normalizedPaymentMode,
        "partner_name": partnerName,
        "updated_at": timestamp,
      },
      SetOptions(
        merge: true,
      ),
    );

    if (partnerSnapshot.exists) {
      batch.set(
        partnerRef,
        {
          "partner_id": trimmedId,
          "partner_name": partnerName,
          "markup_amount": markupAmount,
          "payment_mode": normalizedPaymentMode,
          "updated_at": timestamp,
          if ((partnerSnapshot.data()?["created_at"]) == null)
            "created_at": timestamp,
        },
        SetOptions(
          merge: true,
        ),
      );
    } else {
      batch.set(
        partnerRef,
        {
          "partner_id": trimmedId,
          "partner_name": partnerName,
          "markup_amount": markupAmount,
          "payment_mode": normalizedPaymentMode,
          "today_amount": 0,
          "month_amount": 0,
          "total_amount": 0,
          "monthly_markup_history": {},
          "claimable_cash_markup_amount": 0,
          "claimable_cash_markup_month_amount": 0,
          "monthly_cash_markup_history": {},
          "claimed_cash_markup_amount": 0,
          "created_at": timestamp,
          "updated_at": timestamp,
        },
        SetOptions(
          merge: true,
        ),
      );
    }

    await batch.commit();
    _partnerUserCache[trimmedId] = {
      ...userData,
      "markup_amount": markupAmount,
      "payment_mode": normalizedPaymentMode,
      "partner_name": partnerName,
      "name": userData["name"],
      "updated_at": timestamp,
    };
    _loadingPartnerUserIds.remove(trimmedId);
  }

  Future<void> _saveQuickSettings() async {
    if (_isSavingQuickSettings) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final markupAmount = _toDouble(_markupTEC.text.trim());
    setState(() {
      _isSavingQuickSettings = true;
    });
    try {
      await _savePartnerSettings(
        userId: _userIdTEC.text,
        markupAmount: markupAmount,
        paymentMode: _quickPaymentMode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _quickPartnerUserData = {
          ...?_quickPartnerUserData,
          "markup_amount": markupAmount,
          "payment_mode": _quickPaymentMode,
          "partner_name":
              "${_quickPartnerUserData?["name"] ?? _quickPartnerUserData?["partner_name"] ?? ""}"
                      .trim()
                      .isEmpty
                  ? null
                  : capitalizeWords(
                      "${_quickPartnerUserData?["name"] ?? _quickPartnerUserData?["partner_name"] ?? ""}",
                    ),
        };
      });
      _showSuccessSnack("Partner settings updated.");
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showErrorSnack("$e");
    } finally {
      if (mounted) {
        setState(() {
          _isSavingQuickSettings = false;
        });
      }
    }
  }

  void _queueQuickPartnerSearch(String value) {
    _quickPartnerSearchDebounce?.cancel();
    _quickPartnerSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        _searchQuickPartners(value);
      },
    );
  }

  Future<void> _searchQuickPartners(String value) async {
    final keyword = value.trim();
    if (keyword.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearchingQuickPartner = false;
        _quickPartnerSearchResults = [];
      });
      return;
    }
    setState(() {
      _isSearchingQuickPartner = true;
    });
    try {
      final trimmedKeyword = keyword.trim();
      final seenIds = <String>{};
      final results = <Map<String, dynamic>>[];
      final lowerKeyword = trimmedKeyword.toLowerCase();

      final idSnapshot =
          await fbStore.collection("users").doc(trimmedKeyword).get();
      if (idSnapshot.exists) {
        final data = idSnapshot.data() ?? {};
        seenIds.add(idSnapshot.id);
        results.add(
          {
            "id": idSnapshot.id,
            ...data,
          },
        );
      }

      final idPrefixSnapshot = await fbStore
          .collection("users")
          .orderBy(FieldPath.documentId)
          .startAt([trimmedKeyword])
          .endAt(["$trimmedKeyword\uf8ff"])
          .limit(8)
          .get();
      for (final doc in idPrefixSnapshot.docs) {
        if (seenIds.contains(doc.id)) {
          continue;
        }
        seenIds.add(doc.id);
        results.add(
          {
            "id": doc.id,
            ...doc.data(),
          },
        );
      }

      final namePrefixes = <String>{
        trimmedKeyword,
        capitalizeWords(trimmedKeyword, alt: trimmedKeyword),
        titleCase(trimmedKeyword),
      }.where((value) => value.trim().isNotEmpty).toList();

      for (final prefix in namePrefixes) {
        final nameSnapshot = await fbStore
            .collection("users")
            .orderBy("name")
            .startAt([prefix])
            .endAt(["$prefix\uf8ff"])
            .limit(8)
            .get();
        for (final doc in nameSnapshot.docs) {
          if (seenIds.contains(doc.id)) {
            continue;
          }
          seenIds.add(doc.id);
          results.add(
            {
              "id": doc.id,
              ...doc.data(),
            },
          );
        }
      }

      final broadNameSnapshot =
          await fbStore.collection("users").orderBy("name").limit(50).get();
      for (final doc in broadNameSnapshot.docs) {
        if (seenIds.contains(doc.id)) {
          continue;
        }
        final data = doc.data();
        final candidateName = "${data["name"] ?? ""}".toLowerCase();
        final candidateId = doc.id.toLowerCase();
        if (candidateName.contains(lowerKeyword) ||
            candidateId.contains(lowerKeyword)) {
          seenIds.add(doc.id);
          results.add(
            {
              "id": doc.id,
              ...data,
            },
          );
        }
      }

      results.sort((a, b) {
        final aId = "${a["id"] ?? ""}".toLowerCase();
        final bId = "${b["id"] ?? ""}".toLowerCase();
        final aName = "${a["name"] ?? ""}".toLowerCase();
        final bName = "${b["name"] ?? ""}".toLowerCase();

        int score(String id, String name) {
          if (id == lowerKeyword || name == lowerKeyword) return 0;
          if (id.startsWith(lowerKeyword) || name.startsWith(lowerKeyword)) {
            return 1;
          }
          if (id.contains(lowerKeyword) || name.contains(lowerKeyword)) {
            return 2;
          }
          return 3;
        }

        final scoreDiff = score(aId, aName).compareTo(score(bId, bName));
        if (scoreDiff != 0) {
          return scoreDiff;
        }
        return aName.compareTo(bName);
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _quickPartnerSearchResults = results.take(12).toList();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showErrorSnack("$e");
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingQuickPartner = false;
        });
      }
    }
  }

  String titleCase(String value) {
    return value
        .split(" ")
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) => part[0].toUpperCase() + part.substring(1).toLowerCase(),
        )
        .join(" ");
  }

  void _selectQuickPartner(Map<String, dynamic> userData) {
    final userId = "${userData["id"] ?? ""}".trim();
    if (userId.isEmpty) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _quickPartnerUserId = userId;
      _quickPartnerUserData = userData;
      _userIdTEC.text = userId;
      _markupTEC.text = "${_toDouble(userData["markup_amount"])}";
      _quickPaymentMode =
          "${userData["payment_mode"] ?? "load"}".toLowerCase() == "cash"
              ? "cash"
              : "load";
      _quickPartnerSearchResults = [];
    });
  }

  Future<void> _showEditPartnerDialog({
    required String partnerId,
    required Map<String, dynamic>? userData,
  }) async {
    final markupTEC = TextEditingController(
      text: "${_toDouble(userData?["markup_amount"])}",
    );
    String paymentMode =
        "${userData?["payment_mode"] ?? "load"}".toLowerCase() == "cash"
            ? "cash"
            : "load";
    bool isSaving = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              title: const Text(
                "Edit Partner Settings",
                style: TextStyle(
                  color: Color(0xFF030744),
                ),
              ),
              content: SizedBox(
                width: min(
                  MediaQuery.of(context).size.width,
                  420,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFieldWidget(
                      controller: TextEditingController(
                        text: partnerId,
                      ),
                      labelText: "User ID",
                      readOnly: true,
                    ),
                    const SizedBox(height: _panelGap),
                    TextFieldWidget(
                      controller: markupTEC,
                      labelText: "Markup Amount",
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: _panelGap),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMode,
                      decoration: _dropdownDecoration(
                        label: "Payment Mode",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "cash",
                          child: Text("Cash"),
                        ),
                        DropdownMenuItem(
                          value: "load",
                          child: Text("Load"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setStateDialog(() {
                          paymentMode = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                  ),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setStateDialog(() {
                            isSaving = true;
                          });
                          try {
                            await _savePartnerSettings(
                              userId: partnerId,
                              markupAmount: _toDouble(markupTEC.text),
                              paymentMode: paymentMode,
                            );
                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                            _showSuccessSnack("Partner settings updated.");
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }
                            _showErrorSnack("$e");
                            setStateDialog(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(
                    isSaving ? "Saving..." : "Save",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    markupTEC.dispose();
  }

  Future<void> _recordPartnerClaim({
    required String partnerId,
    required Map<String, dynamic> partnerData,
    required double amount,
    String note = "",
  }) async {
    final currentClaimable = _toDouble(
      partnerData["claimable_cash_markup_amount"],
    );
    final currentClaimableMonth = _toDouble(
      partnerData["claimable_cash_markup_month_amount"],
    );
    if (amount <= 0) {
      throw "Enter a valid claim amount.";
    }
    if (amount > currentClaimable) {
      throw "Claim amount is greater than the current claimable total.";
    }

    final monthKey = _monthKeyNow();
    final claimedHistory = _toDoubleMap(
      partnerData["monthly_claimed_cash_markup_history"],
    );
    final partnerRef = fbStore.collection("partners").doc(partnerId);
    final userRef = fbStore.collection("users").doc(partnerId);
    final batch = fbStore.batch();
    final claimRef = partnerRef.collection("claimed_transactions").doc();

    batch.set(
      claimRef,
      {
        "amount": amount,
        "partner_id": partnerId,
        "partner_name":
            "${partnerData["partner_name"] ?? partnerData["name"] ?? ""}",
        "month_key": monthKey,
        "created_at": _timestampNow(),
        "note": note.trim(),
        "claimed_by_user_id": AuthService.currentUser?.id,
        "claimed_by_name": AuthService.currentUser?.name,
      },
    );
    batch.set(
      partnerRef,
      {
        "claimed_cash_markup_amount":
            _toDouble(partnerData["claimed_cash_markup_amount"]) + amount,
        "claimed_cash_markup_month_amount":
            _toDouble(partnerData["claimed_cash_markup_month_amount"]) + amount,
        "monthly_claimed_cash_markup_history": _increaseMapValue(
          claimedHistory,
          monthKey,
          amount,
        ),
        "claimable_cash_markup_amount": max(
          currentClaimable - amount,
          0,
        ),
        "claimable_cash_markup_month_amount": max(
          currentClaimableMonth - amount,
          0,
        ),
        "updated_at": _timestampNow(),
      },
      SetOptions(
        merge: true,
      ),
    );
    batch.set(
      userRef,
      {
        "claimable_cash_markup_amount": max(
          currentClaimable - amount,
          0,
        ),
        "claimable_cash_markup_month_amount": max(
          currentClaimableMonth - amount,
          0,
        ),
        "updated_at": _timestampNow(),
      },
      SetOptions(
        merge: true,
      ),
    );
    await batch.commit();
  }

  Future<void> _showPartnerClaimDialog({
    required String partnerId,
    required Map<String, dynamic> partnerData,
  }) async {
    final amountTEC = TextEditingController();
    final noteTEC = TextEditingController();
    bool isSaving = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              title: const Text(
                "Record Claimed Amount",
                style: TextStyle(
                  color: Color(0xFF030744),
                ),
              ),
              content: SizedBox(
                width: min(
                  MediaQuery.of(context).size.width,
                  420,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoLine(
                      "Claimable",
                      _formatMoney(
                        partnerData["claimable_cash_markup_amount"],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFieldWidget(
                      controller: amountTEC,
                      labelText: "Claimed Amount",
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFieldWidget(
                      controller: noteTEC,
                      labelText: "Note",
                      maxLines: 3,
                      minLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setStateDialog(() {
                            isSaving = true;
                          });
                          try {
                            await _recordPartnerClaim(
                              partnerId: partnerId,
                              partnerData: partnerData,
                              amount: _toDouble(amountTEC.text),
                              note: noteTEC.text,
                            );
                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                            _showSuccessSnack("Claim recorded.");
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }
                            _showErrorSnack("$e");
                            setStateDialog(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(
                    isSaving ? "Saving..." : "Save",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    amountTEC.dispose();
    noteTEC.dispose();
  }

  Future<void> _recordDriverDeduction({
    required String driverId,
    required Map<String, dynamic> driverData,
    required double amount,
    String note = "",
  }) async {
    final received = _toDouble(driverData["received_cash_markup_amount"]);
    final deducted = _toDouble(driverData["deducted_cash_markup_amount"]);
    final receivedMonth = _toDouble(
      driverData["received_cash_markup_month_amount"],
    );
    final deductedMonth = _toDouble(
      driverData["deducted_cash_markup_month_amount"],
    );
    final deductible = max(
      received - deducted,
      0,
    );
    if (amount <= 0) {
      throw "Enter a valid deducted amount.";
    }
    if (amount > deductible) {
      throw "Deducted amount is greater than the current deductible total.";
    }

    final monthKey = _monthKeyNow();
    final deductedHistory = _toDoubleMap(
      driverData["monthly_deducted_cash_markup_history"],
    );
    final driverRef = fbStore.collection("drivers").doc(driverId);
    final deductionRef =
        driverRef.collection("deducted_markup_transactions").doc();
    final batch = fbStore.batch();

    batch.set(
      deductionRef,
      {
        "amount": amount,
        "driver_id": driverId,
        "driver_name":
            "${driverData["driver_name"] ?? driverData["name"] ?? ""}",
        "month_key": monthKey,
        "created_at": _timestampNow(),
        "note": note.trim(),
        "deducted_by_user_id": AuthService.currentUser?.id,
        "deducted_by_name": AuthService.currentUser?.name,
      },
    );
    batch.set(
      driverRef,
      {
        "deducted_cash_markup_amount": deducted + amount,
        "deducted_cash_markup_month_amount": deductedMonth + amount,
        "monthly_deducted_cash_markup_history": _increaseMapValue(
          deductedHistory,
          monthKey,
          amount,
        ),
        "deductable_cash_markup_amount": max(
          received - (deducted + amount),
          0,
        ),
        "deductable_cash_markup_month_amount": max(
          receivedMonth - (deductedMonth + amount),
          0,
        ),
        "updated_at": _timestampNow(),
      },
      SetOptions(
        merge: true,
      ),
    );
    await batch.commit();
  }

  Future<void> _showDriverDeductionDialog({
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    final amountTEC = TextEditingController();
    final noteTEC = TextEditingController();
    bool isSaving = false;
    final deductible = max(
      _toDouble(driverData["received_cash_markup_amount"]) -
          _toDouble(driverData["deducted_cash_markup_amount"]),
      0,
    );
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              title: const Text(
                "Record Deducted Amount",
                style: TextStyle(
                  color: Color(0xFF030744),
                ),
              ),
              content: SizedBox(
                width: min(
                  MediaQuery.of(context).size.width,
                  420,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoLine(
                      "Deductible",
                      _formatMoney(deductible),
                    ),
                    const SizedBox(height: 14),
                    TextFieldWidget(
                      controller: amountTEC,
                      labelText: "Deducted Amount",
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFieldWidget(
                      controller: noteTEC,
                      labelText: "Note",
                      maxLines: 3,
                      minLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setStateDialog(() {
                            isSaving = true;
                          });
                          try {
                            await _recordDriverDeduction(
                              driverId: driverId,
                              driverData: driverData,
                              amount: _toDouble(amountTEC.text),
                              note: noteTEC.text,
                            );
                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                            _showSuccessSnack("Deduction recorded.");
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }
                            _showErrorSnack("$e");
                            setStateDialog(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(
                    isSaving ? "Saving..." : "Save",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    amountTEC.dispose();
    noteTEC.dispose();
  }

  Widget _buildInfoLine(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 280;
        return Flex(
          direction: isNarrow ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF030744),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isNarrow) const Spacer(),
            if (isNarrow) const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF007BFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6D7890),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF030744),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onTap,
    Color color = const Color(0xFF007BFF),
  }) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: WidgetButton(
        onTap: onTap,
        borderRadius: _panelRadius,
        mainColor: color,
        useDefaultHoverColor: false,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableRow({
    required String title,
    required Widget subtitle,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return WidgetButton(
      onTap: onTap,
      borderRadius: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _panelOuterGap,
          vertical: _panelGap,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      height: 1,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF030744),
                    ),
                  ),
                  const SizedBox(height: 8),
                  subtitle,
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF030744),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSwitch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(
          color: const Color(0xFF030744).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: WidgetButton(
              onTap: () {
                setState(() {
                  _selectedSection = "partners";
                });
              },
              borderRadius: 6,
              mainColor: _selectedSection == "partners"
                  ? const Color(0xFF030744)
                  : Colors.transparent,
              isTransparentColor: _selectedSection != "partners",
              useDefaultHoverColor: false,
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    "Partners",
                    style: TextStyle(
                      color: _selectedSection == "partners"
                          ? Colors.white
                          : const Color(0xFF030744),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: WidgetButton(
              onTap: () {
                setState(() {
                  _selectedSection = "drivers";
                });
              },
              borderRadius: 6,
              mainColor: _selectedSection == "drivers"
                  ? const Color(0xFF030744)
                  : Colors.transparent,
              isTransparentColor: _selectedSection != "drivers",
              useDefaultHoverColor: false,
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    "Drivers",
                    style: TextStyle(
                      color: _selectedSection == "drivers"
                          ? Colors.white
                          : const Color(0xFF030744),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryWrap(String title, Map<String, double> values) {
    final entries = values.entries.toList()
      ..sort(
        (a, b) => b.key.compareTo(a.key),
      );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_panelInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(
          color: const Color(0xFF030744).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              height: 1,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF030744),
            ),
          ),
          const SizedBox(height: _panelGap),
          if (entries.isEmpty)
            const Text(
              "No history yet.",
              style: TextStyle(
                color: Color(0xFF6D7890),
              ),
            ),
          if (entries.isNotEmpty)
            Column(
              children: entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatMonthLabel(entry.key),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6D7890),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatMoney(entry.value),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF030744),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistoryList({
    required String title,
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String amountKey,
    required String actorLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_panelInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(
          color: const Color(0xFF030744).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              height: 1,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF030744),
            ),
          ),
          const SizedBox(height: _panelGap),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      color: Color(0xFF007BFF),
                    ),
                  ),
                );
              }
              final docs = snapshot.hasData
                  ? _sortDocsByCreatedAt(snapshot.data!.docs)
                  : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              if (docs.isEmpty) {
                return const Text(
                  "No history yet.",
                  style: TextStyle(
                    color: Color(0xFF6D7890),
                  ),
                );
              }
              return Column(
                children: docs.take(10).map((doc) {
                  final data = doc.data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatMoney(data[amountKey]),
                                style: const TextStyle(
                                  height: 1,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF030744),
                                ),
                              ),
                              Text(
                                _formatTimestamp(data["created_at"]),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6D7890),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "$actorLabel: ${data["partner_name"] ?? data["driver_name"] ?? "-"}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF030744),
                            ),
                          ),
                          if ("${data["note"]}".trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "${data["note"]}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6D7890),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPartnerSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_panelOuterGap),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_panelRadius),
            border: Border.all(
              color: const Color(0xFF030744).withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              TextFieldWidget(
                controller: _userIdTEC,
                labelText: "Search Name or User ID",
                onChanged: (value) {
                  setState(() {
                    _quickPartnerUserData = null;
                    _quickPartnerUserId = null;
                    _markupTEC.clear();
                    _quickPaymentMode = "load";
                  });
                  _queueQuickPartnerSearch(value);
                },
              ),
              if (_isSearchingQuickPartner) ...[
                const SizedBox(height: _panelGap),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF007BFF),
                    ),
                  ),
                ),
              ],
              if (_quickPartnerSearchResults.isNotEmpty) ...[
                const SizedBox(height: _panelGap),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_panelRadius),
                    border: Border.all(
                      color: const Color(0xFF030744).withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children:
                        _quickPartnerSearchResults.take(6).map((userData) {
                      final userId = "${userData["id"] ?? ""}";
                      final userName = capitalizeWords(
                        "${userData["name"] ?? "Unnamed User"}",
                        alt: "Unnamed User",
                      );
                      return InkWell(
                        onTap: () => _selectQuickPartner(userData),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: const Color(0xFF030744)
                                    .withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF030744),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "User ID: $userId",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6D7890),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (_quickPartnerUserData != null &&
                  _quickPartnerUserId != null) ...[
                const SizedBox(height: _panelGap),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(_panelGap),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(_panelRadius),
                    border: Border.all(
                      color: const Color(0xFF030744).withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capitalizeWords(
                          "${_quickPartnerUserData?["name"] ?? "Partner"}",
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF030744),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "User ID: ${_quickPartnerUserId ?? ""}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6D7890),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: _panelGap),
                TextFieldWidget(
                  controller: _markupTEC,
                  labelText: "Markup Amount",
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: _panelGap),
                DropdownButtonFormField<String>(
                  initialValue: _quickPaymentMode,
                  decoration: _dropdownDecoration(
                    label: "Payment Mode",
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "cash",
                      child: Text("Cash"),
                    ),
                    DropdownMenuItem(
                      value: "load",
                      child: Text("Load"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _quickPaymentMode = value;
                    });
                  },
                ),
                const SizedBox(height: _panelGap),
                SizedBox(
                  width: double.infinity,
                  child: ActionButton(
                    text: _isSavingQuickSettings
                        ? "Saving..."
                        : "Save Partner Settings",
                    onTap: _isSavingQuickSettings ? () {} : _saveQuickSettings,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactListControls({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_panelGap),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(
          color: const Color(0xFF030744).withValues(alpha: 0.08),
        ),
      ),
      child: TextFieldWidget(
        controller: controller,
        labelText: hintText,
        onChanged: (_) {
          setState(() {});
        },
      ),
    );
  }

  bool _matchesSearch(String source, String query) {
    return source.toLowerCase().contains(query.toLowerCase());
  }

  Widget _buildPartnerList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactListControls(
          controller: _partnerListSearchTEC,
          hintText: "Search partners",
        ),
        const SizedBox(height: _panelGap),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fbStore.collection("partners").snapshots(),
          builder: (context, partnerSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fbStore.collectionGroup("transactions").snapshots(),
              builder: (context, transactionSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: fbStore
                      .collection("users")
                      .orderBy("partner_name")
                      .startAt([""]).snapshots(),
                  builder: (context, userSnapshot) {
                    if ((partnerSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !partnerSnapshot.hasData) ||
                        (transactionSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !transactionSnapshot.hasData) ||
                        (userSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !userSnapshot.hasData)) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: Color(0xFF007BFF),
                          ),
                        ),
                      );
                    }

                    var entries = _buildPartnerEntries(
                      partnerDocs: partnerSnapshot.hasData
                          ? partnerSnapshot.data!.docs
                          : <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                      transactionDocs: transactionSnapshot.hasData
                          ? transactionSnapshot.data!.docs
                          : <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                      userSettingDocs: userSnapshot.hasData
                          ? userSnapshot.data!.docs
                          : <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                    );

                    _ensurePartnerUsersLoaded(
                      entries.map((entry) => "${entry["partnerId"]}").toList(),
                    );

                    final query = _partnerListSearchTEC.text.trim();
                    entries = entries.where((entry) {
                      final partnerId = "${entry["partnerId"]}";
                      final partnerData =
                          entry["partnerData"] as Map<String, dynamic>? ?? {};
                      final inferredUserData =
                          entry["userData"] as Map<String, dynamic>?;
                      final userData =
                          inferredUserData ?? _partnerUserCache[partnerId];
                      final displayName = _partnerDisplayName(
                        partnerId: partnerId,
                        partnerData: partnerData,
                        userData: userData,
                      );
                      if (query.isEmpty) {
                        return true;
                      }
                      final haystack = [
                        partnerId,
                        "${partnerData["partner_name"] ?? ""}",
                        "${userData?["name"] ?? ""}",
                        "${userData?["partner_name"] ?? ""}",
                        displayName,
                      ].join(" ");
                      return _matchesSearch(haystack, query);
                    }).toList();

                    if (entries.isEmpty) {
                      return const Text(
                        "No partners found.",
                        style: TextStyle(
                          color: Color(0xFF6D7890),
                        ),
                      );
                    }

                    return Column(
                      children: entries.map((entry) {
                        final partnerId = "${entry["partnerId"]}";
                        final partnerData =
                            entry["partnerData"] as Map<String, dynamic>? ?? {};
                        final inferredUserData =
                            entry["userData"] as Map<String, dynamic>?;
                        final userData =
                            inferredUserData ?? _partnerUserCache[partnerId];
                        final isExpanded =
                            _expandedPartnerIds.contains(partnerId);
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: _panelOuterGap),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(_panelRadius),
                              border: Border.all(
                                color: const Color(0xFF030744)
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildExpandableRow(
                                  title: _partnerDisplayName(
                                    partnerId: partnerId,
                                    partnerData: partnerData,
                                    userData: userData,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "User ID: $partnerId",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6D7890),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Claimable: ${_formatMoney(partnerData["claimable_cash_markup_amount"])}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6D7890),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Claimed: ${_formatMoney(partnerData["claimed_cash_markup_amount"])}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6D7890),
                                        ),
                                      ),
                                    ],
                                  ),
                                  isExpanded: isExpanded,
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedPartnerIds.remove(partnerId);
                                      } else {
                                        _expandedPartnerIds.add(partnerId);
                                      }
                                    });
                                  },
                                ),
                                if (isExpanded) ...[
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: const Color(0xFF030744)
                                        .withValues(alpha: 0.08),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      _panelOuterGap,
                                      _panelGap,
                                      _panelOuterGap,
                                      _panelOuterGap,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildSummaryRow(
                                          "Payment Mode",
                                          capitalizeWords(
                                            "${userData?["payment_mode"] ?? "cash"}",
                                          ),
                                        ),
                                        _buildSummaryRow(
                                          "Markup",
                                          userData != null
                                              ? _formatMoney(
                                                  userData["markup_amount"])
                                              : _loadingPartnerUserIds
                                                      .contains(partnerId)
                                                  ? "Loading..."
                                                  : _formatMoney(0),
                                        ),
                                        _buildSummaryRow(
                                          "Today",
                                          _formatMoney(
                                              partnerData["today_amount"]),
                                        ),
                                        _buildSummaryRow(
                                          "This Month",
                                          _formatMoney(
                                              partnerData["month_amount"]),
                                        ),
                                        _buildSummaryRow(
                                          "All Time",
                                          _formatMoney(
                                              partnerData["total_amount"]),
                                        ),
                                        _buildSummaryRow(
                                          "Claimed",
                                          _formatMoney(
                                            partnerData[
                                                "claimed_cash_markup_amount"],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildPrimaryButton(
                                          text: "Edit Settings",
                                          onTap: () {
                                            _showEditPartnerDialog(
                                              partnerId: partnerId,
                                              userData: userData,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        _buildPrimaryButton(
                                          text: "Record Claim",
                                          onTap: () {
                                            _showPartnerClaimDialog(
                                              partnerId: partnerId,
                                              partnerData: partnerData,
                                            );
                                          },
                                          color: const Color(0xFF030744),
                                        ),
                                        const SizedBox(height: _panelGap),
                                        _buildHistoryWrap(
                                          "Monthly Markup History",
                                          _toDoubleMap(
                                            partnerData[
                                                "monthly_markup_history"],
                                          ),
                                        ),
                                        const SizedBox(height: _panelGap),
                                        _buildHistoryWrap(
                                          "Monthly Claimable Cash History",
                                          _toDoubleMap(
                                            partnerData[
                                                "monthly_cash_markup_history"],
                                          ),
                                        ),
                                        const SizedBox(height: _panelGap),
                                        _buildHistoryWrap(
                                          "Monthly Claimed History",
                                          _toDoubleMap(
                                            partnerData[
                                                "monthly_claimed_cash_markup_history"],
                                          ),
                                        ),
                                        const SizedBox(height: _panelGap),
                                        _buildTransactionHistoryList(
                                          title: "Claim History",
                                          stream: fbStore
                                              .collection("partners")
                                              .doc(partnerId)
                                              .collection(
                                                  "claimed_transactions")
                                              .snapshots(),
                                          amountKey: "amount",
                                          actorLabel: "Partner",
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDriverList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactListControls(
          controller: _driverListSearchTEC,
          hintText: "Search drivers",
        ),
        const SizedBox(height: _panelGap),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fbStore.collection("drivers").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    color: Color(0xFF007BFF),
                  ),
                ),
              );
            }
            var docs = snapshot.hasData
                ? _sortDocsByUpdatedAt(snapshot.data!.docs)
                : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final query = _driverListSearchTEC.text.trim();
            docs = docs.where((doc) {
              final data = doc.data();
              final received = _toDouble(data["received_cash_markup_amount"]);
              final deducted = _toDouble(data["deducted_cash_markup_amount"]);
              final hasMarkup = received > 0 || deducted > 0;
              if (!hasMarkup) {
                return false;
              }
              if (query.isEmpty) {
                return true;
              }
              final driverId = "${data["driver_id"] ?? doc.id}";
              final haystack = [
                driverId,
                "${data["driver_name"] ?? ""}",
                "${data["name"] ?? ""}",
              ].join(" ");
              return _matchesSearch(haystack, query);
            }).toList();
            docs.sort((a, b) {
              final aData = a.data();
              final bData = b.data();
              final aDeductible = max(
                _toDouble(aData["received_cash_markup_amount"]) -
                    _toDouble(aData["deducted_cash_markup_amount"]),
                0,
              );
              final bDeductible = max(
                _toDouble(bData["received_cash_markup_amount"]) -
                    _toDouble(bData["deducted_cash_markup_amount"]),
                0,
              );
              final deductibleDiff = bDeductible.compareTo(aDeductible);
              if (deductibleDiff != 0) {
                return deductibleDiff;
              }
              final aTs = aData["updated_at"];
              final bTs = bData["updated_at"];
              if (aTs is Timestamp && bTs is Timestamp) {
                return bTs.compareTo(aTs);
              }
              return 0;
            });
            if (docs.isEmpty) {
              return const Text(
                "No driver markup records found.",
                style: TextStyle(
                  color: Color(0xFF6D7890),
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final driverId = "${data["driver_id"] ?? doc.id}";
                final deductible = max(
                  _toDouble(data["received_cash_markup_amount"]) -
                      _toDouble(data["deducted_cash_markup_amount"]),
                  0,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: _panelOuterGap),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_panelRadius),
                      border: Border.all(
                        color: const Color(0xFF030744).withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildExpandableRow(
                          title: capitalizeWords(
                            "${data["driver_name"] ?? data["name"] ?? "Driver"}",
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Driver ID: $driverId",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6D7890),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Deductible: ${_formatMoney(deductible)}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6D7890),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Deducted: ${_formatMoney(data["deducted_cash_markup_amount"])}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6D7890),
                                ),
                              ),
                            ],
                          ),
                          isExpanded: _expandedDriverIds.contains(driverId),
                          onTap: () {
                            setState(() {
                              if (_expandedDriverIds.contains(driverId)) {
                                _expandedDriverIds.remove(driverId);
                              } else {
                                _expandedDriverIds.add(driverId);
                              }
                            });
                          },
                        ),
                        if (_expandedDriverIds.contains(driverId)) ...[
                          Divider(
                            height: 1,
                            thickness: 1,
                            color:
                                const Color(0xFF030744).withValues(alpha: 0.08),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              _panelOuterGap,
                              _panelGap,
                              _panelOuterGap,
                              _panelOuterGap,
                            ),
                            child: Column(
                              children: [
                                _buildSummaryRow(
                                  "Received",
                                  _formatMoney(
                                    data["received_cash_markup_amount"],
                                  ),
                                ),
                                _buildSummaryRow(
                                  "Deducted",
                                  _formatMoney(
                                    data["deducted_cash_markup_amount"],
                                  ),
                                ),
                                _buildSummaryRow(
                                  "Deductible",
                                  _formatMoney(deductible),
                                ),
                                const SizedBox(height: 8),
                                _buildPrimaryButton(
                                  text: "Record Deduction",
                                  onTap: () {
                                    _showDriverDeductionDialog(
                                      driverId: driverId,
                                      driverData: data,
                                    );
                                  },
                                ),
                                const SizedBox(height: _panelGap),
                                _buildHistoryWrap(
                                  "Monthly Received History",
                                  _toDoubleMap(
                                    data[
                                        "monthly_received_cash_markup_history"],
                                  ),
                                ),
                                const SizedBox(height: _panelGap),
                                _buildHistoryWrap(
                                  "Monthly Deducted History",
                                  _toDoubleMap(
                                    data[
                                        "monthly_deducted_cash_markup_history"],
                                  ),
                                ),
                                const SizedBox(height: _panelGap),
                                _buildTransactionHistoryList(
                                  title: "Deduction History",
                                  stream: fbStore
                                      .collection("drivers")
                                      .doc(driverId)
                                      .collection(
                                          "deducted_markup_transactions")
                                      .snapshots(),
                                  amountKey: "amount",
                                  actorLabel: "Driver",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPanelBody() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fbStore.collection("access").doc("pwa_partners").snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final hasAccess = _hasPanelAccess(
          data?["users"] ?? [],
        );
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF007BFF),
            ),
          );
        }
        if (!hasAccess) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 46,
                    color: Color(0xFF030744),
                  ),
                  SizedBox(height: 14),
                  Text(
                    "You do not have access to the Partner panel.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.2,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF030744),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            _isNarrowScreen(context) ? 14 : 18,
            _panelOuterGap,
            _isNarrowScreen(context) ? 14 : 18,
            24,
          ),
          child: Column(
            children: [
              _buildQuickPartnerSettings(),
              const SizedBox(height: _panelOuterGap),
              _buildSectionSwitch(),
              const SizedBox(height: _panelOuterGap),
              if (_selectedSection == "partners") _buildPartnerList(),
              if (_selectedSection == "drivers") _buildDriverList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 4),
                  WidgetButton(
                    onTap: () {
                      Get.back();
                    },
                    child: const SizedBox(
                      width: 58,
                      height: 58,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: 2,
                            right: 4,
                            bottom: 2,
                          ),
                          child: Icon(
                            Icons.chevron_left,
                            color: Color(0xFF030744),
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Expanded(
                    child: Text(
                      "Partner Panel",
                      style: TextStyle(
                        height: 1,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF030744),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 1,
                color: const Color(0xFF030744).withValues(alpha: 0.1),
              ),
              Expanded(
                child: _buildPanelBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
