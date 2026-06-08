// ignore_for_file: depend_on_referenced_packages

import 'dart:ui' as ui;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:pwa/view_models/chat.vm.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/order.request.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:pwa/widgets/camera_widget_shared.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pwa/widgets/quick_chat_pills.widget.dart';
import 'package:pwa/utils/web_viewport_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

class ChatView extends StatefulWidget {
  const ChatView(
    this.chatEntity,
    this.order, {
    this.readOnly = false,
    super.key,
  });

  final ChatEntity chatEntity;
  final Order order;
  final bool readOnly;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  static const int _chatUploadMaxLongSide = 1080;
  static const double _chatBubblePillTopPadding = 2;
  static const double _chatBubblePillHeight = 34;
  bool isMediaLoading = false;
  bool _isUpdatingRequestCancellation = false;
  bool _isUpdatingRequestPass = false;
  double _webKeyboardInset = 0;
  double _mobileKeyboardInset = 0;
  final WebViewportObserver _viewportObserver = WebViewportObserver();
  final TaxiRequest _taxiRequest = TaxiRequest();
  late TextEditingController _controller;
  late FocusNode _messageFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController();
    _messageFocusNode = FocusNode();
    _controller.addListener(_handleComposerChanged);
    _messageFocusNode.addListener(_handleComposerChanged);
    _mobileKeyboardInset = _currentKeyboardInset();
    if (widget.readOnly) {
      setChatFile(null);
    } else if (chatFileListenable.value != chatFile) {
      chatFileListenable.value = chatFile;
    }
    setChatViewOpen(true);
    _startVisualViewportListener();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final nextKeyboardInset = _currentKeyboardInset();
    if ((_mobileKeyboardInset - nextKeyboardInset).abs() < 0.5) {
      return;
    }
    if (mounted) {
      setState(() {
        _mobileKeyboardInset = nextKeyboardInset;
      });
    }
  }

  @override
  void dispose() {
    setChatViewOpen(false);
    WidgetsBinding.instance.removeObserver(this);
    _stopVisualViewportListener();
    _controller.removeListener(_handleComposerChanged);
    _messageFocusNode.removeListener(_handleComposerChanged);
    _controller.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    if (!_messageFocusNode.hasFocus) {
      if (_webKeyboardInset != 0) {
        _webKeyboardInset = 0;
      }
      if (_mobileKeyboardInset != 0) {
        _mobileKeyboardInset = 0;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  double _currentKeyboardInset() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.first;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  Future<Uint8List> _resizeChatImageBytesForUpload(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      final longSide = width > height ? width : height;

      if (longSide <= _chatUploadMaxLongSide) {
        return bytes;
      }

      final scale = _chatUploadMaxLongSide / longSide;
      final targetWidth = (width * scale).round();
      final targetHeight = (height * scale).round();
      final resizedCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final resizedImage = resizedFrame.image;
      final byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        return bytes;
      }

      final resizedBytes = byteData.buffer.asUint8List();
      return resizedBytes;
    } catch (_) {
      return bytes;
    }
  }

  void _startVisualViewportListener() {
    _viewportObserver.start((inset) {
      if (!mounted) {
        return;
      }
      if ((_webKeyboardInset - inset).abs() < 1) {
        return;
      }
      setState(() {
        _webKeyboardInset = inset;
      });
    });
  }

  void _stopVisualViewportListener() {
    _viewportObserver.stop();
  }

  Future<void> _sendTextMessage(
    ChatViewModel vm,
    String message,
  ) async {
    final trimmedMessage = message.trim();
    if (vm.isBusy || trimmedMessage.isEmpty || trimmedMessage == "null") {
      return;
    }

    await vm.sendMessage(
      ChatMessage(
        text: trimmedMessage,
        user: widget.chatEntity.mainUser!.toChatUser(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _controller.clear();
  }

  Future<void> _sendQuickChatText(
    ChatViewModel vm,
    String message, {
    bool isRequestCancellation = false,
    bool isRequestPass = false,
  }) async {
    final trimmedMessage = message.trim();
    if (widget.readOnly ||
        vm.isBusy ||
        trimmedMessage.isEmpty ||
        trimmedMessage == "null") {
      return;
    }
    final normalizedMessage = trimmedMessage.toLowerCase();
    final isCancellationRequest =
        isRequestCancellation || normalizedMessage == "request cancellation";
    final isPassRequest = isRequestPass || normalizedMessage == "request pass";
    if (isCancellationRequest || isPassRequest) {
      final orderSnapshot =
          await fbStore.collection("orders").doc(widget.order.code).get();
      final data = orderSnapshot.data();
      final cancelStatus =
          "${data?["cancel_request_status"] ?? ""}".trim().toLowerCase();
      final passStatus =
          "${data?["pass_request_status"] ?? ""}".trim().toLowerCase();
      if (isCancellationRequest && cancelStatus == "accepted") {
        return;
      }
      if (isPassRequest && passStatus == "accepted") {
        return;
      }
    }

    await fbStore.collection("orders").doc(widget.order.code).update(
      {
        "driverSeen": false,
        "userMessage": trimmedMessage,
        if (isCancellationRequest) "cancel_request_status": "pending",
        if (isPassRequest) "pass_request_status": "pending",
      },
    );
    await vm.sendMessage(
      ChatMessage(
        text: trimmedMessage,
        user: widget.chatEntity.mainUser!.toChatUser(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _controller.clear();
  }

  String? _requestMessageType(ChatMessage message) {
    final normalized = message.text.trim().toLowerCase();
    if (normalized == "request cancellation") {
      return "cancellation";
    }
    if (normalized == "request pass") {
      return "pass";
    }
    return null;
  }

  String _displayMessageText(ChatMessage message) {
    final requestType = _requestMessageType(message);
    if (requestType == "cancellation") {
      return "Request Cancellation";
    }
    if (requestType == "pass") {
      return "Request Pass";
    }
    return _displayContextualParticipantNames(message.text);
  }

  String _displayContextualParticipantNames(String text) {
    final driverName = (widget.order.driver?.name ?? "").trim();
    final currentUserName = (AuthService.currentUser?.name ?? "").trim();
    var displayText = _replaceDisplayName(
      text,
      name: driverName,
      plainReplacement: "your driver",
      possessiveReplacement: "your driver's",
    );
    displayText = _replaceDisplayName(
      displayText,
      name: currentUserName,
      plainReplacement: "you",
      possessiveReplacement: "your",
    );
    return _capitalizeLeadingContextReplacement(displayText);
  }

  String _replaceDisplayName(
    String text, {
    required String name,
    required String plainReplacement,
    required String possessiveReplacement,
  }) {
    if (name.isEmpty || name.toLowerCase() == "null") {
      return text;
    }

    final escapedName = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(RegExp.escape)
        .join(r'\s+');
    if (escapedName.isEmpty) {
      return text;
    }

    final possessivePattern = RegExp(
      "(^|[^A-Za-z0-9_])$escapedName['’]s\\b",
      caseSensitive: false,
    );
    final possessiveText = text.replaceAllMapped(
      possessivePattern,
      (match) => "${match.group(1) ?? ""}$possessiveReplacement",
    );
    final namePattern = RegExp(
      "(^|[^A-Za-z0-9_])$escapedName\\b",
      caseSensitive: false,
    );
    return possessiveText.replaceAllMapped(
      namePattern,
      (match) => "${match.group(1) ?? ""}$plainReplacement",
    );
  }

  String _capitalizeLeadingContextReplacement(String text) {
    if (text.startsWith("your driver")) {
      return "Your driver${text.substring(11)}";
    }
    if (text.startsWith("your")) {
      return "Your${text.substring(4)}";
    }
    if (text.startsWith("you")) {
      return "You${text.substring(3)}";
    }
    return text;
  }

  bool _canShowRequestCancellationPill(String? status) {
    final normalized = (status ?? "").trim().toLowerCase();
    return ![
      "enroute",
      "delivered",
      "completed",
      "successful",
      "cancelled",
    ].contains(normalized);
  }

  bool _isEnrouteOrBeyondStatus(String? status) {
    final normalized = (status ?? "").trim().toLowerCase();
    return [
      "enroute",
      "delivered",
      "completed",
      "successful",
      "cancelled",
    ].contains(normalized);
  }

  bool _shouldShowAcceptedCancelRequestActions(String? message) {
    final normalized = (message ?? "").trim().toLowerCase();
    return normalized.contains("has accepted") &&
        normalized.contains("cancel request");
  }

  int? get _currentOrderDriverId =>
      widget.order.driverId ?? widget.order.driver?.id;

  int _remainingCancelSecondsForOrder(Order? order) {
    final createdAt = order?.createdAt ?? order?.taxiOrder?.createdAt;
    if (createdAt == null) {
      return 0;
    }

    final cancelAvailableAt = createdAt.toLocal().add(
          const Duration(minutes: 5),
        );
    final remaining = cancelAvailableAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  int _remainingRebookSecondsForOrder(Order? order) {
    final createdAt = order?.createdAt ?? order?.taxiOrder?.createdAt;
    if (createdAt == null) {
      return 0;
    }

    final rebookAvailableAt = createdAt.toLocal().add(
          const Duration(minutes: 2),
        );
    final remaining = rebookAvailableAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Address? _orderPickupAddress() {
    final taxiOrder = widget.order.taxiOrder;
    final lat = taxiOrder?.pickupLatitude;
    final lng = taxiOrder?.pickupLongitude;
    if (taxiOrder == null || lat == null || lng == null) {
      return null;
    }
    return Address(
      addressLine: taxiOrder.pickupAddress,
      coordinates: Coordinates(lat, lng),
    );
  }

  Address? _orderDropoffAddress() {
    final taxiOrder = widget.order.taxiOrder;
    final lat = taxiOrder?.dropoffLatitude;
    final lng = taxiOrder?.dropoffLongitude;
    if (taxiOrder == null || lat == null || lng == null) {
      return null;
    }
    return Address(
      addressLine: taxiOrder.dropoffAddress,
      coordinates: Coordinates(lat, lng),
    );
  }

  void _showAcceptedCancelWaitSnackBar(int seconds) {
    ScaffoldMessenger.of(Get.context!).clearSnackBars();
    ScaffoldMessenger.of(Get.context!).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          "Please wait for $seconds second${seconds == 1 ? "" : "s"} or get a new driver now!",
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _otherChatParticipantName() {
    final currentUserId = "${AuthService.currentUser?.id ?? ''}";
    final otherPeer = widget.chatEntity.peers.entries
        .where((entry) => entry.key != currentUserId)
        .map((entry) => entry.value.name.trim())
        .firstWhere(
          (name) => name.isNotEmpty && name.toLowerCase() != "null",
          orElse: () => "Recipient",
        );
    return otherPeer;
  }

  double get _chatDriverSearchPickupKmLimit =>
      widget.order.driver?.vehicle?.vehicleType?.pickupKmLimit ??
      widget.order.taxiOrder?.vehicleType?.pickupKmLimit ??
      0.0;

  double get _chatDriverDistantPayableFare {
    return widget.order.total ?? 0;
  }

  double get _chatDriverDistantDialogBaseFare {
    final orderSubTotal = widget.order.subTotal ?? 0;
    if (orderSubTotal > 0) {
      return orderSubTotal;
    }
    return _chatDriverDistantPayableFare;
  }

  Future<void> _showDriverDistantDialogForRebook(
    ChatViewModel vm,
    availableDriver,
  ) async {
    final fareNotifier = ValueNotifier<double?>(_chatDriverDistantPayableFare);
    try {
      await AlertService().showDriverDistantDialog(
        availableDriver: availableDriver,
        totalAmountListenable: fareNotifier,
        originalFare: _chatDriverDistantDialogBaseFare,
        newBaseFare: _chatDriverDistantDialogBaseFare,
        onAccept: () async {
          await _submitAcceptedCancelRequestRebook(
            vm,
            availableDriver,
          );
        },
      );
    } finally {
      fareNotifier.dispose();
    }
  }

  Future<void> _submitAcceptedCancelRequestRebook(
    ChatViewModel vm,
    availableDriver,
  ) async {
    try {
      AlertService().showLoading();
      final apiResponse = await _taxiRequest.passOrderRequest(
        reason: "rebook",
        id: widget.order.id!,
        targetDriverId: availableDriver.driver!.id!,
      );
      if (!apiResponse.allGood) {
        throw apiResponse.message;
      }

      final orderCode = widget.order.code?.trim();
      if (orderCode != null && orderCode.isNotEmpty) {
        await fbStore.collection("orders").doc(orderCode).update(
          {
            "driver_accept_id": null,
            "driver_accept_latitude": null,
            "driver_accept_longitude": null,
            "userSeen": true,
          },
        );
      }

      final currentUserName = (widget.order.user?.name ?? "User").trim();
      final newDriverName = (availableDriver.driver?.name ?? "Driver").trim();
      if (newDriverName.isNotEmpty) {
        final message =
            "$currentUserName rebooked for a new driver and was assigned to $newDriverName!";
        await vm.sendMessage(
          ChatMessage(
            text: message,
            user: widget.chatEntity.mainUser!.toChatUser(),
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
      AlertService().stopLoading(forceStop: true);
    } catch (e) {
      AlertService().stopLoading(forceStop: true);
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _updateRequestStatus({
    required ChatViewModel vm,
    required String requestType,
    required String status,
  }) async {
    final isCancellation = requestType == "cancellation";
    final isPass = requestType == "pass";
    final isUpdating = isCancellation
        ? _isUpdatingRequestCancellation
        : _isUpdatingRequestPass;
    if (isUpdating) {
      return;
    }

    setState(() {
      if (isCancellation) {
        _isUpdatingRequestCancellation = true;
      } else if (isPass) {
        _isUpdatingRequestPass = true;
      }
    });
    try {
      await fbStore.collection("orders").doc(widget.order.code).update(
        {
          isCancellation ? "cancel_request_status" : "pass_request_status":
              status,
        },
      );
      final currentUserName = (AuthService.currentUser?.name ?? "User").trim();
      final otherParticipantName = _otherChatParticipantName();
      await vm.sendMessage(
        ChatMessage(
          text:
              "$currentUserName $status $otherParticipantName's ${isCancellation ? "cancel" : "pass"} request!",
          user: widget.chatEntity.mainUser!.toChatUser(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (isCancellation) {
            _isUpdatingRequestCancellation = false;
          } else if (isPass) {
            _isUpdatingRequestPass = false;
          }
        });
      }
    }
  }

  Future<void> _processAcceptedCancelRequestCancel() async {
    final orderSnapshot =
        await fbStore.collection("orders").doc(widget.order.code).get();
    final data = orderSnapshot.data();
    final cancelStatus =
        "${data?["cancel_request_status"] ?? ""}".trim().toLowerCase();
    final status =
        "${data?["status"] ?? widget.order.status ?? ""}".trim().toLowerCase();
    final canCancelWithAcceptedRequest =
        cancelStatus == "accepted" && !_isEnrouteOrBeyondStatus(status);
    final latestRemainingCancelSeconds =
        _remainingCancelSecondsForOrder(widget.order);
    if (!canCancelWithAcceptedRequest && latestRemainingCancelSeconds > 0) {
      _showAcceptedCancelWaitSnackBar(latestRemainingCancelSeconds);
      return;
    }

    if (AuthService.inReviewMode()) {
      Get.back();
      return;
    }

    Get.until((route) => route.isFirst);
    AlertService().showLoading();
    try {
      final apiResponse = await _taxiRequest.cancelOrderRequest(
        id: widget.order.id!,
        reason: "initiated by passenger",
        rebook: false,
      );
      final orderCode = widget.order.code?.trim();
      if (!apiResponse.allGood) {
        throw apiResponse.message;
      }
      AlertService().stopLoading(forceStop: true);
      if (orderCode != null && orderCode.isNotEmpty) {
        await fbStore.collection("orders").doc(orderCode).update(
          {
            "userSeen": true,
          },
        );
      }
    } catch (e) {
      AlertService().stopLoading(forceStop: true);
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _processAcceptedCancelRequestRebook(
    ChatViewModel vm,
  ) async {
    final orderSnapshot =
        await fbStore.collection("orders").doc(widget.order.code).get();
    final data = orderSnapshot.data();
    final cancelStatus =
        "${data?["cancel_request_status"] ?? ""}".trim().toLowerCase();
    final status =
        "${data?["status"] ?? widget.order.status ?? ""}".trim().toLowerCase();
    final canCancelWithAcceptedRequest =
        cancelStatus == "accepted" && !_isEnrouteOrBeyondStatus(status);
    final latestRemainingRebookSeconds =
        _remainingRebookSecondsForOrder(widget.order);
    if (!canCancelWithAcceptedRequest && latestRemainingRebookSeconds > 0) {
      _showAcceptedCancelWaitSnackBar(latestRemainingRebookSeconds);
      return;
    }

    final pickup = _orderPickupAddress();
    final dropoff = _orderDropoffAddress();
    final vehicleTypeId = widget.order.taxiOrder?.vehicleTypeId;
    if (pickup == null || dropoff == null || vehicleTypeId == null) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Unable to prepare this booking for rebook",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    Get.until((route) => route.isFirst);
    try {
      AlertService().showLoading();
      final availableDriver = await _taxiRequest.findAvailableDriver(
        pickup: pickup,
        dropoff: dropoff,
        vehicleTypeId: vehicleTypeId,
        types: const [],
      );
      if (availableDriver?.driver == null || availableDriver?.kmDistance == 0) {
        throw "No driver found. Try again later";
      }
      AlertService().stopLoading(forceStop: true);
      if ((availableDriver?.pickupKm ?? 0.0) <=
          _chatDriverSearchPickupKmLimit) {
        await _submitAcceptedCancelRequestRebook(
          vm,
          availableDriver!,
        );
      } else {
        await _showDriverDistantDialogForRebook(
          vm,
          availableDriver!,
        );
      }
    } catch (e) {
      AlertService().stopLoading(forceStop: true);
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  void _confirmAcceptedCancelRequestCancel() {
    AlertService().showAppAlert(
      asset: AppLotties.confirm,
      title: "Are you sure?",
      content: "Do you want to cancel this booking?",
      hideCancel: false,
      cancelText: "No",
      confirmText: "Yes",
      confirmColor: Colors.red,
      cancelAction: () async {
        Get.back();
      },
      confirmAction: () async {
        Get.back();
        await _processAcceptedCancelRequestCancel();
      },
    );
  }

  void _confirmAcceptedCancelRequestRebook(ChatViewModel vm) {
    AlertService().showAppAlert(
      asset: AppLotties.confirm,
      title: "Are you sure?",
      content: "Do you want to get a new driver now?",
      hideCancel: false,
      cancelText: "No",
      confirmText: "Yes",
      confirmColor: const Color(0xFF007BFF),
      cancelAction: () async {
        Get.back();
      },
      confirmAction: () async {
        Get.back();
        await _processAcceptedCancelRequestRebook(vm);
      },
    );
  }

  Widget _buildRequestStatus({
    required String requestType,
    Color color = Colors.white,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fbStore.collection("orders").doc(widget.order.code).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final statusKey = requestType == "cancellation"
            ? "cancel_request_status"
            : "pass_request_status";
        final rawStatus = "${data?[statusKey] ?? ""}".trim().toLowerCase();
        final status =
            rawStatus.isEmpty || rawStatus == "null" ? "pending" : rawStatus;
        final statusText = status == "accepted"
            ? "Accepted"
            : status == "pending"
                ? "Pending"
                : "Rejected";
        final textColor =
            color == Colors.white ? const Color(0xFF030744) : color;
        return Padding(
          padding: const EdgeInsets.only(top: _chatBubblePillTopPadding),
          child: IntrinsicWidth(
            child: Container(
              height: _chatBubblePillHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(
                  Radius.circular(1000),
                ),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.18),
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.15,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestActions({
    required ChatViewModel vm,
    required ChatMessage message,
    required String requestType,
    Color color = Colors.white,
  }) {
    if (widget.readOnly) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fbStore.collection("orders").doc(widget.order.code).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final currentUserId = "${AuthService.currentUser?.id ?? ''}";
        final statusKey = requestType == "cancellation"
            ? "cancel_request_status"
            : "pass_request_status";
        final rawStatus = "${data?[statusKey] ?? ""}".trim().toLowerCase();
        final status =
            rawStatus.isEmpty || rawStatus == "null" ? "pending" : rawStatus;
        final isSender =
            currentUserId.isNotEmpty && currentUserId == message.user.id;
        final isUpdating = requestType == "cancellation"
            ? _isUpdatingRequestCancellation
            : _isUpdatingRequestPass;

        if (isSender || status != "pending") {
          return _buildRequestStatus(
            requestType: requestType,
            color: color,
          );
        }

        Widget buildActionButton({
          required String label,
          required String status,
          required bool showLoading,
        }) {
          return Padding(
            padding: const EdgeInsets.only(top: _chatBubblePillTopPadding),
            child: IntrinsicWidth(
              child: SizedBox(
                height: _chatBubblePillHeight,
                child: WidgetButton(
                  onTap: isUpdating
                      ? () {}
                      : () async {
                          await _updateRequestStatus(
                            vm: vm,
                            requestType: requestType,
                            status: status,
                          );
                        },
                  mainColor: Colors.white,
                  interactionColor: color.withValues(alpha: 0.12),
                  borderRadius: 1000,
                  useDefaultHoverColor: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: showLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: color,
                              ),
                            )
                          : Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildActionButton(
              label: "Reject",
              status: "rejected",
              showLoading: isUpdating,
            ),
            const SizedBox(width: 8),
            buildActionButton(
              label: "Accept",
              status: "accepted",
              showLoading: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAcceptedCancelRequestPills(ChatViewModel vm) {
    Widget buildPill({
      required String label,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(top: _chatBubblePillTopPadding),
        child: IntrinsicWidth(
          child: WidgetButton(
            onTap: onTap,
            mainColor: color.withValues(alpha: 0.08),
            interactionColor: color.withValues(alpha: 0.18),
            useDefaultHoverColor: false,
            borderRadius: 1000,
            child: Container(
              height: _chatBubblePillHeight,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(1000),
                ),
                border: Border.all(
                  color: color.withValues(alpha: 0.18),
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: _chatBubblePillHeight + _chatBubblePillTopPadding,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return buildPill(
              label: "Cancel",
              color: Colors.red,
              onTap: _confirmAcceptedCancelRequestCancel,
            );
          }
          return buildPill(
            label: "Get a new driver now!",
            color: const Color(0xFF007BFF),
            onTap: () {
              _confirmAcceptedCancelRequestRebook(vm);
            },
          );
        },
      ),
    );
  }

  Widget _buildAcceptedCancelRequestActions({
    required ChatViewModel vm,
    required ChatMessage message,
  }) {
    if (widget.readOnly) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fbStore.collection("orders").doc(widget.order.code).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final currentUserId = "${AuthService.currentUser?.id ?? ''}";
        final isSender =
            currentUserId.isNotEmpty && currentUserId == message.user.id;
        final normalizedMessage = message.text.trim().toLowerCase();
        final firestoreDriverId = "${data?["driver_id"] ?? ""}".trim();
        final orderDriverId = "${_currentOrderDriverId ?? ""}".trim();
        final cancelStatus =
            "${data?["cancel_request_status"] ?? ""}".trim().toLowerCase();
        final sameDriver = firestoreDriverId.isNotEmpty &&
            firestoreDriverId.toLowerCase() != "null" &&
            orderDriverId.isNotEmpty &&
            firestoreDriverId == orderDriverId;

        if (isSender ||
            !normalizedMessage.contains("has accepted") ||
            !normalizedMessage.contains("cancel request") ||
            !sameDriver ||
            cancelStatus != "accepted") {
          return const SizedBox.shrink();
        }

        return _buildAcceptedCancelRequestPills(vm);
      },
    );
  }

  String? _messageImageUrl(ChatMessage message) {
    final text = message.text.trim();
    if (text.contains("https")) {
      return text;
    }
    if (message.medias != null && message.medias!.isNotEmpty) {
      final mediaUrl = message.medias!.first.url.trim();
      if (mediaUrl.isNotEmpty && mediaUrl.toLowerCase() != "null") {
        return mediaUrl;
      }
    }
    return null;
  }

  bool _messageHasVisibleContent(ChatMessage message) {
    final text = message.text.trim();
    if (text.isNotEmpty && text.toLowerCase() != "null") {
      return true;
    }
    return _messageImageUrl(message) != null;
  }

  bool _canShowTextActions(ChatMessage message) {
    final text = message.text.trim();
    return text.isNotEmpty &&
        text.toLowerCase() != "null" &&
        !isPhotoUrlMessage(text) &&
        _requestMessageType(message) == null;
  }

  Widget _buildChatImage(
    BuildContext context,
    String imageUrl,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final availableWidth = mediaQuery.size.width - 124;
    final width = availableWidth < 240 ? availableWidth : 240.0;
    final height = width * (260 / 240);
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.circular(8),
      ),
      child: NetworkImageWidget(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: 900,
      ),
    );
  }

  Widget _buildImageTimeBadge(DateTime createdAt) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(5),
        ),
        color: Colors.black.withValues(alpha: 0.5),
      ),
      child: Text(
        DateFormat(
          "h:mm a",
        ).format(createdAt),
        style: const TextStyle(
          height: 1.15,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showNetworkImagePreview(String? imageUrl, {int memCacheWidth = 900}) {
    final resolvedImageUrl = (imageUrl ?? "").trim();
    if (resolvedImageUrl.isEmpty || resolvedImageUrl.toLowerCase() == "null") {
      return;
    }

    AlertService().showAppAlert(
      isCustom: true,
      customWidget: PinchZoom(
        child: NetworkImageWidget(
          imageUrl: resolvedImageUrl,
          memCacheWidth: memCacheWidth,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _showMemoryImagePreview(Uint8List imageBytes) {
    if (imageBytes.isEmpty) {
      return;
    }

    AlertService().showAppAlert(
      isCustom: true,
      customWidget: PinchZoom(
        child: Image.memory(
          imageBytes,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  String? _philippineMobileNumberFromMessage(String messageText) {
    final matches = RegExp(
      r'(?:\+?63|0)?9(?:[\s\-.()]*\d){9}',
    ).allMatches(messageText);

    for (final match in matches) {
      final rawNumber = match.group(0) ?? "";
      final digits = rawNumber.replaceAll(RegExp(r'\D'), "");
      if (digits.length == 12 && digits.startsWith("639")) {
        return "+$digits";
      }
      if (digits.length == 11 && digits.startsWith("09")) {
        return "+63${digits.substring(1)}";
      }
      if (digits.length == 10 && digits.startsWith("9")) {
        return "+63$digits";
      }
    }

    return null;
  }

  Widget _buildCallPhonePill(String phoneNumber) {
    const color = Color(0xFF007BFF);
    return Padding(
      padding: const EdgeInsets.only(top: _chatBubblePillTopPadding),
      child: IntrinsicWidth(
        child: WidgetButton(
          onTap: () async {
            await launchUrlString("tel:$phoneNumber");
          },
          mainColor: color.withValues(alpha: 0.08),
          interactionColor: color.withValues(alpha: 0.18),
          useDefaultHoverColor: false,
          borderRadius: 1000,
          child: Container(
            height: _chatBubblePillHeight,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(
                Radius.circular(1000),
              ),
              border: Border.all(
                color: color.withValues(alpha: 0.18),
              ),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.call,
                      size: 14,
                      color: color,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "Call",
                      style: TextStyle(
                        height: 1.15,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMessageActionsSheet(String messageText) async {
    final trimmedMessage = messageText.trim();
    if (trimmedMessage.isEmpty || trimmedMessage.toLowerCase() == "null") {
      return;
    }
    final phoneNumber = _philippineMobileNumberFromMessage(trimmedMessage);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(1000),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  trimmedMessage,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(height: 16),
              WidgetButton(
                borderRadius: 0,
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: trimmedMessage),
                  );
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                  if (!mounted) {
                    return;
                  }
                  showSuccess("Copied to clipboard.", context: context);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded),
                      SizedBox(width: 16),
                      Text("Copy"),
                    ],
                  ),
                ),
              ),
              if (phoneNumber != null)
                WidgetButton(
                  borderRadius: 0,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await launchUrlString("tel:$phoneNumber");
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.call_outlined),
                        SizedBox(width: 16),
                        Text("Call"),
                      ],
                    ),
                  ),
                ),
              WidgetButton(
                borderRadius: 0,
                onTap: () {
                  Navigator.pop(sheetContext);
                },
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded),
                      SizedBox(width: 16),
                      Text("Close"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasPendingChatDraft() {
    final message = _controller.text.trim();
    return (message.isNotEmpty && message != "null") ||
        chatFileListenable.value != null ||
        chatFile != null;
  }

  String _chatImageUploadErrorMessage(Object error) {
    final message = error.toString().replaceFirst("Exception: ", "").trim();
    if (message.contains("try a smaller image")) {
      return message;
    }
    if (message.contains("Server Error") ||
        message.contains("Response:") ||
        message.contains("{message:")) {
      return "The photo failed to upload. Please try a smaller image.";
    }
    if (message.isEmpty || message.toLowerCase() == "null") {
      return "The photo failed to upload. Please try again.";
    }
    return message;
  }

  Future<void> _markChatSeen() async {
    try {
      await fbStore.collection("orders").doc(widget.order.code).update(
        {
          "userSeen": true,
        },
      );
    } catch (_) {
      // Best effort only; leaving chat should not be blocked by sync failure.
    }
  }

  Future<void> _leaveChatPage() async {
    await _markChatSeen();
    Get.back();
  }

  void _confirmLeaveChatPage() {
    if (!_hasPendingChatDraft()) {
      _leaveChatPage();
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
        _leaveChatPage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ChatViewModel chatViewModel = ChatViewModel();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        _confirmLeaveChatPage();
      },
      child: ViewModelBuilder<ChatViewModel>.reactive(
        viewModelBuilder: () => chatViewModel,
        onViewModelReady: (model) {
          model.initialise(widget.chatEntity);
        },
        builder: (context, vm, child) {
          final mediaQuery = MediaQuery.of(context);
          return Scaffold(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: false,
            body: Padding(
              padding: EdgeInsets.only(
                top: mediaQuery.padding.top,
              ),
              child: Stack(
                children: [
                  Builder(builder: (context) {
                    try {
                      return Column(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                              child: ListView.builder(
                                reverse: true,
                                padding: EdgeInsets.only(
                                  bottom: widget.readOnly
                                      ? mediaQuery.padding.bottom + 12
                                      : 12,
                                ),
                                itemCount: vm.messages.length,
                                itemBuilder: (context, index) {
                                  final message = vm.messages[index];
                                  final imageUrl = _messageImageUrl(message);
                                  final isImageMessage = imageUrl != null;
                                  final messagePhoneNumber =
                                      _philippineMobileNumberFromMessage(
                                    message.text,
                                  );
                                  final requestMessageType =
                                      _requestMessageType(message);
                                  final isRequestMessage =
                                      requestMessageType != null;
                                  final requestAccentColor =
                                      requestMessageType == "pass"
                                          ? const Color(0xFF007BFF)
                                          : Colors.red;
                                  final requestBubbleColor =
                                      requestMessageType == "pass"
                                          ? const Color(0xFFEAF4FF)
                                          : const Color(0xFFFFEBEA);
                                  if (!_messageHasVisibleContent(message)) {
                                    return const SizedBox.shrink();
                                  } else if (message.user.id !=
                                      "${AuthService.currentUser?.id}") {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        top: vm.messages.isNotEmpty &&
                                                index == vm.messages.length - 1
                                            ? 83
                                            : 0,
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          if (isImageMessage) {
                                            _showNetworkImagePreview(imageUrl);
                                          }
                                        },
                                        onLongPress: widget.readOnly ||
                                                !_canShowTextActions(
                                                  message,
                                                )
                                            ? null
                                            : () async {
                                                await _showMessageActionsSheet(
                                                  message.text,
                                                );
                                              },
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            top: vm.messages[index].user.id ==
                                                    () {
                                                      try {
                                                        return vm
                                                            .messages[index + 1]
                                                            .user
                                                            .id;
                                                      } catch (e) {
                                                        return "";
                                                      }
                                                    }()
                                                ? 0
                                                : 12,
                                            left: 12,
                                            right: 12,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              vm.messages[index].user.id ==
                                                      () {
                                                        try {
                                                          return vm
                                                              .messages[
                                                                  index - 1]
                                                              .user
                                                              .id;
                                                        } catch (e) {
                                                          return "";
                                                        }
                                                      }()
                                                  ? const SizedBox(width: 35)
                                                  : GestureDetector(
                                                      onTap: () {
                                                        _showNetworkImagePreview(
                                                          "${vm.messages[index].user.profileImage}",
                                                          memCacheWidth: 600,
                                                        );
                                                      },
                                                      child: ClipOval(
                                                        child: SizedBox(
                                                          width: 35,
                                                          height: 35,
                                                          child:
                                                              NetworkImageWidget(
                                                            fit: BoxFit.cover,
                                                            memCacheWidth: 600,
                                                            imageUrl:
                                                                "${vm.messages[index].user.profileImage}",
                                                            progressIndicatorBuilder:
                                                                (
                                                              context,
                                                              imageUrl,
                                                              progress,
                                                            ) {
                                                              return Container(
                                                                decoration:
                                                                    const BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                child:
                                                                    const Center(
                                                                  child:
                                                                      SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child:
                                                                        CircularProgressIndicator(
                                                                      color:
                                                                          Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            errorWidget: (
                                                              context,
                                                              imageUrl,
                                                              progress,
                                                            ) {
                                                              return Container(
                                                                decoration:
                                                                    const BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color: Color(
                                                                    0xFF030744,
                                                                  ),
                                                                ),
                                                                child:
                                                                    const Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .person_outline_outlined,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                              const SizedBox(width: 12),
                                              Flexible(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    vm.messages[index].user
                                                                .id ==
                                                            () {
                                                              try {
                                                                return vm
                                                                    .messages[
                                                                        index +
                                                                            1]
                                                                    .user
                                                                    .id;
                                                              } catch (e) {
                                                                return "";
                                                              }
                                                            }()
                                                        ? const SizedBox
                                                            .shrink()
                                                        : Text(
                                                            vm.messages[index]
                                                                .user
                                                                .getFullName(),
                                                            style:
                                                                const TextStyle(
                                                              height: 1.15,
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding: isImageMessage
                                                          ? EdgeInsets.zero
                                                          : const EdgeInsets
                                                              .all(
                                                              10,
                                                            ),
                                                      decoration: BoxDecoration(
                                                        color: isRequestMessage
                                                            ? requestBubbleColor
                                                            : Colors
                                                                .grey.shade200,
                                                        borderRadius:
                                                            const BorderRadius
                                                                .all(
                                                          Radius.circular(
                                                            8,
                                                          ),
                                                        ),
                                                        border: isRequestMessage
                                                            ? Border.all(
                                                                color: requestAccentColor
                                                                    .withValues(
                                                                  alpha: 0.18,
                                                                ),
                                                              )
                                                            : null,
                                                      ),
                                                      child: isImageMessage
                                                          ? Stack(
                                                              alignment: Alignment
                                                                  .bottomLeft,
                                                              children: [
                                                                _buildChatImage(
                                                                  context,
                                                                  imageUrl,
                                                                ),
                                                                _buildImageTimeBadge(
                                                                  vm
                                                                      .messages[
                                                                          index]
                                                                      .createdAt,
                                                                ),
                                                              ],
                                                            )
                                                          : Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  _displayMessageText(
                                                                    message,
                                                                  ),
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        15,
                                                                    height:
                                                                        1.15,
                                                                    color: isRequestMessage
                                                                        ? requestAccentColor
                                                                        : Colors
                                                                            .black,
                                                                    fontWeight: isRequestMessage
                                                                        ? FontWeight
                                                                            .w600
                                                                        : FontWeight
                                                                            .w400,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 5,
                                                                ),
                                                                if (!widget
                                                                        .readOnly &&
                                                                    messagePhoneNumber !=
                                                                        null) ...[
                                                                  _buildCallPhonePill(
                                                                    messagePhoneNumber,
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                ],
                                                                if (isRequestMessage) ...[
                                                                  _buildRequestActions(
                                                                    vm: vm,
                                                                    message:
                                                                        message,
                                                                    requestType:
                                                                        requestMessageType,
                                                                    color:
                                                                        requestAccentColor,
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                ],
                                                                _buildAcceptedCancelRequestActions(
                                                                  vm: vm,
                                                                  message:
                                                                      message,
                                                                ),
                                                                if (!widget
                                                                        .readOnly &&
                                                                    _shouldShowAcceptedCancelRequestActions(
                                                                      message
                                                                          .text,
                                                                    ))
                                                                  const SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                Text(
                                                                  DateFormat(
                                                                    "h:mm a",
                                                                  ).format(
                                                                    vm
                                                                        .messages[
                                                                            index]
                                                                        .createdAt,
                                                                  ),
                                                                  style:
                                                                      TextStyle(
                                                                    height:
                                                                        1.15,
                                                                    fontSize:
                                                                        12,
                                                                    color: isRequestMessage
                                                                        ? requestAccentColor
                                                                        : Colors
                                                                            .black,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 50),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        top: vm.messages.isNotEmpty &&
                                                index == vm.messages.length - 1
                                            ? 83
                                            : 0,
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          if (isImageMessage) {
                                            _showNetworkImagePreview(imageUrl);
                                          }
                                        },
                                        onLongPress: widget.readOnly ||
                                                !_canShowTextActions(
                                                  message,
                                                )
                                            ? null
                                            : () async {
                                                await _showMessageActionsSheet(
                                                  message.text,
                                                );
                                              },
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            top: vm.messages[index].user.id ==
                                                    () {
                                                      try {
                                                        return vm
                                                            .messages[index + 1]
                                                            .user
                                                            .id;
                                                      } catch (e) {
                                                        return "";
                                                      }
                                                    }()
                                                ? 4
                                                : 12,
                                            left: 12,
                                            right: 12,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const SizedBox(width: 50),
                                              Flexible(
                                                child: Container(
                                                  padding: isImageMessage
                                                      ? EdgeInsets.zero
                                                      : const EdgeInsets.all(
                                                          10,
                                                        ),
                                                  decoration: BoxDecoration(
                                                    color: isRequestMessage
                                                        ? requestBubbleColor
                                                        : const Color(
                                                            0xFF007BFF,
                                                          ),
                                                    borderRadius:
                                                        const BorderRadius.all(
                                                      Radius.circular(
                                                        8,
                                                      ),
                                                    ),
                                                    border: isRequestMessage
                                                        ? Border.all(
                                                            color:
                                                                requestAccentColor
                                                                    .withValues(
                                                              alpha: 0.18,
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                  child: isImageMessage
                                                      ? Stack(
                                                          alignment: Alignment
                                                              .bottomRight,
                                                          children: [
                                                            _buildChatImage(
                                                              context,
                                                              imageUrl,
                                                            ),
                                                            _buildImageTimeBadge(
                                                              vm.messages[index]
                                                                  .createdAt,
                                                            ),
                                                          ],
                                                        )
                                                      : Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            Text(
                                                              _displayMessageText(
                                                                message,
                                                              ),
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                height: 1.15,
                                                                color: isRequestMessage
                                                                    ? requestAccentColor
                                                                    : Colors
                                                                        .white,
                                                                fontWeight: isRequestMessage
                                                                    ? FontWeight
                                                                        .w600
                                                                    : FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 5,
                                                            ),
                                                            if (isRequestMessage) ...[
                                                              _buildRequestActions(
                                                                vm: vm,
                                                                message:
                                                                    message,
                                                                requestType:
                                                                    requestMessageType,
                                                                color:
                                                                    requestAccentColor,
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                            ],
                                                            Text(
                                                              DateFormat(
                                                                "h:mm a",
                                                              ).format(
                                                                vm
                                                                    .messages[
                                                                        index]
                                                                    .createdAt,
                                                              ),
                                                              style: TextStyle(
                                                                height: 1.15,
                                                                fontSize: 12,
                                                                color: isRequestMessage
                                                                    ? requestAccentColor
                                                                    : Colors
                                                                        .white,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          ValueListenableBuilder<Uint8List?>(
                            valueListenable: chatFileListenable,
                            builder: (context, selectedChatFile, _) {
                              if (widget.readOnly) {
                                return const SizedBox.shrink();
                              }

                              final mediaKeyboardInset =
                                  mediaQuery.viewInsets.bottom;
                              final rawKeyboardInset =
                                  mediaKeyboardInset > _mobileKeyboardInset
                                      ? mediaKeyboardInset
                                      : _mobileKeyboardInset > _webKeyboardInset
                                          ? _mobileKeyboardInset
                                          : _webKeyboardInset;
                              final isComposerFocused =
                                  _messageFocusNode.hasFocus;
                              final keyboardInset =
                                  isComposerFocused ? rawKeyboardInset : 0.0;
                              final isKeyboardVisible = keyboardInset > 0;
                              final closedComposerSafeBottomPadding =
                                  (mediaQuery.viewPadding.bottom > 0
                                          ? mediaQuery.viewPadding.bottom
                                          : mediaQuery.padding.bottom)
                                      .toDouble();
                              final showQuickChatPills =
                                  selectedChatFile == null &&
                                      !isComposerFocused;
                              final double imagePreviewHeight =
                                  mediaQuery.size.width.clamp(0.0, 450.0);
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: selectedChatFile == null
                                      ? keyboardInset
                                      : 0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: const Color(
                                          0xFF030744,
                                        ).withValues(alpha: 0.15),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      !showQuickChatPills
                                          ? const SizedBox.shrink()
                                          : StreamBuilder<
                                              DocumentSnapshot<
                                                  Map<String, dynamic>>>(
                                              stream:
                                                  userQuickChatDoc.snapshots(),
                                              builder: (context, snapshot) {
                                                final options =
                                                    parseQuickChatOptions(
                                                  snapshot.data?.data(),
                                                );
                                                if (options.isEmpty) {
                                                  return const SizedBox
                                                      .shrink();
                                                }

                                                return StreamBuilder<
                                                    DocumentSnapshot<
                                                        Map<String, dynamic>>>(
                                                  stream: fbStore
                                                      .collection("orders")
                                                      .doc(widget.order.code)
                                                      .snapshots(),
                                                  builder:
                                                      (context, orderSnapshot) {
                                                    final cancelStatus =
                                                        "${orderSnapshot.data?.data()?["cancel_request_status"] ?? ""}"
                                                            .trim()
                                                            .toLowerCase();
                                                    return Column(
                                                      children: [
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        QuickChatPills(
                                                          options: options,
                                                          horizontalPadding: 12,
                                                          enabled: !vm.isBusy,
                                                          showRequestCancellation:
                                                              _canShowRequestCancellationPill(
                                                                    widget.order
                                                                        .status,
                                                                  ) &&
                                                                  cancelStatus !=
                                                                      "accepted",
                                                          onSelected:
                                                              (option) async {
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                            await _sendQuickChatText(
                                                              vm,
                                                              option,
                                                            );
                                                          },
                                                          onRequestCancellation:
                                                              () async {
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                            await _sendQuickChatText(
                                                              vm,
                                                              "Request cancellation",
                                                              isRequestCancellation:
                                                                  true,
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                      SizedBox(
                                        height: selectedChatFile == null
                                            ? null
                                            : imagePreviewHeight,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: selectedChatFile == null
                                                    ? 12
                                                    : 0,
                                                bottom: selectedChatFile == null
                                                    ? 12
                                                    : 0,
                                              ),
                                              child: Row(
                                                children: [
                                                  _controller.text != "" &&
                                                          _controller.text !=
                                                              "null"
                                                      ? const SizedBox(
                                                          width: 16)
                                                      : const SizedBox(
                                                          width: 8),
                                                  _controller.text != "" &&
                                                          _controller.text !=
                                                              "null"
                                                      ? const SizedBox.shrink()
                                                      : SizedBox(
                                                          width: 38,
                                                          height: 38,
                                                          child: WidgetButton(
                                                            onTap: () async {
                                                              FocusManager
                                                                  .instance
                                                                  .primaryFocus
                                                                  ?.unfocus();
                                                              await showCameraSource(
                                                                cameraType:
                                                                    "chat",
                                                              );
                                                            },
                                                            borderRadius: 8,
                                                            child: const Center(
                                                              child: Icon(
                                                                Icons
                                                                    .camera_alt_outlined,
                                                                size: 30,
                                                                color: Color(
                                                                  0xFF007BFF,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                  _controller.text != "" &&
                                                          _controller.text !=
                                                              "null"
                                                      ? const SizedBox.shrink()
                                                      : SizedBox(
                                                          width: 38,
                                                          height: 38,
                                                          child: WidgetButton(
                                                            onTap: () async {
                                                              FocusManager
                                                                  .instance
                                                                  .primaryFocus
                                                                  ?.unfocus();
                                                              try {
                                                                final ImagePicker
                                                                    picker =
                                                                    ImagePicker();
                                                                final XFile?
                                                                    image =
                                                                    await picker
                                                                        .pickImage(
                                                                  source:
                                                                      ImageSource
                                                                          .gallery,
                                                                  maxWidth:
                                                                      _chatUploadMaxLongSide
                                                                          .toDouble(),
                                                                  maxHeight:
                                                                      _chatUploadMaxLongSide
                                                                          .toDouble(),
                                                                  imageQuality:
                                                                      80,
                                                                );
                                                                if (image !=
                                                                    null) {
                                                                  final imageBytes =
                                                                      await image
                                                                          .readAsBytes();
                                                                  final normalizedBytes =
                                                                      await normalizeImageToJpegWeb(
                                                                    imageBytes,
                                                                  );
                                                                  final uploadBytes =
                                                                      await _resizeChatImageBytesForUpload(
                                                                    normalizedBytes,
                                                                  );
                                                                  setChatFile(
                                                                    uploadBytes,
                                                                  );
                                                                }
                                                              } catch (e) {
                                                                showPermissionSettingsDialog(
                                                                  permissionName:
                                                                      "Photos",
                                                                  reason:
                                                                      'Please allow photo access in Settings so you can send an image from your gallery.',
                                                                );
                                                              }
                                                            },
                                                            borderRadius: 8,
                                                            child: const Center(
                                                              child: Icon(
                                                                Icons
                                                                    .image_outlined,
                                                                size: 30,
                                                                color: Color(
                                                                  0xFF007BFF,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                  _controller.text != "" &&
                                                          _controller.text !=
                                                              "null"
                                                      ? const SizedBox.shrink()
                                                      : const SizedBox(
                                                          width: 8),
                                                  Expanded(
                                                    child: TextField(
                                                      focusNode:
                                                          _messageFocusNode,
                                                      controller: _controller,
                                                      textInputAction:
                                                          TextInputAction.send,
                                                      decoration:
                                                          InputDecoration(
                                                        filled: true,
                                                        border:
                                                            const OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                            Radius.circular(
                                                              8,
                                                            ),
                                                          ),
                                                          borderSide:
                                                              BorderSide.none,
                                                        ),
                                                        fillColor: Colors
                                                            .grey.shade200,
                                                      ),
                                                      onSubmitted:
                                                          (message) async {
                                                        await _sendTextMessage(
                                                          vm,
                                                          message,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 55,
                                                    height: 55,
                                                    child: WidgetButton(
                                                      onTap: () async {
                                                        await _sendTextMessage(
                                                          vm,
                                                          _controller.text,
                                                        );
                                                      },
                                                      borderRadius: 8,
                                                      child: Center(
                                                        child: vm.isBusy
                                                            ? const CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              )
                                                            : Icon(
                                                                Icons.send,
                                                                size: 30,
                                                                color: _controller.text ==
                                                                            "" ||
                                                                        _controller.text ==
                                                                            "null"
                                                                    ? Colors
                                                                        .grey
                                                                    : const Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (selectedChatFile == null &&
                                                !isKeyboardVisible &&
                                                closedComposerSafeBottomPadding >
                                                    0) ...[
                                              SizedBox(
                                                height:
                                                    closedComposerSafeBottomPadding,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    } catch (e) {
                      return const SizedBox.shrink();
                    }
                  }),
                  ValueListenableBuilder<Uint8List?>(
                    valueListenable: chatFileListenable,
                    builder: (context, selectedChatFile, _) {
                      if (selectedChatFile == null) {
                        return const SizedBox.shrink();
                      }
                      final double imagePreviewHeight =
                          mediaQuery.size.width.clamp(0.0, 450.0);
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                _showMemoryImagePreview(selectedChatFile);
                              },
                              child: Container(
                                width: mediaQuery.size.width,
                                height: imagePreviewHeight,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    fit: BoxFit.cover,
                                    image: MemoryImage(selectedChatFile),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 32,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 55,
                                      child: WidgetButton(
                                        onTap: () async {
                                          setChatFile(null);
                                        },
                                        mainColor: Colors.red,
                                        useDefaultHoverColor: false,
                                        borderRadius: 8,
                                        child: const Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.close,
                                                size: 35,
                                                color: Colors.white,
                                              ),
                                              Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: SizedBox(
                                      height: 55,
                                      child: WidgetButton(
                                        onTap: () async {
                                          if (!vm.isBusy) {
                                            vm.setBusy(true);
                                            try {
                                              await OrderRequest().postMedia(
                                                widget.order.id!,
                                                "client",
                                              );
                                              await OrderRequest().getMedia(
                                                widget.order.id!,
                                              );
                                              if (mediaList.isNotEmpty &&
                                                  !vm.messages.any(
                                                    (message) =>
                                                        message.text.contains(
                                                            mediaList.last
                                                                .photoUrl!) &&
                                                        message.user.id ==
                                                            "${AuthService.currentUser?.id}",
                                                  )) {
                                                await vm.sendMessage(
                                                  ChatMessage(
                                                    text: mediaList
                                                        .last.photoUrl!,
                                                    user: widget
                                                        .chatEntity.mainUser!
                                                        .toChatUser(),
                                                    createdAt:
                                                        DateTime.now().toUtc(),
                                                  ),
                                                );
                                              }
                                              setChatFile(null);
                                            } catch (e) {
                                              ScaffoldMessenger.of(Get.context!)
                                                  .clearSnackBars();
                                              ScaffoldMessenger.of(
                                                Get.context!,
                                              ).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Colors.red,
                                                  content: Text(
                                                    _chatImageUploadErrorMessage(
                                                      e,
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                            vm.setBusy(false);
                                          }
                                        },
                                        mainColor: const Color(0xFF007BFF),
                                        useDefaultHoverColor: false,
                                        borderRadius: 8,
                                        child: Center(
                                          child: vm.isBusy
                                              ? const SizedBox(
                                                  width: 30,
                                                  height: 30,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.send,
                                                      size: 35,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(
                                                      width: 8,
                                                    ),
                                                    Text(
                                                      "Send",
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 58,
                                  height: 58,
                                  child: WidgetButton(
                                    onTap: _confirmLeaveChatPage,
                                    mainColor: Colors.transparent,
                                    isTransparentColor: true,
                                    useDefaultHoverColor: false,
                                    interactionColor: const Color(0x14030744),
                                    borderRadius: 1000,
                                    child: const Center(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: 2,
                                          right: 4,
                                          bottom: 2,
                                        ),
                                        child: Icon(
                                          Icons.chevron_left,
                                          color: Color(
                                            0xFF030744,
                                          ),
                                          size: 38,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "#${widget.order.id}",
                                      style: const TextStyle(
                                        height: 1,
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold,
                                        color: Color(
                                          0xFF030744,
                                        ),
                                      ),
                                    ),
                                    if (widget.readOnly) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.visibility_outlined,
                                        color: Color(0xFF030744),
                                      ),
                                    ],
                                  ],
                                ),
                                const Expanded(child: SizedBox.shrink()),
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: WidgetButton(
                                    onTap: () async {
                                      if (widget.readOnly) {
                                        await showFacebookSupportDialog(
                                            context);
                                        return;
                                      }
                                      launchUrlString(
                                        "tel:${widget.order.driver?.phone}",
                                      );
                                    },
                                    mainColor: const Color(
                                      0xFF007BFF,
                                    ),
                                    borderRadius: 8,
                                    useDefaultHoverColor: false,
                                    child: const Center(
                                      child: Icon(
                                        Icons.call,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: const Color(
                                0xFF030744,
                              ).withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
