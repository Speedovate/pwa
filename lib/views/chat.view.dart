// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:pwa/models/order.model.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:pwa/view_models/chat.vm.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/camera.widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/order.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:pwa/widgets/quick_chat_pills.widget.dart';
import 'package:url_launcher/url_launcher_string.dart';

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

class _ChatViewState extends State<ChatView> {
  bool isMediaLoading = false;
  bool _isUpdatingRequestCancellation = false;
  bool _isUpdatingRequestPass = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleComposerChanged);
    if (chatFileListenable.value != chatFile) {
      chatFileListenable.value = chatFile;
    }
    setChatViewOpen(true);
  }

  @override
  void dispose() {
    setChatViewOpen(false);
    _controller.removeListener(_handleComposerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    if (mounted) {
      setState(() {});
    }
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(
                  Radius.circular(1000),
                ),
                border: Border.all(
                  color: color.withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.15,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      color == Colors.white ? const Color(0xFF030744) : color,
                ),
              ),
            ),
          ],
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

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 34,
              child: WidgetButton(
                onTap: isUpdating
                    ? () {}
                    : () async {
                        await _updateRequestStatus(
                          vm: vm,
                          requestType: requestType,
                          status: "accepted",
                        );
                      },
                mainColor: Colors.white,
                borderRadius: 1000,
                useDefaultHoverColor: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: isUpdating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Text(
                            "Accept",
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
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: WidgetButton(
                onTap: isUpdating
                    ? () {}
                    : () async {
                        await _updateRequestStatus(
                          vm: vm,
                          requestType: requestType,
                          status: "rejected",
                        );
                      },
                mainColor: Colors.white,
                borderRadius: 1000,
                useDefaultHoverColor: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(
                      "Reject",
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
          ],
        );
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
    final availableWidth = MediaQuery.of(context).size.width - 124;
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

  Future<void> _showMessageActionsSheet(String messageText) async {
    final trimmedMessage = messageText.trim();
    if (trimmedMessage.isEmpty || trimmedMessage.toLowerCase() == "null") {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
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
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      messenger?.clearSnackBars();
                      messenger?.showSnackBar(
                        const SnackBar(
                          content: Text("Text copied"),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.copy_rounded,
                        ),
                        title: Text("Copy"),
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(sheetContext);
                    },
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.close_rounded,
                        ),
                        title: Text("Close"),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
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
        fbStore
            .collection(
              "orders",
            )
            .doc(widget.order.code)
            .update(
          {
            "userSeen": true,
          },
        );
        Get.back();
      },
      child: ViewModelBuilder<ChatViewModel>.reactive(
        viewModelBuilder: () => chatViewModel,
        onViewModelReady: (model) {
          model.initialise(widget.chatEntity);
        },
        builder: (context, vm, child) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
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
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: vm.messages.length,
                                itemBuilder: (context, index) {
                                  final message = vm.messages[index];
                                  final imageUrl = _messageImageUrl(message);
                                  final isImageMessage = imageUrl != null;
                                  final requestMessageType =
                                      _requestMessageType(message);
                                  final isRequestMessage =
                                      requestMessageType != null;
                                  final requestAccentColor =
                                      requestMessageType == "pass"
                                          ? const Color(0xFF007BFF)
                                          : const Color(0xFFFF3B30);
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
                                            AlertService().showAppAlert(
                                              isCustom: true,
                                              customWidget: PinchZoom(
                                                child: NetworkImageWidget(
                                                  imageUrl: imageUrl,
                                                  memCacheWidth: 900,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        onLongPress: !_canShowTextActions(
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
                                                  : ClipOval(
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
                                                            return const CircularProgressIndicator(
                                                              color: Color(
                                                                0xFF007BFF,
                                                              ),
                                                              strokeWidth: 2,
                                                            );
                                                          },
                                                          errorWidget: (
                                                            context,
                                                            imageUrl,
                                                            progress,
                                                          ) {
                                                            return Container(
                                                              color:
                                                                  const Color(
                                                                0xFF030744,
                                                              ),
                                                              child: const Icon(
                                                                Icons
                                                                    .person_outline_outlined,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            );
                                                          },
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
                                                                  message.text,
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
                                            AlertService().showAppAlert(
                                              isCustom: true,
                                              customWidget: PinchZoom(
                                                child: NetworkImageWidget(
                                                  imageUrl: imageUrl,
                                                  memCacheWidth: 900,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        onLongPress: !_canShowTextActions(
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
                                                              message.text,
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
                              final keyboardInset =
                                  MediaQuery.of(context).viewInsets.bottom;
                              return AnimatedPadding(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
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
                                      selectedChatFile != null
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
                                            : MediaQuery.of(context).size.width,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              _controller.text != "" &&
                                                      _controller.text != "null"
                                                  ? const SizedBox(width: 16)
                                                  : const SizedBox(width: 8),
                                              _controller.text != "" &&
                                                      _controller.text != "null"
                                                  ? const SizedBox.shrink()
                                                  : SizedBox(
                                                      width: 38,
                                                      height: 38,
                                                      child: WidgetButton(
                                                        onTap: () async {
                                                          FocusManager.instance
                                                              .primaryFocus
                                                              ?.unfocus();
                                                          await showCameraSource(
                                                            cameraType: "chat",
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
                                                      _controller.text != "null"
                                                  ? const SizedBox.shrink()
                                                  : SizedBox(
                                                      width: 38,
                                                      height: 38,
                                                      child: WidgetButton(
                                                        onTap: () async {
                                                          FocusManager.instance
                                                              .primaryFocus
                                                              ?.unfocus();
                                                          try {
                                                            final ImagePicker
                                                                picker =
                                                                ImagePicker();
                                                            final XFile? image =
                                                                await picker
                                                                    .pickImage(
                                                              source:
                                                                  ImageSource
                                                                      .gallery,
                                                            );
                                                            if (image != null) {
                                                              setChatFile(
                                                                await normalizeImageToJpegWeb(
                                                                  await image
                                                                      .readAsBytes(),
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (showParseText) {
                                                              debugPrint(
                                                                "Error picking image: $e",
                                                              );
                                                            }
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
                                                      _controller.text != "null"
                                                  ? const SizedBox.shrink()
                                                  : const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller: _controller,
                                                  decoration: InputDecoration(
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
                                                    fillColor:
                                                        Colors.grey.shade200,
                                                  ),
                                                  onSubmitted: (message) async {
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
                                                            color: _controller
                                                                            .text ==
                                                                        "" ||
                                                                    _controller
                                                                            .text ==
                                                                        "null"
                                                                ? Colors.grey
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
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Stack(
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context)
                                  .size
                                  .width
                                  .clamp(0, 450),
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: MemoryImage(selectedChatFile),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 20,
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
                                                    "Error: $e",
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () async {
                                    fbStore
                                        .collection(
                                          "orders",
                                        )
                                        .doc(widget.order.code)
                                        .update(
                                      {
                                        "userSeen": true,
                                      },
                                    );
                                    Get.back();
                                  },
                                  icon: const Padding(
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
                                const SizedBox(width: 2),
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
                                const Expanded(child: SizedBox.shrink()),
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: WidgetButton(
                                    onTap: () {
                                      launchUrlString(
                                        "tel://${widget.order.driver?.phone}",
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
