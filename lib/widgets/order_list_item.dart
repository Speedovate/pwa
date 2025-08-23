// ignore_for_file: depend_on_referenced_packages

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/services/auth.service.dart';

class OrderListItem extends StatefulWidget {
  const OrderListItem({
    required this.order,
    required this.onTap,
    super.key,
  });

  final Order order;
  final VoidCallback? onTap;

  @override
  State<OrderListItem> createState() => _OrderListItemState();
}

class _OrderListItemState extends State<OrderListItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(
          Radius.circular(12),
        ),
        border: Border.all(
          width: 1,
          color: const Color(0xFF030744).withOpacity(0.15),
        ),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(
          Radius.circular(12),
        ),
        child: Ink(
          child: InkWell(
            borderRadius: const BorderRadius.all(
              Radius.circular(12),
            ),
            focusColor: const Color(0xFF030744).withOpacity(
              AuthService.inReviewMode() ? 0.0 : 0.1,
            ),
            hoverColor: const Color(0xFF030744).withOpacity(
              AuthService.inReviewMode() ? 0.0 : 0.1,
            ),
            splashColor: const Color(0xFF030744).withOpacity(
              AuthService.inReviewMode() ? 0.0 : 0.1,
            ),
            highlightColor: const Color(0xFF030744).withOpacity(
              AuthService.inReviewMode() ? 0.0 : 0.1,
            ),
            onTap: widget.onTap,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Image.asset(
                      AppImages.icon,
                      height: 28,
                      width: 28,
                      color: const Color(0xFF030744),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Ride #${widget.order.id}",
                        style: const TextStyle(
                          height: 1,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF030744),
                        ),
                      ),
                    ),
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
                            return Colors.blue.shade100;
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
                              return "Navigating";
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
                            color: () {
                              final status = widget.order.status;
                              if (status == "pending") {
                                return Colors.blue;
                              } else if (status == "preparing") {
                                return Colors.blue;
                              } else if (status == "ready") {
                                return Colors.blue;
                              } else if (status == "enroute") {
                                return Colors.blue;
                              } else if (status == "failed") {
                                return Colors.red;
                              } else if (status == "cancelled") {
                                if (widget.order.reason == "rebook") {
                                  return Colors.orange;
                                } else if (widget.order.reason == "pass") {
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
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFF030744).withOpacity(0.15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 70,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          capitalizeWords(
                            widget.order.driver?.vehicle?.vehicleType?.name ==
                                    null
                                ? null
                                : "ride",
                            alt: "Failed",
                          ),
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
                          DateFormat("dd MMM yyyy, h:mm a").format(
                            widget.order.createdAt!,
                          ),
                          style: const TextStyle(
                            height: 1.05,
                            fontSize: 12,
                            color: Color(0xFF030744),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AuthService.inReviewMode()
                            ? Text(
                                "${widget.order.taxiOrder?.tripDetails?.kmDistance?.toStringAsFixed(1)} km",
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
                                "₱${((widget.order.subTotal ?? 0) + (widget.order.taxiOrder?.pickupFee ?? 0)).toStringAsFixed(0)}",
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
        ),
      ),
    );
  }
}
