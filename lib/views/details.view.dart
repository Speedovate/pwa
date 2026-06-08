// ignore_for_file: depend_on_referenced_packages

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/images.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:pwa/views/chat.view.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/models/peer_user.model.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:pwa/view_models/details.vm.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DetailsView extends StatefulWidget {
  const DetailsView({
    required this.order,
    required this.hvm,
    this.onUseHistoryRoute,
    super.key,
  });

  final Order order;
  final HomeViewModel hvm;
  final VoidCallback? onUseHistoryRoute;

  @override
  State<DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<DetailsView> {
  DetailsViewModel detailsViewModel = DetailsViewModel();

  bool get _isCurrentOngoingOrder {
    final ongoingOrder = widget.hvm.ongoingOrder;
    if (ongoingOrder == null) {
      return false;
    }

    if (widget.order.id != null && ongoingOrder.id != null) {
      return widget.order.id == ongoingOrder.id;
    }

    final orderCode = (widget.order.code ?? "").trim();
    final ongoingOrderCode = (ongoingOrder.code ?? "").trim();
    return orderCode.isNotEmpty && orderCode == ongoingOrderCode;
  }

  Future<void> _openSupportChannel() async {
    await showFacebookSupportDialog(context);
  }

  Future<void> _callDriverOrSupport() async {
    if (!_isCurrentOngoingOrder) {
      await _openSupportChannel();
      return;
    }

    await launchUrlString(
      "tel:${widget.hvm.ongoingOrder?.driver?.phone}",
    );
  }

  ChatEntity? _buildReadOnlyChatEntity() {
    final orderCode = (widget.order.code ?? "").trim();
    final driver = widget.order.driver;
    if (orderCode.isEmpty || driver == null) {
      return null;
    }

    final userId = "${widget.order.user?.id ?? AuthService.currentUser?.id}";
    final driverId = "${driver.id}";
    final peers = {
      userId: PeerUser(
        id: userId,
        name:
            widget.order.user?.name ?? AuthService.currentUser?.name ?? "User",
        image: widget.order.user?.photo ?? AuthService.currentUser?.photo ?? "",
      ),
      driverId: PeerUser(
        id: driverId,
        name: driver.name ?? "Driver",
        image: driver.photo ?? "",
      ),
    };

    return ChatEntity(
      onMessageSent: (_, __) {},
      mainUser: peers[userId],
      peers: peers,
      path: 'orders/$orderCode/customerDriver/chats',
      title: "Chat with driver",
    );
  }

  Future<void> _openReadOnlyChat() async {
    final chatEntity = _buildReadOnlyChatEntity();
    if (chatEntity == null) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Chat history is unavailable for this booking.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      PageRouteBuilder(
        reverseTransitionDuration: Duration.zero,
        transitionDuration: Duration.zero,
        pageBuilder: (context, a, b) => ChatView(
          chatEntity,
          widget.order,
          readOnly: true,
        ),
      ),
    );
  }

  Future<void> _openBookingChat() async {
    if (_isCurrentOngoingOrder) {
      await widget.hvm.chatDriver();
      return;
    }

    await _openReadOnlyChat();
  }

  Address _historyRouteAddress({
    required String? addressLine,
    required double? latitude,
    required double? longitude,
  }) {
    return Address(
      addressLine: addressLine,
      coordinates: Coordinates(
        latitude ?? double.parse("${initLatLng!.lat}"),
        longitude ?? double.parse("${initLatLng!.lng}"),
      ),
    );
  }

  void _showOngoingBookingSnackBar() {
    ScaffoldMessenger.of(Get.context!).clearSnackBars();
    ScaffoldMessenger.of(Get.context!).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          "You have an ongoing booking",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _returnHistoryRoute({
    required Address pickup,
    required Address dropoff,
  }) async {
    widget.onUseHistoryRoute?.call();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop(
      <String, dynamic>{
        "pickup": pickup,
        "dropoff": dropoff,
      },
    );
  }

  Future<void> _repeatHistoryRoute() async {
    if (widget.hvm.ongoingOrder != null) {
      _showOngoingBookingSnackBar();
      return;
    }

    await _returnHistoryRoute(
      pickup: _historyRouteAddress(
        addressLine: widget.order.taxiOrder?.pickupAddress,
        latitude: widget.order.taxiOrder?.pickupLatitude,
        longitude: widget.order.taxiOrder?.pickupLongitude,
      ),
      dropoff: _historyRouteAddress(
        addressLine: widget.order.taxiOrder?.dropoffAddress,
        latitude: widget.order.taxiOrder?.dropoffLatitude,
        longitude: widget.order.taxiOrder?.dropoffLongitude,
      ),
    );
  }

  Future<void> _reverseHistoryRoute() async {
    if (widget.hvm.ongoingOrder != null) {
      _showOngoingBookingSnackBar();
      return;
    }

    await _returnHistoryRoute(
      pickup: _historyRouteAddress(
        addressLine: widget.order.taxiOrder?.dropoffAddress,
        latitude: widget.order.taxiOrder?.dropoffLatitude,
        longitude: widget.order.taxiOrder?.dropoffLongitude,
      ),
      dropoff: _historyRouteAddress(
        addressLine: widget.order.taxiOrder?.pickupAddress,
        latitude: widget.order.taxiOrder?.pickupLatitude,
        longitude: widget.order.taxiOrder?.pickupLongitude,
      ),
    );
  }

  Widget _buildHistoryRouteButton({
    required String label,
    required Future<void> Function() onPressed,
  }) {
    return Expanded(
      child: WidgetButton(
        onTap: () async {
          await onPressed();
        },
        mainColor: Colors.transparent,
        isTransparentColor: true,
        useDefaultHoverColor: false,
        interactionColor: const Color(0xFF007BFF).withValues(alpha: 0.12),
        borderRadius: 0,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              height: 1.05,
              color: Color(0xFF007BFF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryRouteActions() {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          _buildHistoryRouteButton(
            label: "Repeat",
            onPressed: _repeatHistoryRoute,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: const Color(0xFF030744).withValues(alpha: 0.15),
          ),
          _buildHistoryRouteButton(
            label: "Reverse",
            onPressed: _reverseHistoryRoute,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<DetailsViewModel>.reactive(
      viewModelBuilder: () => detailsViewModel,
      onViewModelReady: (vm) => vm.initialise(widget.order),
      builder: (context, vm, child) {
        final isProvider = isBool(AuthService.currentUser?.isProvider);
        final discount = widget.order.discount ?? 0;
        final markupAmount =
            (vm.orderData?["markup_amount"] as num?)?.toDouble() ?? 0;
        final sourceLabel = widget.order.taxiOrder?.isWalkIn == true
            ? "Via Spot"
            : isProvider && markupAmount > 0
                ? "Via App | Guest"
                : isProvider && discount > 0
                    ? "Via App | Staff"
                    : "Via App";

        final mediaQuery = MediaQuery.of(context);
        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: mediaQuery.size.height,
              child: Padding(
                padding: EdgeInsets.only(
                  top: mediaQuery.padding.top,
                  bottom: 12,
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 12,
                    ),
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
                        Expanded(
                          child: Center(
                            child: Text(
                              DateFormat("dd MMM yyyy, h:mm a").format(
                                widget.order.createdAt!,
                              ),
                              style: const TextStyle(
                                height: 1.05,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF030744),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 64),
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: const Color(0xFF030744).withValues(alpha: 0.15),
                    ),
                    widget.order.driver == null
                        ? const SizedBox.shrink()
                        : const SizedBox(height: 20),
                    widget.order.driver == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: SizedBox(
                              width: double.infinity.clamp(0, 800),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      AlertService().showAppAlert(
                                        isCustom: true,
                                        customWidget: PinchZoom(
                                          child: SizedBox(
                                            height: mediaQuery.size.width - 70,
                                            child: NetworkImageWidget(
                                              imageUrl:
                                                  widget.order.driver?.cPhoto ??
                                                      "",
                                              memCacheWidth: 600,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipOval(
                                      child: SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: NetworkImageWidget(
                                          fit: BoxFit.cover,
                                          memCacheWidth: 600,
                                          imageUrl:
                                              widget.order.driver?.cPhoto ?? "",
                                          progressIndicatorBuilder: (
                                            context,
                                            imageUrl,
                                            progress,
                                          ) {
                                            return const SizedBox.expand(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                ),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeCap: StrokeCap.round,
                                                    color: Color(0xFF007BFF),
                                                    backgroundColor:
                                                        Colors.white,
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
                                            return const SizedBox.expand(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF030744),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    Icons
                                                        .person_outline_outlined,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        right: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            capitalizeWords(
                                              widget.order.driver?.name,
                                              alt: "Driver",
                                            ),
                                            style: const TextStyle(
                                              height: 1.15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF030744),
                                            ),
                                          ),
                                          Text(
                                            capitalizeWords(
                                              "${widget.order.driver?.vehicle?.vehicleInfo}${widget.order.driver?.franchiseNumber == null ? "" : " | ${widget.order.driver?.franchiseNumber}"}${widget.order.driver?.licenseNumber == null ? "" : " | ${widget.order.driver?.licenseNumber}"}",
                                              alt: "Driver Info",
                                            ),
                                            style: const TextStyle(
                                              height: 1.15,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFF030744),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  WidgetButton(
                                    mainColor: const Color(0xFF007BFF),
                                    useDefaultHoverColor: false,
                                    borderRadius: 8,
                                    onTap: _callDriverOrSupport,
                                    child: const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Center(
                                        child: Icon(
                                          Icons.call,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  WidgetButton(
                                    mainColor: const Color(0xFF007BFF),
                                    useDefaultHoverColor: false,
                                    borderRadius: 8,
                                    onTap: _openBookingChat,
                                    child: const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Center(
                                        child: Icon(
                                          Icons.chat,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: Container(
                        width: double.infinity.clamp(0, 800),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(
                              12,
                            ),
                          ),
                          border: Border.all(
                            width: 1,
                            color:
                                const Color(0xFF030744).withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: () {
                                  final status = widget.order.status;
                                  if (status == "pending") {
                                    return Colors.blue.shade100;
                                  } else if (status == "preparing") {
                                    return Colors.blue.shade100;
                                  } else if (status == "ready") {
                                    return Colors.blue.shade100;
                                  } else if (status == "enroute") {
                                    return Colors.orange.shade100;
                                  } else if (status == "failed") {
                                    return Colors.red.shade100;
                                  } else if (status == "cancelled") {
                                    if (widget.order.reason == "rebook") {
                                      return Colors.orange.shade100;
                                    } else if (widget.order.reason == "pass") {
                                      return Colors.orange.shade100;
                                    } else {
                                      return Colors.red.shade100;
                                    }
                                  } else if (status == "delivered") {
                                    return Colors.green.shade100;
                                  } else {
                                    return Colors.blue.shade100;
                                  }
                                }(),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                child: Text(
                                  () {
                                    final status = widget.order.status;
                                    if (status == "pending") {
                                      return "Searching";
                                    } else if (status == "preparing") {
                                      return "Waiting";
                                    } else if (status == "ready") {
                                      return "Arrived";
                                    } else if (status == "enroute") {
                                      return "Ongoing";
                                    } else if (status == "failed") {
                                      return "Failed";
                                    } else if (status == "cancelled") {
                                      if (widget.order.reason == "rebook") {
                                        return "Rebooked";
                                      } else if (widget.order.reason ==
                                          "pass") {
                                        return "Passed";
                                      } else {
                                        return "Cancelled";
                                      }
                                    } else if (status == "delivered") {
                                      return "Completed";
                                    } else {
                                      return "Connecting";
                                    }
                                  }(),
                                  style: TextStyle(
                                    height: 1,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: () {
                                      final status = widget.order.status;
                                      if (status == "pending") {
                                        return Colors.blue;
                                      } else if (status == "preparing") {
                                        return Colors.blue;
                                      } else if (status == "ready") {
                                        return Colors.blue;
                                      } else if (status == "enroute") {
                                        return Colors.orange;
                                      } else if (status == "failed") {
                                        return Colors.red;
                                      } else if (status == "cancelled") {
                                        if (widget.order.reason == "rebook") {
                                          return Colors.orange;
                                        } else if (widget.order.reason ==
                                            "pass") {
                                          return Colors.orange;
                                        } else {
                                          return Colors.red;
                                        }
                                      } else if (status == "delivered") {
                                        return Colors.green;
                                      } else {
                                        return Colors.blue;
                                      }
                                    }(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            Text(
                              "#${widget.order.id}",
                              style: const TextStyle(
                                height: 1,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF030744),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: const Color(0xFF030744)
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const SizedBox(width: 12),
                                widget.order.driver == null
                                    ? ClipOval(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            color: Colors.red,
                                            child: const Icon(
                                              Icons.warning,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const NetworkImageWidget(
                                        imageUrl: AppImages.logo,
                                        memCacheWidth: 600,
                                        height: 28,
                                        width: 28,
                                      ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "${capitalizeWords(widget.order.driver?.vehicle?.vehicleType?.name, alt: "Failed")} Booking",
                                    style: const TextStyle(
                                      height: 1,
                                      fontSize: 14,
                                      color: Color(0xFF030744),
                                    ),
                                  ),
                                ),
                                Text(
                                  sourceLabel,
                                  style: const TextStyle(
                                    height: 1,
                                    fontSize: 14,
                                    color: Color(0xFF030744),
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: const Color(0xFF030744)
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const SizedBox(width: 14),
                                const Icon(
                                  Icons.trip_origin,
                                  color: Color(0xFF007BFF),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    capitalizeWords(
                                      widget.order.taxiOrder?.pickupAddress,
                                      alt: "Pickup Address",
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF030744),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const SizedBox(width: 14),
                                const Icon(
                                  Icons.trip_origin,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    capitalizeWords(
                                      widget.order.taxiOrder?.dropoffAddress,
                                      alt: "Dropoff Address",
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF030744),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildHistoryRouteActions(),
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: const Color(0xFF030744)
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            AuthService.inReviewMode()
                                ? const SizedBox.shrink()
                                : Row(
                                    children: [
                                      const SizedBox(width: 14),
                                      Padding(
                                        padding: const EdgeInsets.all(1),
                                        child: Container(
                                          width: 21,
                                          height: 21,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.green,
                                              width: 2,
                                            ),
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(1000),
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              "₱",
                                              style: TextStyle(
                                                height: 1,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "Total Fare",
                                        style: TextStyle(
                                          color: Color(0xFF030744),
                                        ),
                                      ),
                                      const Expanded(child: SizedBox.shrink()),
                                      Text(
                                        "₱${((widget.order.total ?? 0) + (isBool(AuthService.currentUser?.isProvider) && (widget.order.discount ?? 0) == 0 ? (vm.orderData?["markup_amount"] ?? 0) : 0)).toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          color: Color(0xFF030744),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                  ),
                            AuthService.inReviewMode()
                                ? const SizedBox.shrink()
                                : const SizedBox(height: 8),
                            Row(
                              children: [
                                const SizedBox(width: 14),
                                Icon(
                                  AuthService.inReviewMode()
                                      ? Icons.location_on
                                      : Icons.credit_score_outlined,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AuthService.inReviewMode()
                                      ? "Distance"
                                      : "Payment Method",
                                  style: const TextStyle(
                                    color: Color(0xFF030744),
                                  ),
                                ),
                                const Expanded(child: SizedBox.shrink()),
                                Text(
                                  AuthService.inReviewMode()
                                      ? "${widget.order.taxiOrder?.tripDetails?.kmDistance?.toStringAsFixed(0)} km"
                                      : widget.order.paymentMethodId == 1
                                          ? "Cash"
                                          : "Load",
                                  style: const TextStyle(
                                    color: Color(0xFF030744),
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: SizedBox(
                        child: ActionButton(
                          text: "Report an issue",
                          style: const TextStyle(
                            height: 1,
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          mainColor: Colors.red.withValues(alpha: 0.1),
                          onTap: () {
                            _openSupportChannel();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
