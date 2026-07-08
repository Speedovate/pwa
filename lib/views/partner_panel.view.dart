// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/alert.service.dart';
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

  final NumberFormat _currencyFormatter = NumberFormat("#,##0", "en_US");
  final TextEditingController _userIdTEC = TextEditingController();
  final TextEditingController _quickPartnerNameTEC = TextEditingController();
  final TextEditingController _markupTEC = TextEditingController();
  final TextEditingController _partnerListSearchTEC = TextEditingController();
  final TextEditingController _driverListSearchTEC = TextEditingController();
  Timer? _quickPartnerSearchDebounce;
  Timer? _partnerListSearchDebounce;
  Timer? _driverListSearchDebounce;
  bool _isSavingQuickSettings = false;
  bool _isSearchingQuickPartner = false;
  Map<String, dynamic>? _quickPartnerUserData;
  String? _quickPartnerUserId;
  String _quickPaymentMode = "load";
  List<Map<String, dynamic>> _quickPartnerSearchResults = [];
  int _quickPartnerSearchVersion = 0;
  String _selectedSection = "partners";
  final Map<String, Map<String, dynamic>?> _partnerUserCache = {};
  final Set<String> _loadingPartnerUserIds = {};
  final Set<String> _expandedPartnerIds = {};
  final Set<String> _expandedDriverIds = {};

  @override
  void dispose() {
    _quickPartnerSearchDebounce?.cancel();
    _partnerListSearchDebounce?.cancel();
    _driverListSearchDebounce?.cancel();
    _userIdTEC.dispose();
    _quickPartnerNameTEC.dispose();
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
    final formatted = _currencyFormatter
        .format(_toDouble(value).round())
        .replaceAll(RegExp(r"^[^\d-]+"), "");
    return "₱$formatted";
  }

  String _formatWholeNumber(dynamic value) {
    return _toDouble(value).toStringAsFixed(0);
  }

  String _firstNonEmptyText(List<dynamic> values) {
    for (final value in values) {
      final text = "$value".trim();
      if (text.isNotEmpty && text.toLowerCase() != "null") {
        return text;
      }
    }
    return "";
  }

  bool _hasPendingPanelDetails() {
    return _hasText(_userIdTEC.text) ||
        _hasText(_quickPartnerNameTEC.text) ||
        _hasText(_markupTEC.text) ||
        _hasText(_partnerListSearchTEC.text) ||
        _hasText(_driverListSearchTEC.text);
  }

  bool _hasText(String? value) {
    final text = (value ?? "").trim();
    return text.isNotEmpty && text != "null";
  }

  void _leavePartnerPanel() {
    Get.back();
  }

  void _confirmLeavePartnerPanel() {
    if (!_hasPendingPanelDetails()) {
      _leavePartnerPanel();
      return;
    }

    AlertService().showAppAlert(
      title: "Are you sure?",
      content: "You're about to leave this page",
      hideCancel: false,
      confirmText: "Leave",
      confirmColor: Colors.red,
      confirmAction: () {
        Get.back();
        _leavePartnerPanel();
      },
    );
  }

  String _monthKeyNow() {
    return DateFormat(
      "yyyy-MM",
    ).format(
      DateTime.now(),
    );
  }

  String _currentMonthLabel() {
    return DateFormat("MMM yyyy").format(DateTime.now());
  }

  String _editableDateTimeLabel(DateTime value) {
    return DateFormat("MMM dd, yyyy hh:mm a").format(value);
  }

  Timestamp _timestampNow() {
    return Timestamp.now();
  }

  String _transactionV2DocIdFromDate(DateTime value) {
    return DateFormat("MMddyyyyhhmmssa").format(value).toUpperCase();
  }

  Future<String> _resolveTransactionV2DocId({
    required CollectionReference<Map<String, dynamic>> collection,
    required String baseId,
    String? currentId,
  }) async {
    if (currentId == baseId) {
      return baseId;
    }
    var candidate = baseId;
    var suffix = 2;
    while (true) {
      final snapshot = await collection.doc(candidate).get();
      if (!snapshot.exists || candidate == currentId) {
        return candidate;
      }
      candidate = "${baseId}_$suffix";
      suffix++;
    }
  }

  DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse("$value");
  }

  Timestamp? _timestampFromValue(dynamic value) {
    if (value is Timestamp) {
      return value;
    }
    final date = _dateTimeFromValue(value);
    if (date == null) {
      return null;
    }
    return Timestamp.fromDate(date);
  }

  dynamic _toEditableValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          "$key",
          _toEditableValue(item),
        ),
      );
    }
    if (value is List) {
      return value.map(_toEditableValue).toList();
    }
    return value;
  }

  dynamic _fromEditableValue(String? key, dynamic value) {
    if (value is Map) {
      return value.map(
        (mapKey, item) => MapEntry(
          "$mapKey",
          _fromEditableValue("$mapKey", item),
        ),
      );
    }
    if (value is List) {
      return value.map((item) => _fromEditableValue(key, item)).toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      final isDateKey = (key ?? "").endsWith("_at") ||
          (key ?? "").contains("date") ||
          trimmed.contains("T");
      if (isDateKey) {
        final parsed = DateTime.tryParse(trimmed);
        if (parsed != null) {
          return Timestamp.fromDate(parsed);
        }
      }
      return value;
    }
    return value;
  }

  String _prettyJson(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent("  ");
    return encoder.convert(
      _toEditableValue(data),
    );
  }

  Map<String, dynamic> _mapFromJsonText(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw "JSON must be an object.";
    }
    return Map<String, dynamic>.from(
      _fromEditableValue(null, decoded) as Map,
    );
  }

  String _monthKeyFromData(Map<String, dynamic> data) {
    final monthKey = "${data["month_key"] ?? ""}".trim();
    if (monthKey.isNotEmpty && monthKey.toLowerCase() != "null") {
      return monthKey;
    }
    final createdAt = _dateTimeFromValue(data["created_at"]);
    if (createdAt == null) {
      return _monthKeyNow();
    }
    return DateFormat("yyyy-MM").format(createdAt);
  }

  bool _isCreditTransaction(Map<String, dynamic> data) {
    if (data["is_credit"] == null) {
      return true;
    }
    return isBool(data["is_credit"]);
  }

  bool _isPartnerUserData(Map<String, dynamic> data) {
    return isBool(data["is_provider"]) ||
        isBool(data["is_prv"]) ||
        isBool(data["isProvider"]);
  }

  bool _hasDriverIdentity(Map<String, dynamic> data) {
    return _firstNonEmptyText([
      data["driver_id"],
      data["driver_name"],
    ]).isNotEmpty;
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

    for (final doc in userSettingDocs) {
      final userData = doc.data();
      final partnerId = doc.id.trim();
      if (partnerId.isEmpty) {
        continue;
      }
      if (!entries.containsKey(partnerId) && !_isPartnerUserData(userData)) {
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
      final aUserData = a["userData"] as Map<String, dynamic>?;
      final bUserData = b["userData"] as Map<String, dynamic>?;
      final claimableDiff = _toDouble(
        bData["claimable_cash_markup_amount"],
      ).compareTo(
        _toDouble(aData["claimable_cash_markup_amount"]),
      );
      if (claimableDiff != 0) {
        return claimableDiff;
      }
      final claimedDiff = _toDouble(
        bData["claimed_cash_markup_amount"],
      ).compareTo(
        _toDouble(aData["claimed_cash_markup_amount"]),
      );
      if (claimedDiff != 0) {
        return claimedDiff;
      }
      final aName = _normalizedSortText(
        _partnerDisplayName(
          partnerId: "${a["partnerId"]}",
          partnerData: aData,
          userData: aUserData,
        ),
      );
      final bName = _normalizedSortText(
        _partnerDisplayName(
          partnerId: "${b["partnerId"]}",
          partnerData: bData,
          userData: bUserData,
        ),
      );
      final nameDiff = aName.compareTo(bName);
      if (nameDiff != 0) {
        return nameDiff;
      }
      return ("${a["partnerId"]}").compareTo("${b["partnerId"]}");
    });
    return merged;
  }

  int _visibleDriverCount({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> driverDocs,
    required Set<String> partnerIds,
  }) {
    return driverDocs.where((doc) {
      final data = doc.data();
      final driverId = "${data["driver_id"] ?? doc.id}";
      if ((partnerIds.contains(doc.id) || partnerIds.contains(driverId)) &&
          !_hasDriverIdentity(data)) {
        return false;
      }
      final deductible = _toDouble(data["deductible_cash_markup_amount"]);
      final deducted = _toDouble(data["deducted_cash_markup_amount"]);
      final hasMarkup = deductible > 0 || deducted > 0;
      return hasMarkup || _hasDriverIdentity(data);
    }).length;
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      return DateFormat(
        "MM/dd/yyyy",
      ).format(
        value.toDate(),
      );
    }
    return "-";
  }

  Future<DateTime?> _pickDateTime(DateTime initialValue) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialValue,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007BFF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF030744),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedDate == null || !mounted) {
      return null;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007BFF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF030744),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedTime == null) {
      return null;
    }
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
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

  String _normalizePartnerName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r"\s+"), " ");
  }

  String _normalizedSortText(String value) {
    return value.trim().toLowerCase();
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

  void _ensurePartnerUsersLoadedAfterBuild(List<String> userIds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensurePartnerUsersLoaded(userIds);
    });
  }

  void _showSuccessSnack(String message) {
    showSuccess(message, context: context);
  }

  void _showErrorSnack(String message) {
    showError(message);
  }

  void _scheduleListSearchRefresh({required bool isDriver}) {
    final timer =
        isDriver ? _driverListSearchDebounce : _partnerListSearchDebounce;
    if (timer != null) {
      tempTimerDebug(
        isDriver
            ? "partner_panel.driver_list_search"
            : "partner_panel.partner_list_search",
        "cancel_before_reschedule",
        details: {
          "instanceId": tempTimerInstanceId(timer),
        },
      );
    }
    timer?.cancel();
    Timer? nextTimer;
    final instanceId = nextTempTimerInstanceId(
      isDriver
          ? "partner_panel.driver_list_search"
          : "partner_panel.partner_list_search",
    );
    tempTimerDebug(
      isDriver
          ? "partner_panel.driver_list_search"
          : "partner_panel.partner_list_search",
      "schedule",
      details: {
        "instanceId": instanceId,
      },
    );
    nextTimer = Timer(const Duration(milliseconds: 160), () {
      if (isDriver) {
        if (identical(_driverListSearchDebounce, nextTimer)) {
          _driverListSearchDebounce = null;
        }
      } else {
        if (identical(_partnerListSearchDebounce, nextTimer)) {
          _partnerListSearchDebounce = null;
        }
      }
      if (!mounted) {
        return;
      }
      tempTimerDebug(
        isDriver
            ? "partner_panel.driver_list_search"
            : "partner_panel.partner_list_search",
        "fire",
        details: {
          "instanceId": instanceId,
        },
      );
      setState(() {});
    });
    if (isDriver) {
      _driverListSearchDebounce = nextTimer;
    } else {
      _partnerListSearchDebounce = nextTimer;
    }
    attachTempTimerInstanceId(nextTimer, instanceId);
  }

  Future<void> _showJsonEditorDialog({
    required String title,
    required Map<String, dynamic> initialData,
    required Future<void> Function(Map<String, dynamic> data) onSave,
  }) async {
    final jsonTEC = TextEditingController(
      text: _prettyJson(initialData),
    );
    bool isSaving = false;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useSafeArea: false,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              title: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF030744),
                ),
              ),
              content: SizedBox(
                width: min(mediaQuery.size.width, 520),
                child: TextField(
                  controller: jsonTEC,
                  minLines: 18,
                  maxLines: 18,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontFamily: "Courier",
                    color: Color(0xFF030744),
                  ),
                  decoration: InputDecoration(
                    labelText: "JSON Data",
                    alignLabelWithHint: true,
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
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              actions: [
                _dialogActionButton(
                  text: "Cancel",
                  onTap: isSaving ? null : () => Navigator.pop(context),
                ),
                _dialogActionButton(
                  text: "Format",
                  onTap: isSaving
                      ? null
                      : () {
                          try {
                            final data = _mapFromJsonText(jsonTEC.text);
                            jsonTEC.value = TextEditingValue(
                              text: _prettyJson(data),
                              selection: TextSelection.collapsed(
                                offset: _prettyJson(data).length,
                              ),
                            );
                          } catch (e) {
                            _showErrorSnack("$e");
                          }
                        },
                ),
                _dialogActionButton(
                  text: isSaving ? "Saving..." : "Save",
                  onTap: isSaving
                      ? null
                      : () async {
                          setStateDialog(() {
                            isSaving = true;
                          });
                          try {
                            final data = _mapFromJsonText(jsonTEC.text);
                            await onSave(data);
                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
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
                ),
              ],
            );
          },
        );
      },
    );
    jsonTEC.dispose();
  }

  bool _isNarrowScreen(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width < 390;
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

  Widget _dialogActionButton({
    required String text,
    required VoidCallback? onTap,
  }) {
    return WidgetButton(
      onTap: onTap ?? () {},
      mainColor: Colors.transparent,
      isTransparentColor: true,
      useDefaultHoverColor: false,
      interactionColor: const Color(0x14030744),
      disableGestureDetection: onTap == null,
      borderRadius: _panelRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: onTap == null
                ? const Color(0xFF030744).withValues(alpha: 0.35)
                : const Color(0xFF030744),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final isEmpty = value.trim().isEmpty;
    return WidgetButton(
      onTap: onTap,
      borderRadius: _panelRadius,
      mainColor: Colors.white,
      useDefaultHoverColor: false,
      child: Theme(
        data: ThemeData(
          inputDecorationTheme: InputDecorationTheme(
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
          ),
        ),
        child: InputDecorator(
          isFocused: false,
          isEmpty: isEmpty,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: isEmpty ? label : null,
            labelStyle: const TextStyle(
              height: 1,
              fontSize: 14,
              fontFamily: "Inter",
              fontWeight: FontWeight.bold,
              color: Color(0xFF030744),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 18,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isEmpty ? label : value,
                  style: TextStyle(
                    height: 1,
                    fontSize: 14,
                    fontFamily: "Inter",
                    fontWeight: FontWeight.bold,
                    color: isEmpty
                        ? const Color(0xFF007BFF).withValues(alpha: 0.5)
                        : const Color(0xFF030744),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Color(0xFF030744),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePartnerSettings({
    required String userId,
    required double markupAmount,
    required String paymentMode,
    String? partnerNameOverride,
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
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    final normalizedPaymentMode =
        paymentMode.toLowerCase() == "cash" ? "cash" : "load";
    final rawPartnerName =
        "${partnerNameOverride ?? userData["partner_name"] ?? userData["name"] ?? ""}"
            .trim();
    final partnerName =
        rawPartnerName.isEmpty || rawPartnerName.toLowerCase() == "null"
            ? null
            : capitalizeWords(rawPartnerName, alt: rawPartnerName);

    final batch = fbStore.batch();
    batch.set(
      userRef,
      {
        if (partnerName != null) "name": partnerName,
        "markup_amount": markupAmount,
        "payment_mode": normalizedPaymentMode,
        "partner_name": partnerName,
        if (!userData.containsKey("today_amount")) "today_amount": 0,
        if (!userData.containsKey("month_amount")) "month_amount": 0,
        if (!userData.containsKey("total_amount")) "total_amount": 0,
        "syncedAt": syncedAt,
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
          "today": DateFormat("MMMM d, yyyy").format(DateTime.now()),
          "month": DateFormat("MMMM").format(DateTime.now()),
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
          "today": DateFormat("MMMM d, yyyy").format(DateTime.now()),
          "month": DateFormat("MMMM").format(DateTime.now()),
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
      "name": partnerName ?? userData["name"],
      "updated_at": timestamp,
    };
    _loadingPartnerUserIds.remove(trimmedId);
  }

  Future<void> _savePartnerRecord({
    required String partnerId,
    required Map<String, dynamic> data,
  }) async {
    final trimmedId = partnerId.trim();
    if (trimmedId.isEmpty) {
      throw "Partner ID is missing.";
    }
    final timestamp = _timestampNow();
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    final partnerData = Map<String, dynamic>.from(data)
      ..["partner_id"] = trimmedId
      ..["updated_at"] = timestamp;
    final userUpdate = <String, dynamic>{
      "syncedAt": syncedAt,
      "updated_at": timestamp,
    };
    const syncedKeys = [
      "partner_name",
      "markup_amount",
      "payment_mode",
      "today_amount",
      "month_amount",
      "total_amount",
    ];
    for (final key in syncedKeys) {
      if (partnerData.containsKey(key)) {
        userUpdate[key] = partnerData[key];
      }
    }
    if ("${partnerData["partner_name"] ?? ""}".trim().isNotEmpty) {
      userUpdate["name"] = partnerData["partner_name"];
    }
    final batch = fbStore.batch();
    batch.set(
      fbStore.collection("partners").doc(trimmedId),
      partnerData,
      SetOptions(merge: true),
    );
    batch.set(
      fbStore.collection("users").doc(trimmedId),
      userUpdate,
      SetOptions(merge: true),
    );
    await batch.commit();
    _partnerUserCache[trimmedId] = {
      ...?_partnerUserCache[trimmedId],
      ...userUpdate,
    };
  }

  Future<void> _saveDriverRecord({
    required String driverId,
    required Map<String, dynamic> data,
  }) async {
    final trimmedId = driverId.trim();
    if (trimmedId.isEmpty) {
      throw "Driver ID is missing.";
    }
    final timestamp = _timestampNow();
    final driverData = Map<String, dynamic>.from(data)
      ..["driver_id"] = trimmedId
      ..["updated_at"] = timestamp;
    final userUpdate = <String, dynamic>{
      "updated_at": timestamp,
    };
    const syncedKeys = [
      "driver_id",
      "driver_name",
      "deductible_cash_markup_amount",
      "deductible_cash_markup_month_amount",
      "deductible_cash_markup_history",
    ];
    for (final key in syncedKeys) {
      if (driverData.containsKey(key)) {
        userUpdate[key] = driverData[key];
      }
    }
    final batch = fbStore.batch();
    batch.set(
      fbStore.collection("drivers").doc(trimmedId),
      driverData,
      SetOptions(merge: true),
    );
    final normalizedName = _firstNonEmptyText([
      driverData["driver_name"],
      driverData["name"],
    ]);
    if (normalizedName.isNotEmpty) {
      userUpdate["name"] = normalizedName;
      userUpdate["driver_name"] = normalizedName;
    }
    batch.set(
      fbStore.collection("users").doc(trimmedId),
      userUpdate,
      SetOptions(merge: true),
    );
    await batch.commit();
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
        partnerNameOverride: _quickPartnerNameTEC.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _quickPartnerUserData = {
          ...?_quickPartnerUserData,
          "markup_amount": markupAmount,
          "payment_mode": _quickPaymentMode,
          "partner_name": _quickPartnerNameTEC.text.trim().isEmpty
              ? null
              : capitalizeWords(
                  _quickPartnerNameTEC.text,
                  alt: _quickPartnerNameTEC.text,
                ),
          if (_quickPartnerNameTEC.text.trim().isNotEmpty)
            "name": capitalizeWords(
              _quickPartnerNameTEC.text,
              alt: _quickPartnerNameTEC.text,
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
    if (_quickPartnerSearchDebounce != null) {
      tempTimerDebug(
        "partner_panel.quick_partner_search",
        "cancel_before_reschedule",
        details: {
          "instanceId": tempTimerInstanceId(_quickPartnerSearchDebounce),
        },
      );
    }
    _quickPartnerSearchDebounce?.cancel();
    final instanceId =
        nextTempTimerInstanceId("partner_panel.quick_partner_search");
    tempTimerDebug(
      "partner_panel.quick_partner_search",
      "schedule",
      details: {
        "instanceId": instanceId,
        "valueLength": value.length,
      },
    );
    _quickPartnerSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        _quickPartnerSearchDebounce = null;
        tempTimerDebug(
          "partner_panel.quick_partner_search",
          "fire",
          details: {
            "instanceId": instanceId,
            "valueLength": value.length,
          },
        );
        _searchQuickPartners(value);
      },
    );
    if (_quickPartnerSearchDebounce != null) {
      attachTempTimerInstanceId(_quickPartnerSearchDebounce!, instanceId);
    }
  }

  Future<void> _searchQuickPartners(String value) async {
    final keyword = value.trim();
    final searchVersion = ++_quickPartnerSearchVersion;
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

      final broadUserSnapshot =
          await fbStore.collection("users").limit(250).get();
      for (final doc in broadUserSnapshot.docs) {
        if (seenIds.contains(doc.id)) {
          continue;
        }
        final data = doc.data();
        final haystack = [
          doc.id,
          "${data["name"] ?? ""}",
          "${data["partner_name"] ?? ""}",
        ].join(" ").toLowerCase();
        if (haystack.contains(lowerKeyword)) {
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

      if (!mounted ||
          searchVersion != _quickPartnerSearchVersion ||
          _userIdTEC.text.trim() != keyword) {
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
      _quickPartnerNameTEC.text = _firstNonEmptyText([
        userData["partner_name"],
        userData["name"],
      ]);
      _markupTEC.text = _formatWholeNumber(userData["markup_amount"]);
      _quickPaymentMode =
          "${userData["payment_mode"] ?? "load"}".toLowerCase() == "cash"
              ? "cash"
              : "load";
      _quickPartnerSearchResults = [];
    });
  }

  Future<void> _showEditPartnerDialog({
    required String partnerId,
    required Map<String, dynamic> partnerData,
  }) async {
    await _showJsonEditorDialog(
      title: "Edit Partner Record",
      initialData: partnerData,
      onSave: (data) async {
        await _savePartnerRecord(
          partnerId: partnerId,
          data: data,
        );
        _showSuccessSnack("Partner record updated.");
      },
    );
  }

  Future<void> _updatePartnerAggregateForTransactionChange({
    required String partnerId,
    required Map<String, dynamic> partnerData,
    Map<String, dynamic>? oldTransactionData,
    Map<String, dynamic>? newTransactionData,
  }) async {
    final partnerRef = fbStore.collection("partners").doc(partnerId);
    final partnerSnapshot = await partnerRef.get();
    final currentPartnerData = {
      ..._defaultPartnerAggregate(
        partnerId: partnerId,
        partnerName: _firstNonEmptyText([
          partnerData["partner_name"],
          partnerData["name"],
        ]),
      ),
      ...partnerData,
      ...?partnerSnapshot.data(),
      "partner_id": partnerId,
    };

    var todayAmount = _toDouble(currentPartnerData["today_amount"]);
    var monthAmount = _toDouble(currentPartnerData["month_amount"]);
    var totalAmount = _toDouble(currentPartnerData["total_amount"]);
    var claimable = _toDouble(
      currentPartnerData["claimable_cash_markup_amount"],
    );
    var claimableMonth = _toDouble(
      currentPartnerData["claimable_cash_markup_month_amount"],
    );
    var claimedTotal = _toDouble(
      currentPartnerData["claimed_cash_markup_amount"],
    );
    var claimedMonthTotal = _toDouble(
      currentPartnerData["claimed_cash_markup_month_amount"],
    );
    final markupHistory = Map<String, dynamic>.from(
      currentPartnerData["monthly_markup_history"] ??
          currentPartnerData["monthly_cash_markup_history"] ??
          {},
    );
    final claimedHistory = Map<String, dynamic>.from(
      currentPartnerData["monthly_claimed_cash_markup_history"] ?? {},
    );
    final currentMonthKey = _monthKeyNow();
    final now = DateTime.now();

    void adjustHistory(
      Map<String, dynamic> history,
      String monthKey,
      double delta,
    ) {
      final nextValue = max(_toDouble(history[monthKey]) + delta, 0);
      if (nextValue == 0) {
        history.remove(monthKey);
      } else {
        history[monthKey] = nextValue;
      }
    }

    void applyTransaction(
        Map<String, dynamic>? transactionData, int direction) {
      if (transactionData == null) {
        return;
      }
      final amount = _toDouble(transactionData["amount"]);
      if (amount <= 0) {
        return;
      }
      final isCredit = _isCreditTransaction(transactionData);
      final monthKey = _monthKeyFromData(transactionData);
      final createdAt = _dateTimeFromValue(transactionData["created_at"]);
      final isToday = createdAt != null &&
          createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
      final signedAmount = amount * direction;

      if (isCredit) {
        totalAmount = max(totalAmount + signedAmount, 0);
        claimable = max(claimable + signedAmount, 0);
        if (isToday) {
          todayAmount = max(todayAmount + signedAmount, 0);
        }
        adjustHistory(
          markupHistory,
          monthKey,
          signedAmount,
        );
        if (monthKey == currentMonthKey) {
          monthAmount = max(monthAmount + signedAmount, 0);
          claimableMonth = max(claimableMonth + signedAmount, 0);
        }
      } else {
        claimedTotal = max(claimedTotal + signedAmount, 0);
        claimable = max(claimable - signedAmount, 0);
        adjustHistory(
          claimedHistory,
          monthKey,
          signedAmount,
        );
        if (monthKey == currentMonthKey) {
          claimedMonthTotal = max(claimedMonthTotal + signedAmount, 0);
          claimableMonth = max(claimableMonth - signedAmount, 0);
        }
      }
    }

    applyTransaction(oldTransactionData, -1);
    applyTransaction(newTransactionData, 1);
    final todayLabel = DateFormat("MMMM d, yyyy").format(DateTime.now());
    final monthLabel = DateFormat("MMMM").format(DateTime.now());

    final aggregateUpdate = {
      "partner_id": partnerId,
      "partner_name": _firstNonEmptyText([
        currentPartnerData["partner_name"],
        partnerData["partner_name"],
        partnerData["name"],
      ]),
      "today": todayLabel,
      "month": monthLabel,
      "today_amount": todayAmount,
      "month_amount": monthAmount,
      "total_amount": totalAmount,
      "claimable_cash_markup_amount": claimable,
      "claimable_cash_markup_month_amount": claimableMonth,
      "claimed_cash_markup_amount": claimedTotal,
      "claimed_cash_markup_month_amount": claimedMonthTotal,
      "monthly_markup_history": markupHistory,
      "monthly_cash_markup_history": markupHistory,
      "monthly_claimed_cash_markup_history": claimedHistory,
      "updated_at": _timestampNow(),
    };
    final userUpdate = <String, dynamic>{
      "today_amount": todayAmount,
      "month_amount": monthAmount,
      "total_amount": totalAmount,
      "updated_at": aggregateUpdate["updated_at"],
    };
    final partnerName = "${aggregateUpdate["partner_name"] ?? ""}".trim();
    if (partnerName.isNotEmpty) {
      userUpdate["partner_name"] = aggregateUpdate["partner_name"];
      userUpdate["name"] = aggregateUpdate["partner_name"];
    }
    if (currentPartnerData.containsKey("markup_amount")) {
      userUpdate["markup_amount"] = currentPartnerData["markup_amount"];
    }
    if (currentPartnerData.containsKey("payment_mode")) {
      userUpdate["payment_mode"] = currentPartnerData["payment_mode"];
    }

    final batch = fbStore.batch();
    batch.set(
      partnerRef,
      aggregateUpdate,
      SetOptions(merge: true),
    );
    batch.set(
      fbStore.collection("users").doc(partnerId),
      userUpdate,
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _updateDriverAggregateForTransactionChange({
    required String driverId,
    required Map<String, dynamic> driverData,
    Map<String, dynamic>? oldTransactionData,
    Map<String, dynamic>? newTransactionData,
  }) async {
    final driverRef = fbStore.collection("drivers").doc(driverId);
    final userRef = fbStore.collection("users").doc(driverId);
    final driverSnapshot = await driverRef.get();
    final transactionsSnapshot =
        await driverRef.collection("transactions_v2").get();
    final currentDriverData = {
      "driver_id": driverId,
      ...?driverSnapshot.data(),
      ...driverData,
    };
    final currentMonthKey = _monthKeyNow();
    final creditedHistory = <String, dynamic>{};
    final deductedHistory = <String, dynamic>{};
    final deductibleHistory = <String, dynamic>{};
    var deductible = 0.0;
    var deductibleMonth = 0.0;
    var deducted = 0.0;
    var deductedMonth = 0.0;

    void addToHistory(
      Map<String, dynamic> history,
      String monthKey,
      double amount,
    ) {
      final nextValue = _toDouble(history[monthKey]) + amount;
      if (nextValue <= 0) {
        history.remove(monthKey);
      } else {
        history[monthKey] = nextValue;
      }
    }

    for (final doc in transactionsSnapshot.docs) {
      final transactionData = doc.data();
      final amount = _toDouble(transactionData["amount"]);
      if (amount <= 0) {
        continue;
      }
      final isCredit = _isCreditTransaction(transactionData);
      final monthKey = _monthKeyFromData(transactionData);
      if (isCredit) {
        deductible += amount;
        addToHistory(creditedHistory, monthKey, amount);
        addToHistory(deductibleHistory, monthKey, amount);
        if (monthKey == currentMonthKey) {
          deductibleMonth += amount;
        }
      } else {
        deductible = max(deductible - amount, 0);
        deducted += amount;
        addToHistory(deductedHistory, monthKey, amount);
        addToHistory(deductibleHistory, monthKey, -amount);
        if (monthKey == currentMonthKey) {
          deductibleMonth = max(deductibleMonth - amount, 0);
          deductedMonth += amount;
        }
      }
    }

    final aggregateUpdate = {
      "driver_id": driverId,
      "driver_name": _firstNonEmptyText([
        currentDriverData["driver_name"],
        driverData["driver_name"],
        driverData["name"],
      ]),
      "deductible_cash_markup_amount": deductible,
      "deductible_cash_markup_month_amount": deductibleMonth,
      "deductible_cash_markup_history": deductibleHistory,
      "deducted_cash_markup_amount": deducted,
      "deducted_cash_markup_month_amount": deductedMonth,
      "monthly_credited_cash_markup_history": creditedHistory,
      "monthly_deducted_cash_markup_history": deductedHistory,
      "updated_at": _timestampNow(),
    };

    final batch = fbStore.batch();
    batch.set(
      driverRef,
      aggregateUpdate,
      SetOptions(merge: true),
    );
    batch.set(
      userRef,
      aggregateUpdate,
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _showEditDriverDialog({
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    await _showJsonEditorDialog(
      title: "Edit Driver Record",
      initialData: driverData,
      onSave: (data) async {
        await _saveDriverRecord(
          driverId: driverId,
          data: data,
        );
        _showSuccessSnack("Driver record updated.");
      },
    );
  }

  Map<String, dynamic> _partnerTransactionTemplate({
    required String partnerId,
    required Map<String, dynamic> partnerData,
  }) {
    return {
      "amount": 0,
      "is_credit": true,
      "name": _firstNonEmptyText([
        partnerData["partner_name"],
        partnerData["name"],
      ]),
      "created_at": DateTime.now().toIso8601String(),
      "note": "",
    };
  }

  Map<String, dynamic> _driverTransactionTemplate({
    required String driverId,
    required Map<String, dynamic> driverData,
  }) {
    return {
      "amount": 0,
      "is_credit": true,
      "name": _firstNonEmptyText([
        driverData["driver_name"],
        driverData["name"],
      ]),
      "created_at": DateTime.now().toIso8601String(),
      "note": "",
    };
  }

  Future<void> _showPartnerTransactionDialog({
    required String title,
    required String partnerId,
    required Map<String, dynamic> partnerData,
    String? transactionId,
    Map<String, dynamic>? initialData,
  }) async {
    final seed = initialData ??
        _partnerTransactionTemplate(
            partnerId: partnerId, partnerData: partnerData);
    final amountTEC = TextEditingController(
      text: _toDouble(seed["amount"]) > 0
          ? _toDouble(seed["amount"]).toStringAsFixed(0)
          : "",
    );
    final nameTEC = TextEditingController(
      text: _firstNonEmptyText([
        seed["name"],
        partnerData["partner_name"],
        partnerData["name"],
      ]),
    );
    final noteTEC = TextEditingController(
      text: _firstNonEmptyText([
        seed["note"],
      ]),
    );
    var transactionDateTime =
        _dateTimeFromValue(seed["created_at"]) ?? DateTime.now();
    final dateTimeTEC = TextEditingController(
      text: _editableDateTimeLabel(transactionDateTime),
    );
    var isCredit = _isCreditTransaction(seed);
    var isSaving = false;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useSafeArea: false,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              title: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF030744),
                ),
              ),
              content: SizedBox(
                width: min(mediaQuery.size.width, 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFieldWidget(
                      controller: nameTEC,
                      labelText: "Name",
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: _panelGap),
                    TextFieldWidget(
                      controller: amountTEC,
                      labelText: "Amount",
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: _panelGap),
                    DropdownButtonFormField<String>(
                      initialValue: isCredit ? "credit" : "debit",
                      decoration: _dropdownDecoration(
                        label: "Type",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "credit",
                          child: Text("Credit"),
                        ),
                        DropdownMenuItem(
                          value: "debit",
                          child: Text("Debit"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          isCredit = value == "credit";
                        });
                      },
                    ),
                    const SizedBox(height: _panelGap),
                    _buildSelectorField(
                      label: "Date Time",
                      value: dateTimeTEC.text,
                      onTap: () async {
                        final picked = await _pickDateTime(transactionDateTime);
                        if (picked == null) {
                          return;
                        }
                        setStateDialog(() {
                          transactionDateTime = picked;
                          dateTimeTEC.text =
                              _editableDateTimeLabel(transactionDateTime);
                        });
                      },
                    ),
                    const SizedBox(height: _panelGap),
                    TextFieldWidget(
                      controller: noteTEC,
                      labelText: "Note",
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              actions: [
                _dialogActionButton(
                  text: "Cancel",
                  onTap: isSaving ? null : () => Navigator.pop(context),
                ),
                _dialogActionButton(
                  text: isSaving ? "Saving..." : "Save",
                  onTap: isSaving
                      ? null
                      : () async {
                          setStateDialog(() {
                            isSaving = true;
                          });
                          try {
                            await _savePartnerTransaction(
                              partnerId: partnerId,
                              partnerData: partnerData,
                              transactionId: transactionId,
                              data: {
                                ...seed,
                                "name": nameTEC.text.trim(),
                                "amount": _toDouble(amountTEC.text),
                                "is_credit": isCredit,
                                "created_at":
                                    transactionDateTime.toIso8601String(),
                                "note": noteTEC.text.trim(),
                              },
                            );
                            if (!mounted) return;
                            Navigator.of(this.context).pop();
                            _showSuccessSnack(
                              transactionId == null
                                  ? "Partner transaction added."
                                  : "Partner transaction updated.",
                            );
                          } catch (e) {
                            if (!mounted) return;
                            _showErrorSnack("$e");
                            setStateDialog(() {
                              isSaving = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
    amountTEC.dispose();
    nameTEC.dispose();
    dateTimeTEC.dispose();
    noteTEC.dispose();
  }

  Future<void> _showDriverTransactionDialog({
    required String title,
    required String driverId,
    required Map<String, dynamic> driverData,
    String? transactionId,
    Map<String, dynamic>? initialData,
  }) async {
    final seed = initialData ??
        _driverTransactionTemplate(driverId: driverId, driverData: driverData);
    final amountTEC = TextEditingController(
      text: _toDouble(seed["amount"]) > 0
          ? _toDouble(seed["amount"]).toStringAsFixed(0)
          : "",
    );
    final nameTEC = TextEditingController(
      text: _firstNonEmptyText([
        seed["name"],
        driverData["driver_name"],
        driverData["name"],
      ]),
    );
    final noteTEC = TextEditingController(
      text: _firstNonEmptyText([
        seed["note"],
      ]),
    );
    var transactionDateTime =
        _dateTimeFromValue(seed["created_at"]) ?? DateTime.now();
    final dateTimeTEC = TextEditingController(
      text: _editableDateTimeLabel(transactionDateTime),
    );
    var isCredit = _isCreditTransaction(seed);
    var isSaving = false;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useSafeArea: false,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              title: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF030744),
                ),
              ),
              content: SizedBox(
                width: min(mediaQuery.size.width, 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFieldWidget(
                      controller: nameTEC,
                      labelText: "Name",
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: _panelGap),
                    TextFieldWidget(
                      controller: amountTEC,
                      labelText: "Amount",
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: _panelGap),
                    DropdownButtonFormField<String>(
                      initialValue: isCredit ? "credit" : "debit",
                      decoration: _dropdownDecoration(
                        label: "Type",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "credit",
                          child: Text("Credit"),
                        ),
                        DropdownMenuItem(
                          value: "debit",
                          child: Text("Debit"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          isCredit = value == "credit";
                        });
                      },
                    ),
                    const SizedBox(height: _panelGap),
                    _buildSelectorField(
                      label: "Date Time",
                      value: dateTimeTEC.text,
                      onTap: () async {
                        final picked = await _pickDateTime(transactionDateTime);
                        if (picked == null) {
                          return;
                        }
                        setStateDialog(() {
                          transactionDateTime = picked;
                          dateTimeTEC.text =
                              _editableDateTimeLabel(transactionDateTime);
                        });
                      },
                    ),
                    const SizedBox(height: _panelGap),
                    TextFieldWidget(
                      controller: noteTEC,
                      labelText: "Note",
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              actions: [
                _dialogActionButton(
                  text: "Cancel",
                  onTap: isSaving ? null : () => Navigator.pop(context),
                ),
                _dialogActionButton(
                  text: isSaving ? "Saving..." : "Save",
                  onTap: isSaving
                      ? null
                      : () async {
                          setStateDialog(() {
                            isSaving = true;
                          });
                          try {
                            await _saveDriverTransaction(
                              driverId: driverId,
                              driverData: driverData,
                              transactionId: transactionId,
                              data: {
                                ...seed,
                                "name": nameTEC.text.trim(),
                                "amount": _toDouble(amountTEC.text),
                                "is_credit": isCredit,
                                "created_at":
                                    transactionDateTime.toIso8601String(),
                                "note": noteTEC.text.trim(),
                              },
                            );
                            if (!mounted) return;
                            Navigator.of(this.context).pop();
                            _showSuccessSnack(
                              transactionId == null
                                  ? "Driver transaction added."
                                  : "Driver transaction updated.",
                            );
                          } catch (e) {
                            if (!mounted) return;
                            _showErrorSnack("$e");
                            setStateDialog(() {
                              isSaving = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
    amountTEC.dispose();
    nameTEC.dispose();
    dateTimeTEC.dispose();
    noteTEC.dispose();
  }

  Future<void> _savePartnerTransaction({
    required String partnerId,
    required Map<String, dynamic> partnerData,
    String? transactionId,
    required Map<String, dynamic> data,
  }) async {
    final partnerRef = fbStore.collection("partners").doc(partnerId);
    final isCredit = _isCreditTransaction(data);
    final amount = _toDouble(data["amount"]);
    if (amount <= 0) {
      throw "Transaction amount must be greater than zero.";
    }
    final timestamp = _timestampNow();
    final createdAt = _timestampFromValue(data["created_at"]) ?? timestamp;
    final createdAtDate = createdAt.toDate();
    final collection = partnerRef.collection("transactions_v2");
    Map<String, dynamic>? previousTransactionData;
    if (transactionId != null) {
      final previousSnapshot = await collection.doc(transactionId).get();
      previousTransactionData = previousSnapshot.data();
    }
    final nextDocId = await _resolveTransactionV2DocId(
      collection: collection,
      baseId: _transactionV2DocIdFromDate(createdAtDate),
      currentId: transactionId,
    );
    final normalized = <String, dynamic>{
      "note": _firstNonEmptyText([data["note"]]),
      "name": _firstNonEmptyText([
        data["name"],
        partnerData["partner_name"],
        partnerData["name"],
      ]),
      "amount": amount,
      "is_credit": isCredit,
      "created_at": createdAt,
    };
    final transactionRef = collection.doc(nextDocId);
    final batch = fbStore.batch();
    batch.set(transactionRef, normalized, SetOptions(merge: true));
    if (transactionId != null && transactionId != nextDocId) {
      batch.delete(partnerRef.collection("transactions_v2").doc(transactionId));
    }
    await batch.commit();
    await _updatePartnerAggregateForTransactionChange(
      partnerId: partnerId,
      partnerData: partnerData,
      oldTransactionData: previousTransactionData,
      newTransactionData: normalized,
    );
  }

  Future<void> _deletePartnerTransaction({
    required String partnerId,
    required String transactionId,
  }) async {
    final partnerRef = fbStore.collection("partners").doc(partnerId);
    final partnerSnapshot = await partnerRef.get();
    final partnerData = partnerSnapshot.data() ?? {};
    final transactionSnapshot =
        await partnerRef.collection("transactions_v2").doc(transactionId).get();
    final previousTransactionData = transactionSnapshot.data();
    final batch = fbStore.batch();
    batch.delete(partnerRef.collection("transactions_v2").doc(transactionId));
    await batch.commit();
    await _updatePartnerAggregateForTransactionChange(
      partnerId: partnerId,
      partnerData: partnerData,
      oldTransactionData: previousTransactionData,
    );
  }

  Future<void> _saveDriverTransaction({
    required String driverId,
    required Map<String, dynamic> driverData,
    String? transactionId,
    required Map<String, dynamic> data,
  }) async {
    final isCredit = _isCreditTransaction(data);
    final amount = _toDouble(data["amount"]);
    if (amount <= 0) {
      throw "Transaction amount must be greater than zero.";
    }
    final createdAt =
        _timestampFromValue(data["created_at"]) ?? _timestampNow();
    final driverRef = fbStore.collection("drivers").doc(driverId);
    final collection = driverRef.collection("transactions_v2");
    Map<String, dynamic>? previousTransactionData;
    if (transactionId != null) {
      final previousSnapshot = await collection.doc(transactionId).get();
      previousTransactionData = previousSnapshot.data();
    }
    final nextDocId = await _resolveTransactionV2DocId(
      collection: collection,
      baseId: _transactionV2DocIdFromDate(createdAt.toDate()),
      currentId: transactionId,
    );
    final normalized = <String, dynamic>{
      "note": _firstNonEmptyText([data["note"]]),
      "name": _firstNonEmptyText([
        data["name"],
        driverData["driver_name"],
        driverData["name"],
      ]),
      "amount": amount,
      "is_credit": isCredit,
      "created_at": createdAt,
    };

    final transactionRef = collection.doc(nextDocId);
    final batch = fbStore.batch();
    if (transactionId != null && transactionId != nextDocId) {
      batch.delete(driverRef.collection("transactions_v2").doc(transactionId));
    }
    batch.set(transactionRef, normalized, SetOptions(merge: true));
    await batch.commit();
    await _updateDriverAggregateForTransactionChange(
      driverId: driverId,
      driverData: driverData,
      oldTransactionData: previousTransactionData,
      newTransactionData: normalized,
    );
  }

  Future<void> _deleteDriverTransaction({
    required String driverId,
    required String transactionId,
  }) async {
    final driverRef = fbStore.collection("drivers").doc(driverId);
    final driverSnapshot = await driverRef.get();
    final driverData = driverSnapshot.data() ?? {};
    final transactionSnapshot =
        await driverRef.collection("transactions_v2").doc(transactionId).get();
    final previousTransactionData = transactionSnapshot.data();
    final batch = fbStore.batch();
    batch.delete(driverRef.collection("transactions_v2").doc(transactionId));
    await batch.commit();
    await _updateDriverAggregateForTransactionChange(
      driverId: driverId,
      driverData: driverData,
      oldTransactionData: previousTransactionData,
    );
  }

  Widget _buildInlineStat(
    String label,
    String value, {
    Color color = const Color(0xFF030744),
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 6),
      child: Text(
        "$label: $value",
        style: TextStyle(
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    final isDarkButton = color != Colors.white;
    return Container(
      width: double.infinity,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(
          color: const Color(0xFF030744),
        ),
      ),
      child: WidgetButton(
        onTap: onTap,
        borderRadius: _panelRadius,
        mainColor: color,
        useDefaultHoverColor: true,
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isDarkButton ? Colors.white : const Color(0xFF030744),
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
    Color titleColor = const Color(0xFF030744),
    Color iconColor = const Color(0xFF030744),
  }) {
    return WidgetButton(
      onTap: onTap,
      borderRadius: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _panelOuterGap,
          10,
          _panelOuterGap,
          4,
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
                    style: TextStyle(
                      height: 1,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
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
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSwitch({
    int? partnerCount,
    int? driverCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(
          color: const Color(0xFF030744),
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
                    "Partners${partnerCount == null ? "" : " ($partnerCount)"}",
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
                    "Drivers${driverCount == null ? "" : " ($driverCount)"}",
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

  Widget _buildTransactionHistoryList({
    required String title,
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String amountKey,
    required VoidCallback onAdd,
    required Future<void> Function(
      String transactionId,
      Map<String, dynamic> data,
    ) onEdit,
    required Future<void> Function(
      String transactionId,
      Map<String, dynamic> data,
    ) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  height: 1,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF030744),
                ),
              ),
            ),
            WidgetButton(
              onTap: onAdd,
              borderRadius: 8,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: Icon(
                    Icons.add,
                    size: 20,
                    color: Color(0xFF030744),
                  ),
                ),
              ),
            ),
          ],
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
                    .where(
                      (doc) =>
                          _toDouble(
                            doc.data()[amountKey] ?? doc.data()["amount"],
                          ) >
                          0,
                    )
                    .toList()
                : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (docs.isEmpty) {
              return const Text(
                "No history yet.",
                style: TextStyle(
                  color: Color(0xFF030744),
                ),
              );
            }
            return Column(
              children: docs.take(10).map((doc) {
                final data = doc.data();
                final isCredit = _isCreditTransaction(data);
                final amount = _toDouble(data[amountKey] ?? data["amount"]);
                final actorName = _firstNonEmptyText([
                  data["name"],
                  isCredit ? "Credit" : "Debit",
                ]);
                final transactionLabel = _firstNonEmptyText([
                  data["note"],
                ]);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(12),
                      ),
                      border: Border.all(
                        width: 1,
                        color: const Color(0xFF030744).withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                actorName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  height: 1.1,
                                  fontSize: 14,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "${isCredit ? "+" : "-"} ${_formatMoney(amount)}",
                              style: TextStyle(
                                height: 1,
                                fontSize: 14,
                                color: isCredit
                                    ? Colors.green.shade700
                                    : Colors.red.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            WidgetButton(
                              onTap: () {
                                onEdit(doc.id, data);
                              },
                              borderRadius: 8,
                              child: const SizedBox(
                                width: 28,
                                height: 28,
                                child: Center(
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Color(0xFF030744),
                                  ),
                                ),
                              ),
                            ),
                            WidgetButton(
                              onTap: () {
                                onDelete(doc.id, data);
                              },
                              borderRadius: 8,
                              child: const SizedBox(
                                width: 28,
                                height: 28,
                                child: Center(
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Color(0xFF030744),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                transactionLabel,
                                style: const TextStyle(
                                  height: 1,
                                  fontSize: 14,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _formatTimestamp(data["created_at"]),
                              style: const TextStyle(
                                height: 1,
                                fontSize: 14,
                                color: Color(0xFF030744),
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                        const SizedBox(height: 16),
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

  Widget _buildQuickPartnerSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            TextFieldWidget(
              controller: _userIdTEC,
              labelText: "Search Name or User ID",
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _quickPartnerSearchVersion++;
                  _quickPartnerUserData = null;
                  _quickPartnerUserId = null;
                  _quickPartnerNameTEC.clear();
                  _markupTEC.clear();
                  _quickPaymentMode = "load";
                  _quickPartnerSearchResults = [];
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
                  children: _quickPartnerSearchResults.take(6).map((userData) {
                    final userId = "${userData["id"] ?? ""}";
                    final userName = capitalizeWords(
                      "${userData["name"] ?? "Unnamed User"}",
                      alt: "Unnamed User",
                    );
                    return WidgetButton(
                      onTap: () => _selectQuickPartner(userData),
                      borderRadius: 0,
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
                                color: Color(0xFF030744),
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
                        color: Color(0xFF030744),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _panelGap),
              TextFieldWidget(
                controller: _quickPartnerNameTEC,
                labelText: "Partner Name",
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  setState(() {
                    if (_quickPartnerUserData == null) {
                      return;
                    }
                    final normalizedName = value.trim().isEmpty
                        ? null
                        : capitalizeWords(value, alt: value);
                    _quickPartnerUserData = {
                      ...?_quickPartnerUserData,
                      "partner_name": normalizedName,
                      "name": normalizedName,
                    };
                  });
                },
              ),
              const SizedBox(height: _panelGap),
              TextFieldWidget(
                controller: _markupTEC,
                labelText: "Markup Amount",
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
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
              _buildPrimaryButton(
                text: _isSavingQuickSettings
                    ? "Saving..."
                    : "Save Partner Settings",
                onTap: _isSavingQuickSettings ? () {} : _saveQuickSettings,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCompactListControls({
    required TextEditingController controller,
    required String hintText,
    required bool isDriver,
  }) {
    return TextFieldWidget(
      controller: controller,
      labelText: hintText,
      textInputAction: TextInputAction.search,
      onChanged: (_) {
        _scheduleListSearchRefresh(isDriver: isDriver);
      },
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
          isDriver: false,
        ),
        const SizedBox(height: _panelGap),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fbStore.collection("partners").snapshots(),
          builder: (context, partnerSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fbStore
                  .collection("users")
                  .orderBy("partner_name")
                  .startAt([""]).snapshots(),
              builder: (context, userSnapshot) {
                if ((partnerSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !partnerSnapshot.hasData) ||
                    (userSnapshot.connectionState == ConnectionState.waiting &&
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
                  userSettingDocs: userSnapshot.hasData
                      ? userSnapshot.data!.docs
                      : <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                );

                _ensurePartnerUsersLoadedAfterBuild(
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

                final duplicateNameCounts = <String, int>{};
                for (final entry in entries) {
                  final partnerId = "${entry["partnerId"]}";
                  final partnerData =
                      entry["partnerData"] as Map<String, dynamic>? ?? {};
                  final inferredUserData =
                      entry["userData"] as Map<String, dynamic>?;
                  final userData =
                      inferredUserData ?? _partnerUserCache[partnerId];
                  final normalizedName = _normalizePartnerName(
                    _partnerDisplayName(
                      partnerId: partnerId,
                      partnerData: partnerData,
                      userData: userData,
                    ),
                  );
                  duplicateNameCounts[normalizedName] =
                      (duplicateNameCounts[normalizedName] ?? 0) + 1;
                }

                if (entries.isEmpty) {
                  return const Text(
                    "No partners found.",
                    style: TextStyle(
                      color: Color(0xFF030744),
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
                    final isExpanded = _expandedPartnerIds.contains(partnerId);
                    final normalizedName = _normalizePartnerName(
                      _partnerDisplayName(
                        partnerId: partnerId,
                        partnerData: partnerData,
                        userData: userData,
                      ),
                    );
                    final isDuplicate =
                        (duplicateNameCounts[normalizedName] ?? 0) > 1;
                    final accentColor =
                        isDuplicate ? Colors.red : const Color(0xFF030744);
                    return Padding(
                      key: ValueKey("partner-$partnerId"),
                      padding: const EdgeInsets.only(bottom: _panelOuterGap),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(_panelRadius),
                          border: Border.all(
                            color: isDuplicate
                                ? accentColor
                                : const Color(0xFF030744)
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    children: [
                                      _buildInlineStat(
                                        "User ID",
                                        partnerId,
                                        color: accentColor,
                                      ),
                                      _buildInlineStat(
                                        "Payment",
                                        capitalizeWords(
                                          "${userData?["payment_mode"] ?? "cash"}",
                                        ),
                                        color: accentColor,
                                      ),
                                      _buildInlineStat(
                                        "Markup",
                                        userData != null
                                            ? _formatMoney(
                                                userData["markup_amount"],
                                              )
                                            : _loadingPartnerUserIds
                                                    .contains(partnerId)
                                                ? "Loading..."
                                                : _formatMoney(0),
                                        color: accentColor,
                                      ),
                                      _buildInlineStat(
                                        "Today",
                                        _formatMoney(
                                          partnerData["today_amount"],
                                        ),
                                        color: accentColor,
                                      ),
                                      _buildInlineStat(
                                        _currentMonthLabel(),
                                        _formatMoney(
                                          partnerData["month_amount"],
                                        ),
                                        color: accentColor,
                                      ),
                                      _buildInlineStat(
                                        "All Time",
                                        _formatMoney(
                                          partnerData["total_amount"],
                                        ),
                                        color: accentColor,
                                      ),
                                      _buildInlineStat(
                                        "Claimable",
                                        _formatMoney(
                                          partnerData[
                                              "claimable_cash_markup_amount"],
                                        ),
                                        color: accentColor,
                                      ),
                                      _buildInlineStat(
                                        "Claimed",
                                        _formatMoney(
                                          partnerData[
                                              "claimed_cash_markup_amount"],
                                        ),
                                        color: accentColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              isExpanded: isExpanded,
                              titleColor: accentColor,
                              iconColor: accentColor,
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
                                    const SizedBox(height: 8),
                                    _buildPrimaryButton(
                                      text: "Edit Partner",
                                      onTap: () {
                                        _showEditPartnerDialog(
                                          partnerId: partnerId,
                                          partnerData: partnerData,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: _panelGap),
                                    _buildTransactionHistoryList(
                                      title: "Transactions",
                                      stream: fbStore
                                          .collection("partners")
                                          .doc(partnerId)
                                          .collection("transactions_v2")
                                          .snapshots(),
                                      amountKey: "amount",
                                      onAdd: () {
                                        _showPartnerTransactionDialog(
                                          title: "Add Partner Transaction",
                                          partnerId: partnerId,
                                          partnerData: partnerData,
                                        );
                                      },
                                      onEdit: (transactionId, data) async {
                                        await _showPartnerTransactionDialog(
                                          title: "Edit Partner Transaction",
                                          partnerId: partnerId,
                                          partnerData: partnerData,
                                          transactionId: transactionId,
                                          initialData: data,
                                        );
                                      },
                                      onDelete: (transactionId, data) async {
                                        final confirmed =
                                            await showDialog<bool>(
                                                  context: context,
                                                  barrierColor: Colors.black
                                                      .withValues(alpha: 0.5),
                                                  useSafeArea: false,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          Colors.white,
                                                      title: const Text(
                                                        "Delete Transaction?",
                                                      ),
                                                      content: const Text(
                                                        "This will remove the partner transaction and any linked claim record.",
                                                      ),
                                                      actions: [
                                                        _dialogActionButton(
                                                          text: "Cancel",
                                                          onTap: () =>
                                                              Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                        ),
                                                        _dialogActionButton(
                                                          text: "Delete",
                                                          onTap: () =>
                                                              Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ) ??
                                                false;
                                        if (!confirmed) {
                                          return;
                                        }
                                        await _deletePartnerTransaction(
                                          partnerId: partnerId,
                                          transactionId: transactionId,
                                        );
                                        if (!mounted) {
                                          return;
                                        }
                                        _showSuccessSnack(
                                          "Partner transaction removed.",
                                        );
                                      },
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
          isDriver: true,
        ),
        const SizedBox(height: _panelGap),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fbStore.collection("partners").snapshots(),
          builder: (context, partnerSnapshot) {
            final partnerIds = partnerSnapshot.hasData
                ? partnerSnapshot.data!.docs.map((doc) => doc.id).toSet()
                : <String>{};
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fbStore.collection("drivers").snapshots(),
              builder: (context, snapshot) {
                if (((partnerSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !partnerSnapshot.hasData) ||
                    (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData))) {
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
                  final driverId = "${data["driver_id"] ?? doc.id}";
                  if ((partnerIds.contains(doc.id) ||
                          partnerIds.contains(driverId)) &&
                      !_hasDriverIdentity(data)) {
                    return false;
                  }
                  final deductible =
                      _toDouble(data["deductible_cash_markup_amount"]);
                  final deducted =
                      _toDouble(data["deducted_cash_markup_amount"]);
                  final hasMarkup = deductible > 0 || deducted > 0;
                  if (!hasMarkup && !_hasDriverIdentity(data)) {
                    return false;
                  }
                  if (query.isEmpty) {
                    return true;
                  }
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
                  final aDeductible =
                      _toDouble(aData["deductible_cash_markup_amount"]);
                  final bDeductible =
                      _toDouble(bData["deductible_cash_markup_amount"]);
                  final deductibleDiff = bDeductible.compareTo(aDeductible);
                  if (deductibleDiff != 0) {
                    return deductibleDiff;
                  }
                  final aDeducted =
                      _toDouble(aData["deducted_cash_markup_amount"]);
                  final bDeducted =
                      _toDouble(bData["deducted_cash_markup_amount"]);
                  final deductedDiff = bDeducted.compareTo(aDeducted);
                  if (deductedDiff != 0) {
                    return deductedDiff;
                  }
                  final aName = _normalizedSortText(
                    _firstNonEmptyText([
                      aData["driver_name"],
                      aData["name"],
                      a.id,
                    ]),
                  );
                  final bName = _normalizedSortText(
                    _firstNonEmptyText([
                      bData["driver_name"],
                      bData["name"],
                      b.id,
                    ]),
                  );
                  final nameDiff = aName.compareTo(bName);
                  if (nameDiff != 0) {
                    return nameDiff;
                  }
                  return a.id.compareTo(b.id);
                });
                if (docs.isEmpty) {
                  return const Text(
                    "No driver markup records found.",
                    style: TextStyle(
                      color: Color(0xFF030744),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final driverId = "${data["driver_id"] ?? doc.id}";
                    final driverName = _firstNonEmptyText([
                      data["driver_name"],
                      data["name"],
                      "Driver",
                    ]);
                    final deductible =
                        _toDouble(data["deductible_cash_markup_amount"]);
                    final deducted =
                        _toDouble(data["deducted_cash_markup_amount"]);
                    return Padding(
                      key: ValueKey("driver-$driverId"),
                      padding: const EdgeInsets.only(bottom: _panelOuterGap),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(_panelRadius),
                          border: Border.all(
                            color:
                                const Color(0xFF030744).withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildExpandableRow(
                              title: capitalizeWords(
                                driverName,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    children: [
                                      _buildInlineStat(
                                        "Driver ID",
                                        driverId,
                                      ),
                                      _buildInlineStat(
                                        "Deductible",
                                        _formatMoney(deductible),
                                      ),
                                      _buildInlineStat(
                                        "Deducted",
                                        _formatMoney(deducted),
                                      ),
                                    ],
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
                                    const SizedBox(height: 8),
                                    _buildPrimaryButton(
                                      text: "Edit Driver",
                                      onTap: () {
                                        _showEditDriverDialog(
                                          driverId: driverId,
                                          driverData: data,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: _panelGap),
                                    _buildTransactionHistoryList(
                                      title: "Transactions",
                                      stream: fbStore
                                          .collection("drivers")
                                          .doc(driverId)
                                          .collection("transactions_v2")
                                          .snapshots(),
                                      amountKey: "amount",
                                      onAdd: () {
                                        _showDriverTransactionDialog(
                                          title: "Add Driver Transaction",
                                          driverId: driverId,
                                          driverData: data,
                                        );
                                      },
                                      onEdit: (transactionId, txData) async {
                                        await _showDriverTransactionDialog(
                                          title: "Edit Driver Transaction",
                                          driverId: driverId,
                                          driverData: data,
                                          transactionId: transactionId,
                                          initialData: txData,
                                        );
                                      },
                                      onDelete: (transactionId, txData) async {
                                        final confirmed =
                                            await showDialog<bool>(
                                                  context: context,
                                                  barrierColor: Colors.black
                                                      .withValues(alpha: 0.5),
                                                  useSafeArea: false,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          Colors.white,
                                                      title: const Text(
                                                        "Delete Transaction?",
                                                      ),
                                                      content: const Text(
                                                        "This will remove the driver transaction and any linked received/deducted record.",
                                                      ),
                                                      actions: [
                                                        _dialogActionButton(
                                                          text: "Cancel",
                                                          onTap: () =>
                                                              Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                        ),
                                                        _dialogActionButton(
                                                          text: "Delete",
                                                          onTap: () =>
                                                              Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ) ??
                                                false;
                                        if (!confirmed) {
                                          return;
                                        }
                                        await _deleteDriverTransaction(
                                          driverId: driverId,
                                          transactionId: transactionId,
                                        );
                                        if (!mounted) {
                                          return;
                                        }
                                        _showSuccessSnack(
                                          "Driver transaction removed.",
                                        );
                                      },
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
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: fbStore.collection("partners").snapshots(),
                builder: (context, partnerSnapshot) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: fbStore
                        .collection("users")
                        .orderBy("partner_name")
                        .startAt([""]).snapshots(),
                    builder: (context, userSnapshot) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: fbStore.collection("drivers").snapshots(),
                        builder: (context, driverSnapshot) {
                          final partnerDocs = partnerSnapshot.hasData
                              ? partnerSnapshot.data!.docs
                              : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                          final partnerEntries = _buildPartnerEntries(
                            partnerDocs: partnerDocs,
                            userSettingDocs: userSnapshot.hasData
                                ? userSnapshot.data!.docs
                                : <QueryDocumentSnapshot<
                                    Map<String, dynamic>>>[],
                          );
                          final partnerIds =
                              partnerDocs.map((doc) => doc.id).toSet();
                          final driverCount = _visibleDriverCount(
                            driverDocs: driverSnapshot.hasData
                                ? driverSnapshot.data!.docs
                                : <QueryDocumentSnapshot<
                                    Map<String, dynamic>>>[],
                            partnerIds: partnerIds,
                          );
                          return _buildSectionSwitch(
                            partnerCount: partnerEntries.length,
                            driverCount: driverCount,
                          );
                        },
                      );
                    },
                  );
                },
              ),
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
    final mediaQuery = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        _confirmLeavePartnerPanel();
      },
      child: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: EdgeInsets.only(
              top: mediaQuery.padding.top,
              bottom: 12,
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    WidgetButton(
                      onTap: _confirmLeavePartnerPanel,
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
                          fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
