// ignore_for_file: depend_on_referenced_packages

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/utils/order_status_style.dart';

class OrderListItem extends StatefulWidget {
  const OrderListItem({
    required this.hvm,
    required this.order,
    required this.onTap,
    this.onUseHistoryRoute,
    super.key,
  });

  final Order order;
  final HomeViewModel hvm;
  final VoidCallback onTap;
  final VoidCallback? onUseHistoryRoute;

  @override
  State<OrderListItem> createState() => _OrderListItemState();
}

class _OrderListItemState extends State<OrderListItem> {
  bool _ignoreNextCardTap = false;
  final ValueNotifier<bool> _isRouteActionPressed = ValueNotifier(false);

  @override
  void dispose() {
    _isRouteActionPressed.dispose();
    super.dispose();
  }

  void _markRouteActionTap() {
    _ignoreNextCardTap = true;
    _isRouteActionPressed.value = true;
  }

  void _clearRouteActionPress() {
    _ignoreNextCardTap = false;
    _isRouteActionPressed.value = false;
  }

  void _handleCardTap() {
    if (_ignoreNextCardTap) {
      _ignoreNextCardTap = false;
      return;
    }
    widget.onTap();
  }

  Future<void> _returnHistoryRoute({
    required Address pickup,
    required Address dropoff,
  }) async {
    widget.onUseHistoryRoute?.call();
    Get.back(
      result: <String, dynamic>{
        "pickup": pickup,
        "dropoff": dropoff,
      },
    );
  }

  void _showOngoingBookingSnackBar() {
    showError("You have an ongoing booking");
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

  Widget _buildRouteActionButton({
    required String label,
    required Future<void> Function() onTap,
  }) {
    return Expanded(
      child: WidgetButton(
        onTap: () async {
          await onTap();
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

  @override
  Widget build(BuildContext context) {
    final isReviewMode = AuthService.inReviewMode();
    final isCurrentUserProvider = isBool(AuthService.currentUser?.isProvider);
    final sourceLabel =
        widget.order.taxiOrder?.isWalkIn == true ? "Via Spot" : "Via App";
    final paymentMethodLabel =
        widget.order.paymentMethodId == 1 ? "Cash" : "Load";
    final trailingLabel = isCurrentUserProvider
        ? (widget.order.appearsToBeProviderStaffFare ? "Staff" : "Guest")
        : "${widget.order.total?.toStringAsFixed(0)} $paymentMethodLabel";
    return ValueListenableBuilder<bool>(
      valueListenable: _isRouteActionPressed,
      builder: (context, isRouteActionPressed, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(
              Radius.circular(12),
            ),
            border: Border.all(
              width: 1,
              color: const Color(0xFF030744).withValues(alpha: 0.15),
            ),
          ),
          child: WidgetButton(
            borderRadius: 12,
            mainColor: Colors.white,
            onTap: isReviewMode ? () {} : _handleCardTap,
            suppressInteraction: isReviewMode || isRouteActionPressed,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF030744).withValues(alpha: 0.08),
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
                          "#${widget.order.id}",
                          style: const TextStyle(
                            height: 1,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF030744),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: orderStatusChipBackgroundColor(
                          widget.order.status,
                          reason: widget.order.reason,
                        ),
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
                              } else if (widget.order.reason == "pass") {
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
                            color: orderStatusTextColor(
                              widget.order.status,
                              reason: widget.order.reason,
                            ),
                          ),
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
                      color: Color(0xFF007BFF),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
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
                    const SizedBox(
                      width: 8,
                    ),
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
                if (!isReviewMode) ...[
                  const SizedBox(height: 8),
                  Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) => _markRouteActionTap(),
                    onPointerUp: (_) => _clearRouteActionPress(),
                    onPointerCancel: (_) => _clearRouteActionPress(),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          _buildRouteActionButton(
                            label: "Repeat",
                            onTap: _repeatHistoryRoute,
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: const Color(
                              0xFF030744,
                            ).withValues(alpha: 0.15),
                          ),
                          _buildRouteActionButton(
                            label: "Reverse",
                            onTap: _reverseHistoryRoute,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else
                  const SizedBox(height: 14),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFF030744).withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          sourceLabel,
                          style: TextStyle(
                            height: 1.05,
                            color: () {
                              if (widget.order.driver == null) {
                                return Colors.red;
                              } else {
                                return Colors.green;
                              }
                            }(),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "${DateFormat("MMM d, y").format(widget.order.createdAt!)} • ${DateFormat("h:mm a").format(widget.order.createdAt!)}",
                          style: const TextStyle(
                            height: 1.05,
                            fontSize: 12,
                            color: Color(0xFF030744),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AuthService.inReviewMode()
                            ? Text(
                                "${widget.order.taxiOrder?.tripDetails?.kmDistance?.toStringAsFixed(0)} km",
                                style: TextStyle(
                                  height: 1.05,
                                  color: () {
                                    if (widget.order.driver == null) {
                                      return Colors.red;
                                    } else {
                                      return Colors.green;
                                    }
                                  }(),
                                ),
                              )
                            : Text(
                                trailingLabel,
                                style: TextStyle(
                                  height: 1.05,
                                  color: () {
                                    if (widget.order.driver == null) {
                                      return Colors.red;
                                    } else {
                                      return Colors.green;
                                    }
                                  }(),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
