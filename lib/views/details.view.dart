// ignore_for_file: depend_on_referenced_packages

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/images.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/view_models/details.vm.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DetailsView extends StatefulWidget {
  const DetailsView({
    required this.order,
    super.key,
  });

  final Order order;

  @override
  State<DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<DetailsView> {
  DetailsViewModel detailsViewModel = DetailsViewModel();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<DetailsViewModel>.reactive(
      viewModelBuilder: () => detailsViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
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
                            Navigator.pop(context);
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
                      color: const Color(0xFF030744).withOpacity(0.15),
                    ),
                    widget.order.driver == null
                        ? const SizedBox()
                        : const SizedBox(height: 20),
                    widget.order.driver == null
                        ? const SizedBox()
                        : DateTime.now()
                                    .difference(
                                      widget.order.createdAt ?? DateTime.now(),
                                    )
                                    .inDays >
                                7
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Container(
                                  height: 50,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF030744)
                                          .withOpacity(0.15),
                                    ),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(
                                        12,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.account_circle,
                                        color: const Color(0xFF030744)
                                            .withOpacity(0.5),
                                        size: 36,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "You can no longer contact or view your driver's details after 7 days.",
                                          style: TextStyle(
                                            height: 1.05,
                                            fontSize: 13,
                                            color: const Color(0xFF030744)
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
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
                                              child: ClipOval(
                                                child: SizedBox(
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .width -
                                                      70,
                                                  child: Image.network(
                                                    widget.order.driver
                                                            ?.cPhoto ??
                                                        "",
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipOval(
                                          child: SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: CachedNetworkImage(
                                              fit: BoxFit.cover,
                                              memCacheWidth: 600,
                                              imageUrl:
                                                  widget.order.driver?.cPhoto ??
                                                      "",
                                              progressIndicatorBuilder: (
                                                context,
                                                imageUrl,
                                                progress,
                                              ) {
                                                return const CircularProgressIndicator(
                                                  color: Color(0xFF007BFF),
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
                                                      const Color(0xFF030744),
                                                  child: const Icon(
                                                    Icons
                                                        .person_outline_outlined,
                                                    color: Colors.white,
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
                                                  fontWeight: FontWeight.w500,
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
                                        mainColor: const Color(0xFFE5E6EC),
                                        useDefaultHoverColor: false,
                                        borderRadius: 8,
                                        onTap: () {
                                          ScaffoldMessenger.of(
                                            Get.overlayContext!,
                                          ).clearSnackBars();
                                          ScaffoldMessenger.of(
                                            Get.overlayContext!,
                                          ).showSnackBar(
                                            const SnackBar(
                                              backgroundColor: Colors.red,
                                              content: Text(
                                                "You can no longer call your driver."
                                                " Please report an issue instead",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: Center(
                                            child: Icon(
                                              Icons.call,
                                              color: const Color(0xFF030744)
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      WidgetButton(
                                        mainColor: const Color(0xFFE5E6EC),
                                        useDefaultHoverColor: false,
                                        borderRadius: 8,
                                        onTap: () {
                                          ScaffoldMessenger.of(
                                            Get.overlayContext!,
                                          ).clearSnackBars();
                                          ScaffoldMessenger.of(
                                            Get.overlayContext!,
                                          ).showSnackBar(
                                            const SnackBar(
                                              backgroundColor: Colors.red,
                                              content: Text(
                                                "You can no longer chat your driver."
                                                " Please report an issue instead",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: Center(
                                            child: Icon(
                                              Icons.chat,
                                              color: const Color(0xFF030744)
                                                  .withOpacity(0.3),
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
                            color: const Color(0xFF030744).withOpacity(0.15),
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
                                        return Colors.blue;
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
                              "Ride #${widget.order.id}",
                              style: const TextStyle(
                                height: 1,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
                                color:
                                    const Color(0xFF030744).withOpacity(0.15),
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
                                    : Image.asset(
                                        AppImages.icon,
                                        height: 28,
                                        width: 28,
                                        color: const Color(0xFF030744),
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
                                const Text(
                                  "Via App",
                                  style: TextStyle(
                                    height: 1,
                                    fontSize: 14,
                                    color: Colors.green,
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
                                color:
                                    const Color(0xFF030744).withOpacity(0.15),
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
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color:
                                    const Color(0xFF030744).withOpacity(0.15),
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            AuthService.inReviewMode()
                                ? const SizedBox()
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
                                      const Expanded(child: SizedBox()),
                                      Text(
                                        "₱${((widget.order.subTotal ?? 0) + (widget.order.taxiOrder?.pickupFee ?? 0)).toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                  ),
                            AuthService.inReviewMode()
                                ? const SizedBox()
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
                                const Expanded(child: SizedBox()),
                                Text(
                                  AuthService.inReviewMode()
                                      ? "${widget.order.taxiOrder?.tripDetails?.kmDistance?.toStringAsFixed(1)} km"
                                      : widget.order.paymentMethodId == 1
                                          ? "Cash"
                                          : "Load",
                                  style: const TextStyle(
                                    color: Colors.green,
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
                            fontSize: 15,
                            color: Color(0xFF007BFF),
                            fontWeight: FontWeight.bold,
                          ),
                          mainColor: const Color(0xFFEAF1FE),
                          onTap: () {
                            launchUrlString(
                              "sms://+639122078420",
                            );
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
