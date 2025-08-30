// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/map.view.dart';
import 'package:pwa/views/load.view.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:pwa/views/history.view.dart';
import 'package:pwa/views/profile.view.dart';
import 'package:pwa/view_models/Load.vm.dart';
import 'package:pwa/views/settings.view.dart';
import 'package:pwa/widgets/gmap.widget.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/list_tile.widget.dart';
import 'package:pwa/widgets/text_field.widget.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeViewModel homeViewModel = HomeViewModel();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateWithoutTransition(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) {
          return page;
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;
    return ViewModelBuilder<HomeViewModel>.reactive(
      viewModelBuilder: () => homeViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            toolbarHeight: 0,
            backgroundColor: Colors.white,
          ),
          drawer: Drawer(
            backgroundColor: Colors.white,
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top),
                WidgetButton(
                  borderRadius: 0,
                  onTap: () {
                    if (!AuthService.isLoggedIn()) {
                      _navigateWithoutTransition(
                        const LoginView(),
                      );
                    } else {
                      agreed = false;
                      selfieFile = null;
                      _navigateWithoutTransition(
                        const ProfileView(),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 18,
                      left: 18,
                      right: 12,
                      bottom: 18,
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: NetworkImageWidget(
                              fit: BoxFit.cover,
                              memCacheWidth: 600,
                              imageUrl: AuthService.currentUser?.cPhoto ?? "",
                              progressIndicatorBuilder: (
                                context,
                                imageUrl,
                                progress,
                              ) {
                                return CircularProgressIndicator(
                                  strokeCap: StrokeCap.round,
                                  color: const Color(
                                    0xFF007BFF,
                                  ),
                                  backgroundColor: const Color(
                                    0xFF007BFF,
                                  ).withOpacity(0.25),
                                );
                              },
                              errorWidget: (context, imageUrl, progress) {
                                return Container(
                                  color: const Color(
                                    0xFF030744,
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_outlined,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            !AuthService.isLoggedIn()
                                ? "Login Account"
                                : capitalizeWords(
                                    "${AuthService.currentUser!.name}"),
                            style: const TextStyle(
                              height: 1.05,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(
                                0xFF030744,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Icon(Icons.chevron_right,
                            color: Color(
                              0xFF030744,
                            ),
                            size: 25),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(
                    0xFF030744,
                  ).withOpacity(0.1),
                ),
                if (AuthService.isLoggedIn())
                  ListTileWidget(
                    leading: const Icon(
                      Icons.history,
                      color: Color(
                        0xFF030744,
                      ),
                    ),
                    title: const Text(
                      "History",
                      style: TextStyle(
                          color: Color(
                            0xFF030744,
                          ),
                          fontSize: 15),
                    ),
                    onTap: () {
                      _navigateWithoutTransition(
                        const HistoryView(),
                      );
                    },
                  ),
                if (AuthService.isLoggedIn())
                  ListTileWidget(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: Color(
                        0xFF030744,
                      ),
                    ),
                    title: const Text(
                      "Settings",
                      style: TextStyle(
                        color: Color(
                          0xFF030744,
                        ),
                      ),
                    ),
                    onTap: () {
                      if (!AuthService.isLoggedIn()) {
                        _navigateWithoutTransition(
                          const LoginView(),
                        );
                      } else {
                        _navigateWithoutTransition(
                          const SettingsView(),
                        );
                      }
                    },
                  ),
                ListTileWidget(
                  leading: const Icon(
                    Icons.headset_outlined,
                    color: Color(
                      0xFF030744,
                    ),
                  ),
                  title: const Text(
                    "Assistance",
                    style: TextStyle(
                      color: Color(
                        0xFF030744,
                      ),
                    ),
                  ),
                  onTap: () {
                    launchUrlString(
                      "sms://+639122078420",
                    );
                  },
                ),
                ListTileWidget(
                  leading: const Icon(
                    Icons.code,
                    color: Color(
                      0xFF030744,
                    ),
                  ),
                  title: Text(
                    "Version ${version ?? "1.0.0"} (${versionCode ?? "1"})",
                    style: const TextStyle(
                      color: Color(
                        0xFF030744,
                      ),
                    ),
                  ),
                  onTap: () {
                    if (!AuthService.inReviewMode()) {
                      launchUrlString(
                        "https://ppctoda.framer.website",
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          onDrawerChanged: (isOpened) {
            setState(() {});
          },
          backgroundColor: Colors.white,
          body: FutureBuilder<gmaps.LatLng?>(
            future: getMyLatLng(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 16,
                              left: 16,
                              right: 16,
                              bottom: 18,
                            ),
                            child: Image.asset(
                              AppImages.logo,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Center(
                          child: SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              strokeWidth: 10,
                              strokeCap: StrokeCap.round,
                              color: const Color(
                                0xFF007BFF,
                              ),
                              backgroundColor: const Color(
                                0xFF007BFF,
                              ).withOpacity(0.25),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final center = snapshot.data!;
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                GoogleMapWidget(
                                  center: center,
                                  enableGestures: !vm.showReport &&
                                      (isBool(vm.userSeen) ||
                                          vm.dvrMessage == null ||
                                          vm.dvrMessage == "null" ||
                                          vm.ongoingOrder == null ||
                                          vm.ongoingOrder?.status ==
                                              "cancelled" ||
                                          vm.dvrMessage == "null" ||
                                          vm.dvrMessage == "") &&
                                      !isBool(
                                        _scaffoldKey.currentState?.isDrawerOpen,
                                      ) &&
                                      !vm.isLoading,
                                  onMapCreated: (map) {
                                    vm.setMap(map);
                                  },
                                  onCameraMove: (center) {
                                    try {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      final a = vm.disposed;
                                      final b = vm.markers;
                                      if (vm.ongoingOrder == null) {
                                        if (center != vm.lastCenter?.value) {
                                          vm.lastCenter?.value = center;
                                          if (!a && b.isEmpty) {
                                            vm.mapCameraMove(
                                              "onCameraMove",
                                              center,
                                            );
                                            debugPrint("HomeView - Map move");
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint(
                                        "HomeView - onCameraMove error: $e",
                                      );
                                    }
                                  },
                                ),
                                Positioned(
                                  top: 20,
                                  left: 20,
                                  child: _FloatingButton(
                                    icon: Icons.menu,
                                    onTap: () {
                                      _scaffoldKey.currentState?.openDrawer();
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 20,
                                  right: 20,
                                  child: _FloatingButton(
                                    icon: Icons.my_location_outlined,
                                    onTap: () async {
                                      final a = vm.disposed;
                                      final b = vm.markers;
                                      final c = vm.selectedAddress.value;
                                      if (b.isEmpty) {
                                        if (initLatLng?.lat != 9.7638 &&
                                            initLatLng?.lng != 118.7473) {
                                          vm.zoomToCurrentLocation();
                                        } else {
                                          ScaffoldMessenger.of(
                                            Get.overlayContext!,
                                          ).clearSnackBars();
                                          ScaffoldMessenger.of(
                                            Get.overlayContext!,
                                          ).showSnackBar(
                                            const SnackBar(
                                              backgroundColor: Colors.red,
                                              content: Text(
                                                "There was a problem with your location detection!",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (vm.ongoingOrder == null) {
                                          vm.drawDropPolyLines(
                                            "pickup-dropoff",
                                            pickupAddress!.latLng,
                                            dropoffAddress!.latLng,
                                            null,
                                          );
                                        } else {
                                          vm.lastStatus = null;
                                          await vm.getOngoingOrder();
                                        }
                                      }
                                      if (!a && b.isEmpty && c == null) {
                                        vm.mapCameraMove(
                                          "myLocation",
                                          vm.map?.center,
                                        );
                                        debugPrint("HomeView - Map move");
                                      }
                                    },
                                  ),
                                ),
                                Positioned(
                                  left: 20,
                                  bottom: 20,
                                  child: Column(
                                    children: [
                                      _FloatingButton(
                                        icon: Icons.cached_outlined,
                                        onTap: () async {
                                          if (!AuthService.isLoggedIn()) {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                reverseTransitionDuration:
                                                    Duration.zero,
                                                transitionDuration:
                                                    Duration.zero,
                                                pageBuilder: (
                                                  context,
                                                  a,
                                                  b,
                                                ) =>
                                                    const LoginView(),
                                              ),
                                            );
                                          } else {
                                            AlertService().showLoading();
                                            vm.lastStatus = null;
                                            await vm.getOngoingOrder();
                                            if (vm.ongoingOrder == null) {
                                              await LoadViewModel()
                                                  .getLoadBalance();
                                            }
                                            if (pickupAddress != null &&
                                                    dropoffAddress != null &&
                                                    vm.ongoingOrder == null ||
                                                vm.ongoingOrder?.status ==
                                                    "cancelled") {
                                              setState(() {
                                                vm.isPreparing = true;
                                              });
                                              if (vm.ongoingOrder == null) {
                                                await vm.drawDropPolyLines(
                                                  "pickup-dropoff",
                                                  pickupAddress!.latLng,
                                                  dropoffAddress!.latLng,
                                                  null,
                                                );
                                                await vm
                                                    .fetchVehicleTypesPricing();
                                                setState(() {
                                                  vm.isPreparing = false;
                                                });
                                              }
                                            }
                                            AlertService().stopLoading();
                                          }
                                        },
                                      ),
                                      const SizedBox(
                                        height: 8,
                                      ),
                                      _FloatingButton(
                                        icon: Icons.share,
                                        onTap: () {
                                          share(
                                            "Hey there, you can now book tricycles on the PPC TODA app! Here is the download link.",
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 20,
                                  bottom: 20,
                                  child: Column(
                                    children: [
                                      _FloatingButton(
                                        icon: Icons.add,
                                        onTap: () async {
                                          final a = vm.disposed;
                                          final b = vm.markers;
                                          final c = vm.selectedAddress.value;
                                          await vm.zoomIn();
                                          if (!a && b.isEmpty && c == null) {
                                            vm.mapCameraMove(
                                              "zoomIn",
                                              vm.map?.center,
                                            );
                                            debugPrint("HomeView - Map move");
                                          }
                                        },
                                      ),
                                      const SizedBox(
                                        height: 8,
                                      ),
                                      _FloatingButton(
                                        icon: Icons.remove,
                                        onTap: () async {
                                          final a = vm.disposed;
                                          final b = vm.markers;
                                          final c = vm.selectedAddress.value;
                                          await vm.zoomOut();
                                          if (!a && b.isEmpty && c == null) {
                                            vm.mapCameraMove(
                                              "zoomOut",
                                              vm.map?.center,
                                            );
                                            debugPrint("HomeView - Map move");
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                vm.markers.isNotEmpty
                                    ? const SizedBox.shrink()
                                    : const Center(
                                        child: Padding(
                                          padding: EdgeInsets.only(bottom: 40),
                                          child: Icon(
                                            Icons.location_on,
                                            color: Color(
                                              0xFF007BFF,
                                            ),
                                            size: 50,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                ),
                                child: vm.selectedAddress.value == null
                                    ? const SizedBox.shrink()
                                    : Column(
                                        children: [
                                          (gVehicleTypes.isEmpty ||
                                                      locUnavailable) &&
                                                  vm.ongoingOrder == null
                                              ? Column(
                                                  children: [
                                                    Divider(
                                                      height: 1,
                                                      thickness: 1,
                                                      color: const Color(
                                                        0xFF030744,
                                                      ).withOpacity(0.1),
                                                    ),
                                                    const SizedBox(
                                                      height: 20,
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 20,
                                                      ),
                                                      child: Container(
                                                        width: double.infinity
                                                            .clamp(
                                                          0,
                                                          800,
                                                        ),
                                                        height: ((MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width -
                                                                    64) /
                                                                3)
                                                            .clamp(0, 120),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .red.shade50,
                                                          borderRadius:
                                                              const BorderRadius
                                                                  .all(
                                                            Radius.circular(
                                                              8,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 12,
                                                          ),
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .warning,
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    locUnavailable
                                                                        ? "Service location is not available"
                                                                        : "An error occurred, please try again!",
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style:
                                                                        const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color:
                                                                          Color(
                                                                        0xFF030744,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 12,
                                                              ),
                                                              ActionButton(
                                                                onTap: () {
                                                                  vm.closeOrder();
                                                                },
                                                                height: ((MediaQuery.of(context).size.width -
                                                                                64) /
                                                                            3)
                                                                        .clamp(
                                                                            0,
                                                                            120) /
                                                                    3,
                                                                mainColor:
                                                                    Colors.red,
                                                                text: locUnavailable
                                                                    ? "Try another location"
                                                                    : "Retry",
                                                                style:
                                                                    const TextStyle(
                                                                  height: 1.05,
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : vm.ongoingOrder != null &&
                                                      vm.ongoingOrder?.status !=
                                                          "cancelled"
                                                  ? SizedBox(
                                                      height: ((MediaQuery.of(context)
                                                                          .size
                                                                          .width -
                                                                      64) /
                                                                  3)
                                                              .clamp(0, 120) +
                                                          20,
                                                      child: Column(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: vm.ongoingOrder
                                                                            ?.status !=
                                                                        "pending"
                                                                    ? vm.ongoingOrder?.status ==
                                                                            "cancelled"
                                                                        ? Colors
                                                                            .red
                                                                        : Colors
                                                                            .green
                                                                    : const Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        Center(
                                                                      child:
                                                                          Padding(
                                                                        padding:
                                                                            const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              20,
                                                                        ),
                                                                        child:
                                                                            SizedBox(
                                                                          width: double
                                                                              .infinity
                                                                              .clamp(
                                                                            0,
                                                                            800,
                                                                          ),
                                                                          child:
                                                                              Text(
                                                                            "Ride #${vm.ongoingOrder!.id} - ${() {
                                                                              if (vm.ongoingOrder?.status == "pending") {
                                                                                if (vm.ongoingOrder!.driver == null) {
                                                                                  return "Finding a driver";
                                                                                } else {
                                                                                  return "Waiting for driver";
                                                                                }
                                                                              } else if (vm.ongoingOrder?.status == "preparing") {
                                                                                return "Going to pickup";
                                                                              } else if (vm.ongoingOrder?.status == "ready") {
                                                                                return "Arrived at pickup";
                                                                              } else if (vm.ongoingOrder?.status == "enroute") {
                                                                                return "Going to dropoff";
                                                                              } else if (vm.ongoingOrder?.status == "delivered") {
                                                                                return "Completed";
                                                                              } else if (vm.ongoingOrder?.status == "cancelled") {
                                                                                return "Cancelled";
                                                                              } else {
                                                                                return "Connecting";
                                                                              }
                                                                            }()}",
                                                                            style:
                                                                                const TextStyle(
                                                                              height: 1.05,
                                                                              color: Colors.white,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          vm.ongoingOrder!
                                                                      .status !=
                                                                  "pending"
                                                              ? Container(
                                                                  height: 4,
                                                                  color: vm.ongoingOrder
                                                                              ?.status ==
                                                                          "cancelled"
                                                                      ? Colors
                                                                          .red
                                                                          .shade100
                                                                      : Colors
                                                                          .green
                                                                          .shade100,
                                                                )
                                                              : Container(
                                                                  height: 4,
                                                                  color:
                                                                      const Color(
                                                                    0xFF007BFF,
                                                                  ).withOpacity(
                                                                    0.25,
                                                                  ),
                                                                ),
                                                          const SizedBox(
                                                            height: 15,
                                                          ),
                                                          vm.ongoingOrder!
                                                                      .driver ==
                                                                  null
                                                              ? Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .symmetric(
                                                                    horizontal:
                                                                        20,
                                                                  ),
                                                                  child:
                                                                      SizedBox(
                                                                    width: double
                                                                        .infinity
                                                                        .clamp(
                                                                      0,
                                                                      800,
                                                                    ),
                                                                    child:
                                                                        Container(
                                                                      height:
                                                                          50,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color:
                                                                            const Color(
                                                                          0xFF007BFF,
                                                                        ).withOpacity(0.1),
                                                                        borderRadius:
                                                                            const BorderRadius.all(
                                                                          Radius
                                                                              .circular(
                                                                            8,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      child:
                                                                          const Row(
                                                                        children: [
                                                                          SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Icon(
                                                                            Icons.search,
                                                                            color:
                                                                                Color(
                                                                              0xFF007BFF,
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width:
                                                                                8,
                                                                          ),
                                                                          Text(
                                                                            "We are doing our best to find a driver",
                                                                            style:
                                                                                TextStyle(
                                                                              height: 1.05,
                                                                              fontSize: 13,
                                                                              fontWeight: FontWeight.w500,
                                                                              color: Color(
                                                                                0xFF007BFF,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                              : Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .symmetric(
                                                                    horizontal:
                                                                        20,
                                                                  ),
                                                                  child:
                                                                      SizedBox(
                                                                    width: double
                                                                        .infinity
                                                                        .clamp(
                                                                      0,
                                                                      800,
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        GestureDetector(
                                                                          onTap:
                                                                              () {
                                                                            AlertService().showAppAlert(
                                                                              isCustom: true,
                                                                              customWidget: PinchZoom(
                                                                                child: SizedBox(
                                                                                  height: MediaQuery.of(context).size.width - 70,
                                                                                  child: Image.network(
                                                                                    vm.ongoingOrder!.driver?.cPhoto ?? "",
                                                                                    fit: BoxFit.cover,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            );
                                                                          },
                                                                          child:
                                                                              ClipOval(
                                                                            child:
                                                                                SizedBox(
                                                                              width: 48,
                                                                              height: 48,
                                                                              child: NetworkImageWidget(
                                                                                fit: BoxFit.cover,
                                                                                memCacheWidth: 600,
                                                                                imageUrl: vm.ongoingOrder!.driver?.cPhoto ?? "",
                                                                                progressIndicatorBuilder: (
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
                                                                                    color: const Color(
                                                                                      0xFF030744,
                                                                                    ),
                                                                                    child: const Icon(
                                                                                      Icons.person_outline_outlined,
                                                                                      color: Colors.white,
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              12,
                                                                        ),
                                                                        Expanded(
                                                                          child:
                                                                              Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Padding(
                                                                                padding: const EdgeInsets.only(
                                                                                  right: 12,
                                                                                ),
                                                                                child: Text(
                                                                                  capitalizeWords(
                                                                                    vm.ongoingOrder!.driver?.name,
                                                                                    alt: "Driver",
                                                                                  ),
                                                                                  maxLines: 1,
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                  style: const TextStyle(
                                                                                    height: 1.15,
                                                                                    fontWeight: FontWeight.w500,
                                                                                    color: Color(
                                                                                      0xFF030744,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                capitalizeWords(
                                                                                  "${vm.ongoingOrder!.driver?.vehicle?.vehicleInfo}${vm.ongoingOrder!.driver?.franchiseNumber == null ? "" : " | ${vm.ongoingOrder!.driver?.franchiseNumber}"}${vm.ongoingOrder!.driver?.licenseNumber == null ? "" : " | ${vm.ongoingOrder!.driver?.licenseNumber}"}",
                                                                                  alt: "Driver Info",
                                                                                ),
                                                                                style: const TextStyle(
                                                                                  height: 1.15,
                                                                                  fontSize: 12,
                                                                                  fontWeight: FontWeight.w400,
                                                                                  color: Color(
                                                                                    0xFF030744,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              44,
                                                                          height:
                                                                              44,
                                                                          child:
                                                                              WidgetButton(
                                                                            onTap:
                                                                                () {
                                                                              launchUrlString(
                                                                                "tel://${vm.ongoingOrder!.driver?.phone}",
                                                                              );
                                                                            },
                                                                            mainColor:
                                                                                const Color(
                                                                              0xFF007BFF,
                                                                            ),
                                                                            borderRadius:
                                                                                8,
                                                                            useDefaultHoverColor:
                                                                                false,
                                                                            child:
                                                                                const Center(
                                                                              child: Icon(
                                                                                Icons.call,
                                                                                color: Colors.white,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              12,
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              44,
                                                                          height:
                                                                              44,
                                                                          child:
                                                                              WidgetButton(
                                                                            onTap:
                                                                                () {
                                                                              vm.chatDriver();
                                                                            },
                                                                            mainColor:
                                                                                const Color(
                                                                              0xFF007BFF,
                                                                            ),
                                                                            borderRadius:
                                                                                8,
                                                                            useDefaultHoverColor:
                                                                                false,
                                                                            child:
                                                                                const Center(
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
                                                        ],
                                                      ),
                                                    )
                                                  : Column(
                                                      children: [
                                                        Divider(
                                                          height: 1,
                                                          thickness: 1,
                                                          color: const Color(
                                                            0xFF030744,
                                                          ).withOpacity(0.1),
                                                        ),
                                                        const SizedBox(
                                                          height: 20,
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 20,
                                                          ),
                                                          child: SizedBox(
                                                            width: double
                                                                .infinity
                                                                .clamp(
                                                              0,
                                                              800,
                                                            ),
                                                            child: Column(
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    SizedBox(
                                                                      width: ((MediaQuery.of(context).size.width - 64) /
                                                                              3)
                                                                          .clamp(
                                                                              0,
                                                                              120),
                                                                      height: ((MediaQuery.of(context).size.width - 64) /
                                                                              3)
                                                                          .clamp(
                                                                              0,
                                                                              120),
                                                                      child:
                                                                          ConstrainedBox(
                                                                        constraints:
                                                                            const BoxConstraints(
                                                                          maxWidth:
                                                                              200,
                                                                        ),
                                                                        child:
                                                                            Container(
                                                                          height:
                                                                              50,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            borderRadius:
                                                                                const BorderRadius.all(
                                                                              Radius.circular(
                                                                                8,
                                                                              ),
                                                                            ),
                                                                            border:
                                                                                Border.all(
                                                                              color: const Color(
                                                                                0xFF007BFF,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          child:
                                                                              Column(
                                                                            children: [
                                                                              const SizedBox(
                                                                                height: 12,
                                                                              ),
                                                                              Expanded(
                                                                                child: Padding(
                                                                                  padding: const EdgeInsets.symmetric(
                                                                                    horizontal: 8,
                                                                                  ),
                                                                                  child: Image.asset(
                                                                                    "assets/images/${lowerCase(gVehicleTypes.firstWhere(
                                                                                          (v) => v.slug == "tricycle",
                                                                                        ).name!)}.png",
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 8,
                                                                              ),
                                                                              Text(
                                                                                capitalizeWords(
                                                                                  gVehicleTypes
                                                                                      .firstWhere(
                                                                                        (v) => v.slug == "tricycle",
                                                                                      )
                                                                                      .name!,
                                                                                ),
                                                                                style: const TextStyle(
                                                                                  height: 1.05,
                                                                                  fontSize: 16,
                                                                                  color: Color(
                                                                                    0xFF007BFF,
                                                                                  ),
                                                                                  fontWeight: FontWeight.w500,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                "${gVehicleTypes.firstWhere(
                                                                                      (v) => v.slug == "tricycle",
                                                                                    ).maxSeat!} Seater",
                                                                                style: const TextStyle(
                                                                                  height: 1.05,
                                                                                  fontSize: 12,
                                                                                  color: Color(
                                                                                    0xFF007BFF,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 12,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          SizedBox(
                                                                        height: ((MediaQuery.of(context).size.width - 64) / 3).clamp(
                                                                            0,
                                                                            120),
                                                                        child:
                                                                            Column(
                                                                          children: [
                                                                            Expanded(
                                                                              child: WidgetButton(
                                                                                borderRadius: 8,
                                                                                mainColor: vm.paymentMethodId == 1
                                                                                    ? const Color(
                                                                                        0xFF007BFF,
                                                                                      )
                                                                                    : Colors.white,
                                                                                useDefaultHoverColor: false,
                                                                                child: Container(
                                                                                  decoration: BoxDecoration(
                                                                                    borderRadius: const BorderRadius.all(
                                                                                      Radius.circular(
                                                                                        8,
                                                                                      ),
                                                                                    ),
                                                                                    border: Border.all(
                                                                                      color: const Color(
                                                                                        0xFF007BFF,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  child: Center(
                                                                                    child: Text(
                                                                                      "Cash",
                                                                                      textAlign: TextAlign.center,
                                                                                      style: TextStyle(
                                                                                        fontWeight: FontWeight.bold,
                                                                                        color: vm.paymentMethodId == 1
                                                                                            ? Colors.white
                                                                                            : const Color(
                                                                                                0xFF007BFF,
                                                                                              ),
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onTap: () {
                                                                                  if (!AuthService.isLoggedIn()) {
                                                                                    Navigator.push(
                                                                                      Get.overlayContext!,
                                                                                      PageRouteBuilder(
                                                                                        reverseTransitionDuration: Duration.zero,
                                                                                        transitionDuration: Duration.zero,
                                                                                        pageBuilder: (
                                                                                          context,
                                                                                          a,
                                                                                          b,
                                                                                        ) =>
                                                                                            const LoginView(),
                                                                                      ),
                                                                                    );
                                                                                  } else {
                                                                                    setState(() {
                                                                                      vm.paymentMethodId = 1;
                                                                                    });
                                                                                  }
                                                                                },
                                                                              ),
                                                                            ),
                                                                            const SizedBox(
                                                                              height: 15,
                                                                            ),
                                                                            Expanded(
                                                                              child: WidgetButton(
                                                                                borderRadius: 8,
                                                                                mainColor: vm.paymentMethodId != 1
                                                                                    ? const Color(
                                                                                        0xFF007BFF,
                                                                                      )
                                                                                    : Colors.white,
                                                                                useDefaultHoverColor: false,
                                                                                child: Container(
                                                                                  decoration: BoxDecoration(
                                                                                    borderRadius: const BorderRadius.all(
                                                                                      Radius.circular(
                                                                                        8,
                                                                                      ),
                                                                                    ),
                                                                                    border: Border.all(
                                                                                      color: const Color(
                                                                                        0xFF007BFF,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  child: Center(
                                                                                    child: Text(
                                                                                      "Load",
                                                                                      textAlign: TextAlign.center,
                                                                                      style: TextStyle(
                                                                                        fontWeight: FontWeight.bold,
                                                                                        color: vm.paymentMethodId != 1
                                                                                            ? Colors.white
                                                                                            : const Color(
                                                                                                0xFF007BFF,
                                                                                              ),
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onTap: () {
                                                                                  if (!AuthService.isLoggedIn()) {
                                                                                    Navigator.push(
                                                                                      Get.overlayContext!,
                                                                                      PageRouteBuilder(
                                                                                        reverseTransitionDuration: Duration.zero,
                                                                                        transitionDuration: Duration.zero,
                                                                                        pageBuilder: (
                                                                                          context,
                                                                                          a,
                                                                                          b,
                                                                                        ) =>
                                                                                            const LoginView(),
                                                                                      ),
                                                                                    );
                                                                                  } else {
                                                                                    setState(() {
                                                                                      vm.paymentMethodId = 2;
                                                                                    });
                                                                                  }
                                                                                },
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    WidgetButton(
                                                                      onTap:
                                                                          () {
                                                                        if (!AuthService
                                                                            .isLoggedIn()) {
                                                                          Navigator
                                                                              .push(
                                                                            context,
                                                                            PageRouteBuilder(
                                                                              reverseTransitionDuration: Duration.zero,
                                                                              transitionDuration: Duration.zero,
                                                                              pageBuilder: (
                                                                                context,
                                                                                a,
                                                                                b,
                                                                              ) =>
                                                                                  const LoginView(),
                                                                            ),
                                                                          );
                                                                        } else {
                                                                          Navigator
                                                                              .push(
                                                                            context,
                                                                            PageRouteBuilder(
                                                                              reverseTransitionDuration: Duration.zero,
                                                                              transitionDuration: Duration.zero,
                                                                              pageBuilder: (
                                                                                context,
                                                                                a,
                                                                                b,
                                                                              ) =>
                                                                                  const LoadView(),
                                                                            ),
                                                                          );
                                                                        }
                                                                      },
                                                                      borderRadius:
                                                                          8,
                                                                      child:
                                                                          SizedBox(
                                                                        width: ((MediaQuery.of(context).size.width - 64) / 3).clamp(
                                                                            0,
                                                                            120),
                                                                        height: ((MediaQuery.of(context).size.width - 64) / 3).clamp(
                                                                            0,
                                                                            120),
                                                                        child:
                                                                            ConstrainedBox(
                                                                          constraints:
                                                                              const BoxConstraints(
                                                                            maxWidth:
                                                                                200,
                                                                          ),
                                                                          child:
                                                                              Container(
                                                                            height:
                                                                                50,
                                                                            decoration:
                                                                                BoxDecoration(
                                                                              borderRadius: const BorderRadius.all(
                                                                                Radius.circular(
                                                                                  8,
                                                                                ),
                                                                              ),
                                                                              border: Border.all(
                                                                                color: const Color(
                                                                                  0xFF007BFF,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            child:
                                                                                Column(
                                                                              children: [
                                                                                const SizedBox(
                                                                                  height: 12,
                                                                                ),
                                                                                Expanded(
                                                                                  child: Padding(
                                                                                    padding: const EdgeInsets.symmetric(
                                                                                      horizontal: 8,
                                                                                    ),
                                                                                    child: Image.asset(
                                                                                      "assets/images/load.png",
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(
                                                                                  height: 8,
                                                                                ),
                                                                                Text(
                                                                                  "₱${gLoad == null ? AuthService.isLoggedIn() ? "•••" : "0" : gLoad?.balance?.toStringAsFixed(0)}",
                                                                                  style: const TextStyle(
                                                                                    height: 1.05,
                                                                                    fontSize: 16,
                                                                                    color: Color(
                                                                                      0xFF007BFF,
                                                                                    ),
                                                                                    fontWeight: FontWeight.w500,
                                                                                  ),
                                                                                ),
                                                                                const Text(
                                                                                  "TODA Load",
                                                                                  style: TextStyle(
                                                                                    height: 1.05,
                                                                                    fontSize: 12,
                                                                                    color: Color(
                                                                                      0xFF007BFF,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(
                                                                                  height: 12,
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            child: SizedBox(
                                              width: double.infinity.clamp(
                                                0,
                                                800,
                                              ),
                                              child: GestureDetector(
                                                onTap: () async {
                                                  if (!AuthService
                                                      .isLoggedIn()) {
                                                    Navigator.push(
                                                      context,
                                                      PageRouteBuilder(
                                                        reverseTransitionDuration:
                                                            Duration.zero,
                                                        transitionDuration:
                                                            Duration.zero,
                                                        pageBuilder: (
                                                          context,
                                                          a,
                                                          b,
                                                        ) =>
                                                            const LoginView(),
                                                      ),
                                                    );
                                                  } else {
                                                    if (vm.ongoingOrder ==
                                                            null ||
                                                        vm.ongoingOrder
                                                                ?.status ==
                                                            "cancelled") {
                                                      var rebuild =
                                                          await Navigator.push(
                                                        context,
                                                        PageRouteBuilder(
                                                          reverseTransitionDuration:
                                                              Duration.zero,
                                                          transitionDuration:
                                                              Duration.zero,
                                                          pageBuilder: (
                                                            context,
                                                            a,
                                                            b,
                                                          ) =>
                                                              const MapView(
                                                            isPickup: true,
                                                          ),
                                                        ),
                                                      );
                                                      if (mounted &&
                                                          rebuild == true) {
                                                        setState(() {});
                                                      }
                                                      if (pickupAddress !=
                                                                  null &&
                                                              dropoffAddress !=
                                                                  null &&
                                                              vm.ongoingOrder ==
                                                                  null ||
                                                          vm.ongoingOrder
                                                                  ?.status ==
                                                              "cancelled") {
                                                        setState(() {
                                                          vm.isPreparing = true;
                                                        });
                                                        await vm
                                                            .drawDropPolyLines(
                                                          "pickup-dropoff",
                                                          pickupAddress!.latLng,
                                                          dropoffAddress!
                                                              .latLng,
                                                          null,
                                                        );
                                                        await vm
                                                            .fetchVehicleTypesPricing();
                                                        setState(() {
                                                          vm.isPreparing =
                                                              false;
                                                        });
                                                      } else {
                                                        setState(() {
                                                          vm.map!.center =
                                                              pickupAddress!
                                                                  .latLng;
                                                        });
                                                      }
                                                    }
                                                  }
                                                },
                                                child: Container(
                                                  height: 50,
                                                  decoration:
                                                      const BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.all(
                                                      Radius.circular(
                                                        8,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                      const Icon(
                                                        Icons.trip_origin,
                                                        color: Color(
                                                          0xFF007BFF,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: 8,
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          capitalizeWords(
                                                            pickupAddress
                                                                ?.addressLine,
                                                            alt: "Where from?",
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                              0xFF030744,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            child: SizedBox(
                                              height: vm.ongoingOrder != null
                                                  ? 30
                                                  : null,
                                              width: double.infinity.clamp(
                                                0,
                                                800,
                                              ),
                                              child: WidgetButton(
                                                onTap: () async {
                                                  if (!AuthService
                                                      .isLoggedIn()) {
                                                    Navigator.push(
                                                      context,
                                                      PageRouteBuilder(
                                                        reverseTransitionDuration:
                                                            Duration.zero,
                                                        transitionDuration:
                                                            Duration.zero,
                                                        pageBuilder: (
                                                          context,
                                                          a,
                                                          b,
                                                        ) =>
                                                            const LoginView(),
                                                      ),
                                                    );
                                                  } else {
                                                    if (vm.ongoingOrder ==
                                                            null ||
                                                        vm.ongoingOrder
                                                                ?.status ==
                                                            "cancelled") {
                                                      var rebuild =
                                                          await Navigator.push(
                                                        context,
                                                        PageRouteBuilder(
                                                          reverseTransitionDuration:
                                                              Duration.zero,
                                                          transitionDuration:
                                                              Duration.zero,
                                                          pageBuilder: (
                                                            context,
                                                            a,
                                                            b,
                                                          ) =>
                                                              const MapView(
                                                            isPickup: false,
                                                          ),
                                                        ),
                                                      );
                                                      if (mounted &&
                                                          rebuild == true) {
                                                        setState(() {});
                                                      }
                                                      if (pickupAddress !=
                                                                  null &&
                                                              dropoffAddress !=
                                                                  null &&
                                                              vm.ongoingOrder ==
                                                                  null ||
                                                          vm.ongoingOrder
                                                                  ?.status ==
                                                              "cancelled") {
                                                        setState(() {
                                                          vm.isPreparing = true;
                                                        });
                                                        await vm
                                                            .drawDropPolyLines(
                                                          "pickup-dropoff",
                                                          pickupAddress!.latLng,
                                                          dropoffAddress!
                                                              .latLng,
                                                          null,
                                                        );
                                                        await vm
                                                            .fetchVehicleTypesPricing();
                                                        setState(() {
                                                          vm.isPreparing =
                                                              false;
                                                        });
                                                      }
                                                    }
                                                  }
                                                },
                                                borderRadius: 8,
                                                useDefaultHoverColor: false,
                                                disableGestureDetection:
                                                    vm.ongoingOrder != null,
                                                mainColor: vm.ongoingOrder !=
                                                        null
                                                    ? Colors.white
                                                    : const Color(0xFFEAF1FE),
                                                child: SizedBox(
                                                  height: 50,
                                                  child: Row(
                                                    children: [
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
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
                                                            dropoffAddress
                                                                ?.addressLine,
                                                            alt: "Where to go?",
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                              0xFF030744,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 15),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            child: SizedBox(
                                              width: double.infinity.clamp(
                                                0,
                                                800,
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width:
                                                        ((MediaQuery.of(context)
                                                                        .size
                                                                        .width -
                                                                    64) /
                                                                3)
                                                            .clamp(0, 120),
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                        maxWidth: 200,
                                                      ),
                                                      child: Container(
                                                        height: 50,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              const BorderRadius
                                                                  .all(
                                                            Radius.circular(
                                                              8,
                                                            ),
                                                          ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFF007BFF,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            vm.ongoingOrder !=
                                                                        null &&
                                                                    vm.ongoingOrder!
                                                                            .status !=
                                                                        "cancelled"
                                                                ? () {
                                                                    if (vm.ongoingOrder
                                                                            ?.status ==
                                                                        "pending") {
                                                                      return "Waiting";
                                                                    } else if (vm
                                                                            .ongoingOrder
                                                                            ?.status ==
                                                                        "preparing") {
                                                                      return capitalizeWords(
                                                                        (vm.ongoingOrder!.taxiOrder?.tripDetails?.eta ?? "").toLowerCase().contains("any") ||
                                                                                (vm.ongoingOrder!.taxiOrder?.tripDetails?.eta ?? "").toLowerCase().contains("unknown")
                                                                            ? "Any Second"
                                                                            : formatEtaText(vm.ongoingOrder!.taxiOrder!.tripDetails!.eta!),
                                                                      );
                                                                    } else {
                                                                      return travelTime(
                                                                        vm.ongoingOrder!.taxiOrder?.tripDetails?.kmDistance ??
                                                                            0,
                                                                      );
                                                                    }
                                                                  }()
                                                                : vm.selectedVehicle ==
                                                                        null
                                                                    ? vm.isPreparing
                                                                        ? "•••"
                                                                        : "Time"
                                                                    : vm.isPreparing
                                                                        ? "•••"
                                                                        : travelTime(
                                                                            vm.selectedVehicle?.kmDistance ??
                                                                                0,
                                                                          ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                0xFF007BFF,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 15),
                                                  Expanded(
                                                    child: ActionButton(
                                                      text: vm.ongoingOrder !=
                                                                  null &&
                                                              vm.ongoingOrder!
                                                                      .status !=
                                                                  "cancelled"
                                                          ? vm.ongoingOrder
                                                                          ?.status ==
                                                                      "enroute" ||
                                                                  vm.ongoingOrder
                                                                          ?.status ==
                                                                      "preparing" ||
                                                                  vm.ongoingOrder
                                                                          ?.status ==
                                                                      "delivered"
                                                              ? "REPORT"
                                                              : "CANCEL"
                                                          : "BOOK",
                                                      mainColor: vm.isPreparing
                                                          ? const Color(
                                                              0xFF030744,
                                                            ).withOpacity(0.2)
                                                          : vm.ongoingOrder !=
                                                                      null &&
                                                                  vm.ongoingOrder!
                                                                          .status !=
                                                                      "cancelled"
                                                              ? Colors
                                                                  .red.shade100
                                                              : const Color(
                                                                  0xFF007BFF,
                                                                ),
                                                      onTap: () async {
                                                        if (!AuthService
                                                            .isLoggedIn()) {
                                                          Navigator.push(
                                                            context,
                                                            PageRouteBuilder(
                                                              reverseTransitionDuration:
                                                                  Duration.zero,
                                                              transitionDuration:
                                                                  Duration.zero,
                                                              pageBuilder: (
                                                                context,
                                                                a,
                                                                b,
                                                              ) =>
                                                                  const LoginView(),
                                                            ),
                                                          );
                                                        } else {
                                                          FocusManager.instance
                                                              .primaryFocus
                                                              ?.unfocus();
                                                          if (vm.isPreparing ||
                                                              vm.ongoingOrder
                                                                      ?.status ==
                                                                  "cancelled") {
                                                            ScaffoldMessenger
                                                                .of(
                                                              Get.overlayContext!,
                                                            ).clearSnackBars();
                                                            ScaffoldMessenger
                                                                .of(
                                                              Get.overlayContext!,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                backgroundColor:
                                                                    Colors
                                                                        .green,
                                                                content: Text(
                                                                  "Finalizing your details, please wait ...",
                                                                  style:
                                                                      TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          } else if (vm
                                                                  .ongoingOrder ==
                                                              null) {
                                                            if (!vm.busy(vm
                                                                .vehicleTypes)) {
                                                              vm.processNewOrder();
                                                            }
                                                          } else {
                                                            if (vm.ongoingOrder?.status == "enroute" ||
                                                                vm.ongoingOrder
                                                                        ?.status ==
                                                                    "preparing" ||
                                                                vm.ongoingOrder
                                                                        ?.status ==
                                                                    "delivered") {
                                                              setState(() {
                                                                vm.showReport =
                                                                    true;
                                                              });
                                                            } else {
                                                              vm.cancelOrder();
                                                            }
                                                          }
                                                        }
                                                      },
                                                      style: TextStyle(
                                                        height: 1.05,
                                                        fontSize: vm.ongoingOrder !=
                                                                    null &&
                                                                vm.ongoingOrder!
                                                                        .status !=
                                                                    "cancelled"
                                                            ? null
                                                            : 18,
                                                        color: vm.ongoingOrder !=
                                                                    null &&
                                                                vm.ongoingOrder!
                                                                        .status !=
                                                                    "cancelled"
                                                            ? Colors.red
                                                            : Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 15),
                                                  SizedBox(
                                                    width:
                                                        ((MediaQuery.of(context)
                                                                        .size
                                                                        .width -
                                                                    64) /
                                                                3)
                                                            .clamp(0, 120),
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                        maxWidth: 200,
                                                      ),
                                                      child: Container(
                                                        height: 50,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              const BorderRadius
                                                                  .all(
                                                            Radius.circular(
                                                              8,
                                                            ),
                                                          ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFF007BFF,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            vm.ongoingOrder !=
                                                                        null &&
                                                                    vm.ongoingOrder!
                                                                            .status !=
                                                                        "cancelled"
                                                                ? AuthService
                                                                        .inReviewMode()
                                                                    ? vm
                                                                            .isPreparing
                                                                        ? "•••"
                                                                        : "${vm.ongoingOrder!.taxiOrder?.tripDetails?.kmDistance?.toStringAsFixed(1)} km"
                                                                    : vm
                                                                            .isPreparing
                                                                        ? "•••"
                                                                        : "${((vm.ongoingOrder!.subTotal ?? 0) + (vm.ongoingOrder!.taxiOrder?.pickupFee ?? 0)).toStringAsFixed(0)} ${vm.ongoingOrder!.paymentMethodId == 1 ? "Cash" : "Load"}"
                                                                : vm.selectedVehicle ==
                                                                        null
                                                                    ? AuthService
                                                                            .inReviewMode()
                                                                        ? vm.isPreparing
                                                                            ? "•••"
                                                                            : "Dist"
                                                                        : vm.isPreparing
                                                                            ? "•••"
                                                                            : "Fare"
                                                                    : AuthService.inReviewMode()
                                                                        ? vm.isPreparing
                                                                            ? "•••"
                                                                            : "${vm.selectedVehicle?.kmDistance?.toStringAsFixed(1)} km"
                                                                        : vm.isPreparing
                                                                            ? "•••"
                                                                            : "${vm.selectedVehicle?.total?.toStringAsFixed(0)} ${vm.paymentMethodId == 1 ? "Cash" : "Load"}",
                                                            textAlign: TextAlign
                                                                .center,
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                0xFF007BFF,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 20,
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      !vm.isLoading && !vm.isInitializing
                          ? const SizedBox.shrink()
                          : Positioned(
                              left: 0,
                              right: 0,
                              bottom: 20,
                              child: SizedBox(
                                width: 45,
                                height: 45,
                                child: Center(
                                  child: SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeCap: StrokeCap.round,
                                      color: const Color(
                                        0xFF007BFF,
                                      ),
                                      backgroundColor: const Color(
                                        0xFF007BFF,
                                      ).withOpacity(0.25),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      vm.ongoingOrder == null ||
                              vm.ongoingOrder?.status == "cancelled"
                          ? const SizedBox.shrink()
                          : !vm.showReport &&
                                  vm.lastStatus != "delivered" &&
                                  vm.ongoingOrder?.status != "delivered"
                              ? const SizedBox.shrink()
                              : !vm.showReport
                                  ? bookingId != vm.ongoingOrder?.id
                                      ? const SizedBox.shrink()
                                      : Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            color: const Color(
                                              0xFF007BFF,
                                            ),
                                            child: Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                ),
                                                child: SizedBox(
                                                  width: double.infinity.clamp(
                                                    0,
                                                    800,
                                                  ),
                                                  child: Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.all(
                                                        Radius.circular(
                                                          12,
                                                        ),
                                                      ),
                                                    ),
                                                    child:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const SizedBox(
                                                            height: 20,
                                                          ),
                                                          GestureDetector(
                                                            onTap: () {
                                                              AlertService()
                                                                  .showAppAlert(
                                                                isCustom: true,
                                                                customWidget:
                                                                    PinchZoom(
                                                                  child:
                                                                      SizedBox(
                                                                    height: MediaQuery.of(context)
                                                                            .size
                                                                            .width -
                                                                        70,
                                                                    child: Image
                                                                        .network(
                                                                      vm.ongoingOrder?.driver
                                                                              ?.cPhoto ??
                                                                          "",
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            child: ClipOval(
                                                              child: SizedBox(
                                                                width: 80,
                                                                height: 80,
                                                                child:
                                                                    NetworkImageWidget(
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  memCacheWidth:
                                                                      600,
                                                                  imageUrl: vm
                                                                          .ongoingOrder
                                                                          ?.driver
                                                                          ?.cPhoto ??
                                                                      "",
                                                                  progressIndicatorBuilder:
                                                                      (
                                                                    context,
                                                                    imageUrl,
                                                                    progress,
                                                                  ) {
                                                                    return const CircularProgressIndicator(
                                                                      color:
                                                                          Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                                      strokeWidth:
                                                                          2,
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
                                                                      child:
                                                                          const Icon(
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
                                                          ),
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
                                                          Text(
                                                            capitalizeWords(
                                                              vm
                                                                  .ongoingOrder
                                                                  ?.driver
                                                                  ?.name,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                              height: 1.15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Color(
                                                                0xFF030744,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            capitalizeWords(
                                                              "${vm.ongoingOrder?.driver?.vehicle?.vehicleInfo}${vm.ongoingOrder?.driver?.franchiseNumber == null ? "" : "\n${vm.ongoingOrder?.driver?.franchiseNumber}"}${vm.ongoingOrder?.driver?.licenseNumber == null ? "" : " | ${vm.ongoingOrder?.driver?.licenseNumber}"}",
                                                              alt:
                                                                  "Driver Info",
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style:
                                                                const TextStyle(
                                                              height: 1.15,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              color: Color(
                                                                0xFF030744,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 16),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 20,
                                                            ),
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .white,
                                                                borderRadius:
                                                                    const BorderRadius
                                                                        .all(
                                                                  Radius
                                                                      .circular(
                                                                    12,
                                                                  ),
                                                                ),
                                                                border:
                                                                    Border.all(
                                                                  width: 1,
                                                                  color:
                                                                      const Color(
                                                                    0xFF030744,
                                                                  ).withOpacity(
                                                                    0.15,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Column(
                                                                children: [
                                                                  const SizedBox(
                                                                      height:
                                                                          16),
                                                                  Container(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color:
                                                                          () {
                                                                        final status = vm
                                                                            .ongoingOrder
                                                                            ?.status;
                                                                        if (status ==
                                                                            "pending") {
                                                                          return Colors
                                                                              .blue
                                                                              .shade100;
                                                                        } else if (status ==
                                                                            "preparing") {
                                                                          return Colors
                                                                              .blue
                                                                              .shade100;
                                                                        } else if (status ==
                                                                            "ready") {
                                                                          return Colors
                                                                              .blue
                                                                              .shade100;
                                                                        } else if (status ==
                                                                            "enroute") {
                                                                          return Colors
                                                                              .blue
                                                                              .shade100;
                                                                        } else if (status ==
                                                                            "failed") {
                                                                          return Colors
                                                                              .red
                                                                              .shade100;
                                                                        } else if (status ==
                                                                            "cancelled") {
                                                                          return Colors
                                                                              .red
                                                                              .shade100;
                                                                        } else if (status ==
                                                                            "delivered") {
                                                                          return Colors
                                                                              .green
                                                                              .shade100;
                                                                        } else {
                                                                          return Colors
                                                                              .blue
                                                                              .shade100;
                                                                        }
                                                                      }(),
                                                                      borderRadius:
                                                                          const BorderRadius
                                                                              .all(
                                                                        Radius.circular(
                                                                            4),
                                                                      ),
                                                                    ),
                                                                    child:
                                                                        Padding(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .symmetric(
                                                                        vertical:
                                                                            4,
                                                                        horizontal:
                                                                            8,
                                                                      ),
                                                                      child:
                                                                          Text(
                                                                        () {
                                                                          final status = vm
                                                                              .ongoingOrder
                                                                              ?.status;
                                                                          if (status ==
                                                                              "pending") {
                                                                            return "Searching";
                                                                          } else if (status ==
                                                                              "preparing") {
                                                                            return "Waiting";
                                                                          } else if (status ==
                                                                              "ready") {
                                                                            return "Arrived";
                                                                          } else if (status ==
                                                                              "enroute") {
                                                                            return "Navigating";
                                                                          } else if (status ==
                                                                              "failed") {
                                                                            return "Failed";
                                                                          } else if (status ==
                                                                              "cancelled") {
                                                                            return "Cancelled";
                                                                          } else if (status ==
                                                                              "delivered") {
                                                                            return "Completed";
                                                                          } else {
                                                                            return "Connecting";
                                                                          }
                                                                        }(),
                                                                        style:
                                                                            TextStyle(
                                                                          height:
                                                                              1,
                                                                          fontSize:
                                                                              13,
                                                                          fontWeight:
                                                                              FontWeight.w400,
                                                                          color:
                                                                              () {
                                                                            final status =
                                                                                vm.ongoingOrder?.status;
                                                                            if (status ==
                                                                                "pending") {
                                                                              return Colors.blue;
                                                                            } else if (status ==
                                                                                "preparing") {
                                                                              return Colors.blue;
                                                                            } else if (status ==
                                                                                "ready") {
                                                                              return Colors.blue;
                                                                            } else if (status ==
                                                                                "enroute") {
                                                                              return Colors.blue;
                                                                            } else if (status ==
                                                                                "failed") {
                                                                              return Colors.red;
                                                                            } else if (status ==
                                                                                "cancelled") {
                                                                              return Colors.red;
                                                                            } else if (status ==
                                                                                "delivered") {
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
                                                                    "Ride #${vm.ongoingOrder?.id}",
                                                                    style:
                                                                        const TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color:
                                                                          Color(
                                                                        0xFF030744,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    DateFormat(
                                                                      "MMMM dd, yyy - h:mm a",
                                                                    ).format(
                                                                      vm.ongoingOrder
                                                                              ?.createdAt ??
                                                                          DateTime
                                                                              .now(),
                                                                    ),
                                                                    style:
                                                                        const TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          12,
                                                                      color:
                                                                          Color(
                                                                        0xFF030744,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          16),
                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                    ),
                                                                    child:
                                                                        Divider(
                                                                      height: 1,
                                                                      thickness:
                                                                          1,
                                                                      color:
                                                                          const Color(
                                                                        0xFF030744,
                                                                      ).withOpacity(
                                                                        0.15,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 14,
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                      ClipOval(
                                                                        child: Image
                                                                            .asset(
                                                                          AppImages
                                                                              .logo,
                                                                          height:
                                                                              28,
                                                                          width:
                                                                              28,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                          width:
                                                                              6),
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          "${capitalizeWords(
                                                                            vm.ongoingOrder?.driver?.vehicle?.vehicleType?.name,
                                                                            alt:
                                                                                "Failed",
                                                                          )} Booking",
                                                                          style:
                                                                              const TextStyle(
                                                                            height:
                                                                                1,
                                                                            fontSize:
                                                                                14,
                                                                            color:
                                                                                Color(
                                                                              0xFF030744,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const Text(
                                                                        "Via App",
                                                                        style:
                                                                            TextStyle(
                                                                          height:
                                                                              1,
                                                                          fontSize:
                                                                              14,
                                                                          color:
                                                                              Colors.green,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            14,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 14,
                                                                  ),
                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                    ),
                                                                    child:
                                                                        Divider(
                                                                      height: 1,
                                                                      thickness:
                                                                          1,
                                                                      color:
                                                                          const Color(
                                                                        0xFF030744,
                                                                      ).withOpacity(
                                                                        0.15,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 14,
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            14,
                                                                      ),
                                                                      const Icon(
                                                                        Icons
                                                                            .trip_origin,
                                                                        color:
                                                                            Color(
                                                                          0xFF007BFF,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          capitalizeWords(
                                                                            vm.ongoingOrder?.taxiOrder?.pickupAddress,
                                                                          ),
                                                                          maxLines:
                                                                              1,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                          style:
                                                                              const TextStyle(
                                                                            color:
                                                                                Color(
                                                                              0xFF030744,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            14,
                                                                      ),
                                                                      const Icon(
                                                                        Icons
                                                                            .trip_origin,
                                                                        color: Colors
                                                                            .red,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          capitalizeWords(
                                                                            vm.ongoingOrder?.taxiOrder?.dropoffAddress,
                                                                          ),
                                                                          maxLines:
                                                                              1,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                          style:
                                                                              const TextStyle(
                                                                            color:
                                                                                Color(
                                                                              0xFF030744,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 14,
                                                                  ),
                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                    ),
                                                                    child:
                                                                        Divider(
                                                                      height: 1,
                                                                      thickness:
                                                                          1,
                                                                      color:
                                                                          const Color(
                                                                        0xFF030744,
                                                                      ).withOpacity(
                                                                        0.15,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 12,
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            14,
                                                                      ),
                                                                      Padding(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                          1,
                                                                        ),
                                                                        child:
                                                                            Container(
                                                                          width:
                                                                              21,
                                                                          height:
                                                                              21,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            border:
                                                                                Border.all(
                                                                              color: Colors.green,
                                                                              width: 2,
                                                                            ),
                                                                            borderRadius:
                                                                                const BorderRadius.all(
                                                                              Radius.circular(
                                                                                1000,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          child:
                                                                              const Center(
                                                                            child:
                                                                                Text(
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
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      const Text(
                                                                        "Total Fare",
                                                                        style:
                                                                            TextStyle(
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const Expanded(
                                                                        child: SizedBox
                                                                            .shrink(),
                                                                      ),
                                                                      Text(
                                                                        "₱${((vm.ongoingOrder?.subTotal ?? 0) + (vm.ongoingOrder?.taxiOrder?.pickupFee ?? 0)).toStringAsFixed(0)}",
                                                                        style:
                                                                            const TextStyle(
                                                                          color:
                                                                              Colors.green,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            14,
                                                                      ),
                                                                      const Icon(
                                                                        Icons
                                                                            .credit_score_outlined,
                                                                        color: Colors
                                                                            .green,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      const Text(
                                                                        "Payment Method",
                                                                        style:
                                                                            TextStyle(
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const Expanded(
                                                                        child: SizedBox
                                                                            .shrink(),
                                                                      ),
                                                                      Text(
                                                                        vm.ongoingOrder?.paymentMethodId ==
                                                                                1
                                                                            ? "Cash"
                                                                            : "Load",
                                                                        style:
                                                                            const TextStyle(
                                                                          color:
                                                                              Colors.green,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            14,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 14,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 20,
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 20,
                                                            ),
                                                            child: ActionButton(
                                                              onTap: () {
                                                                vm.closeOrder();
                                                              },
                                                              mainColor:
                                                                  const Color(
                                                                0xFF007BFF,
                                                              ).withOpacity(
                                                                0.1,
                                                              ),
                                                              text:
                                                                  "Return to home",
                                                              style:
                                                                  const TextStyle(
                                                                height: 1,
                                                                fontSize: 15,
                                                                color: Color(
                                                                  0xFF007BFF,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 20,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                  : Positioned(
                                      child: GestureDetector(
                                        onTap: () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          setState(() {
                                            vm.showReport = false;
                                          });
                                        },
                                        child: Container(
                                          height: !keyboardOpen
                                              ? MediaQuery.of(context)
                                                  .size
                                                  .height
                                              : MediaQuery.of(context)
                                                      .size
                                                      .height -
                                                  MediaQuery.of(context)
                                                      .viewInsets
                                                      .bottom,
                                          width:
                                              MediaQuery.of(context).size.width,
                                          color: Colors.black.withOpacity(
                                            0.8,
                                          ),
                                          child: Center(
                                            child: SingleChildScrollView(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 36,
                                                ),
                                                child: SizedBox(
                                                  width: double.infinity.clamp(
                                                    0,
                                                    800,
                                                  ),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      FocusManager
                                                          .instance.primaryFocus
                                                          ?.unfocus();
                                                    },
                                                    child: Padding(
                                                      padding: EdgeInsets.only(
                                                        top: MediaQuery.of(
                                                                context)
                                                            .padding
                                                            .top,
                                                      ),
                                                      child: Container(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width -
                                                            80,
                                                        decoration:
                                                            const BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.all(
                                                            Radius.circular(
                                                              12,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            const SizedBox(
                                                              height: 20,
                                                            ),
                                                            GestureDetector(
                                                              onTap: () {
                                                                AlertService()
                                                                    .showAppAlert(
                                                                  isCustom:
                                                                      true,
                                                                  customWidget:
                                                                      PinchZoom(
                                                                    child:
                                                                        SizedBox(
                                                                      height: MediaQuery.of(context)
                                                                              .size
                                                                              .width -
                                                                          70,
                                                                      child: Image
                                                                          .network(
                                                                        vm.ongoingOrder?.driver?.cPhoto ??
                                                                            "",
                                                                        fit: BoxFit
                                                                            .cover,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              child: ClipOval(
                                                                child: SizedBox(
                                                                  width: 80,
                                                                  height: 80,
                                                                  child:
                                                                      NetworkImageWidget(
                                                                    fit: BoxFit
                                                                        .cover,
                                                                    memCacheWidth:
                                                                        600,
                                                                    imageUrl: vm
                                                                            .ongoingOrder
                                                                            ?.driver
                                                                            ?.cPhoto ??
                                                                        "",
                                                                    progressIndicatorBuilder:
                                                                        (
                                                                      context,
                                                                      imageUrl,
                                                                      progress,
                                                                    ) {
                                                                      return const CircularProgressIndicator(
                                                                        color:
                                                                            Color(
                                                                          0xFF007BFF,
                                                                        ),
                                                                        strokeWidth:
                                                                            2,
                                                                      );
                                                                    },
                                                                    errorWidget:
                                                                        (
                                                                      context,
                                                                      imageUrl,
                                                                      progress,
                                                                    ) {
                                                                      return Container(
                                                                        color:
                                                                            const Color(
                                                                          0xFF030744,
                                                                        ),
                                                                        child:
                                                                            const Icon(
                                                                          Icons
                                                                              .person_outline_outlined,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 16),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 20,
                                                              ),
                                                              child: Text(
                                                                capitalizeWords(
                                                                  vm
                                                                      .ongoingOrder
                                                                      ?.driver
                                                                      ?.name,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    const TextStyle(
                                                                  height: 1.15,
                                                                  fontSize: 16,
                                                                  fontFamily:
                                                                      "Inter",
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 20,
                                                              ),
                                                              child: Text(
                                                                capitalizeWords(
                                                                  "${vm.ongoingOrder?.driver?.vehicle?.vehicleInfo}${vm.ongoingOrder?.driver?.franchiseNumber == null ? "" : " | ${vm.ongoingOrder?.driver?.franchiseNumber}"}${vm.ongoingOrder?.driver?.licenseNumber == null ? "" : " | ${vm.ongoingOrder?.driver?.licenseNumber}"}",
                                                                  alt:
                                                                      "Driver Info",
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    const TextStyle(
                                                                  height: 1.15,
                                                                  fontFamily:
                                                                      "Inter",
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 20,
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 20,
                                                              ),
                                                              child:
                                                                  TextFieldWidget(
                                                                controller: vm
                                                                    .reviewTEC,
                                                                floatLabel:
                                                                    false,
                                                                hintText:
                                                                    "Please tell us what happened",
                                                                labelText:
                                                                    "Please tell us what happened",
                                                                textCapitalization:
                                                                    TextCapitalization
                                                                        .sentences,
                                                                keyboardType:
                                                                    TextInputType
                                                                        .text,
                                                                textInputAction:
                                                                    TextInputAction
                                                                        .done,
                                                                obscureText:
                                                                    false,
                                                                showPrefix:
                                                                    false,
                                                                showSuffix:
                                                                    false,
                                                                prefixText:
                                                                    null,
                                                                suffixIcon:
                                                                    null,
                                                                onSuffixTap:
                                                                    null,
                                                                autoFocus:
                                                                    false,
                                                                maxLines: null,
                                                                minLines: 3,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 20,
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 20,
                                                              ),
                                                              child:
                                                                  ActionButton(
                                                                onTap: () {
                                                                  FocusManager
                                                                      .instance
                                                                      .primaryFocus
                                                                      ?.unfocus();
                                                                  vm.reportDriver();
                                                                },
                                                                mainColor:
                                                                    Colors.red,
                                                                text:
                                                                    "Report Driver",
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 15,
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 20,
                                                            ),
                                                            RichText(
                                                              text: TextSpan(
                                                                children: [
                                                                  TextSpan(
                                                                    text:
                                                                        "Need help? ",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      color:
                                                                          const Color(
                                                                        0xFF030744,
                                                                      ).withOpacity(
                                                                        0.5,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        "Contact",
                                                                    style:
                                                                        const TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                                    ),
                                                                    recognizer:
                                                                        TapGestureRecognizer()
                                                                          ..onTap =
                                                                              () {
                                                                            launchUrlString(
                                                                              "sms://+639122078420",
                                                                            );
                                                                          },
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        " or ",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      color:
                                                                          const Color(
                                                                        0xFF030744,
                                                                      ).withOpacity(
                                                                        0.5,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        "Message",
                                                                    style:
                                                                        const TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                                    ),
                                                                    recognizer:
                                                                        TapGestureRecognizer()
                                                                          ..onTap =
                                                                              () {
                                                                            launchUrlString(
                                                                              "https://www.facebook.com/ppctodaofficial",
                                                                            );
                                                                          },
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        " us!",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      color:
                                                                          const Color(
                                                                        0xFF030744,
                                                                      ).withOpacity(
                                                                        0.5,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 20,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                      isBool(vm.userSeen) ||
                              vm.dvrMessage == null ||
                              vm.dvrMessage == "null" ||
                              vm.ongoingOrder == null ||
                              vm.ongoingOrder?.status == "cancelled" ||
                              vm.dvrMessage == "null" ||
                              vm.dvrMessage == ""
                          ? const SizedBox.shrink()
                          : Container(
                              color: Colors.black.withOpacity(
                                0.5,
                              ),
                            ),
                      isBool(vm.userSeen) ||
                              vm.dvrMessage == null ||
                              vm.dvrMessage == "null" ||
                              vm.ongoingOrder == null ||
                              vm.ongoingOrder?.status == "cancelled" ||
                              vm.dvrMessage == "null" ||
                              vm.dvrMessage == ""
                          ? const SizedBox.shrink()
                          : Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(
                                        20,
                                      ),
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              AlertService().showAppAlert(
                                                isCustom: true,
                                                customWidget: PinchZoom(
                                                  child: SizedBox(
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width -
                                                            70,
                                                    child: Image.network(
                                                      vm.ongoingOrder?.driver
                                                              ?.cPhoto ??
                                                          "",
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
                                                  imageUrl: vm.ongoingOrder
                                                          ?.driver?.cPhoto ??
                                                      "",
                                                  progressIndicatorBuilder: (
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
                                                      color: const Color(
                                                        0xFF030744,
                                                      ),
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
                                          const SizedBox(
                                            width: 12,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  capitalizeWords(
                                                    vm.ongoingOrder?.driver
                                                        ?.name,
                                                    alt: "Driver",
                                                  ),
                                                  style: const TextStyle(
                                                    height: 1.15,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(
                                                      0xFF030744,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  capitalizeWords(
                                                    "${vm.ongoingOrder?.driver?.vehicle?.vehicleInfo}${vm.ongoingOrder?.driver?.franchiseNumber == null ? "" : " | ${vm.ongoingOrder?.driver?.franchiseNumber}"}${vm.ongoingOrder?.driver?.licenseNumber == null ? "" : " | ${vm.ongoingOrder?.driver?.licenseNumber}"}",
                                                    alt: "Driver Info",
                                                  ),
                                                  style: const TextStyle(
                                                    height: 1.15,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(
                                                      0xFF030744,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: WidgetButton(
                                              onTap: () {
                                                launchUrlString(
                                                  "tel://${vm.ongoingOrder?.driver?.phone}",
                                                );
                                              },
                                              mainColor: const Color(
                                                0xFF007BFF,
                                              ),
                                              useDefaultHoverColor: false,
                                              borderRadius: 8,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.call,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(
                                      color: Colors.grey.shade300,
                                      thickness: 1,
                                      height: 1,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(
                                        20,
                                      ),
                                      child: Text(
                                        "${capitalizeWords(vm.ongoingOrder?.driver?.name)} (Driver): ${"${vm.dvrMessage}".contains("https") ? "Sent a photo" : "${vm.dvrMessage}"}",
                                      ),
                                    ),
                                    !"${vm.dvrMessage}".contains("https")
                                        ? const SizedBox.shrink()
                                        : GestureDetector(
                                            onTap: () {
                                              AlertService().showAppAlert(
                                                isCustom: true,
                                                customWidget: PinchZoom(
                                                  child: Image.network(
                                                    "${vm.dvrMessage}",
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 20,
                                                right: 20,
                                                bottom: 20,
                                              ),
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                    .size
                                                    .width,
                                                height: MediaQuery.of(context)
                                                    .size
                                                    .width,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF007BFF,
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                    Radius.circular(10),
                                                  ),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      "${vm.dvrMessage}",
                                                    ),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 20,
                                        right: 20,
                                        bottom: 20,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 55,
                                              child: WidgetButton(
                                                onTap: () {
                                                  fbStore
                                                      .collection("orders")
                                                      .doc(
                                                          vm.ongoingOrder?.code)
                                                      .update(
                                                    {
                                                      "userSeen": true,
                                                    },
                                                  );
                                                },
                                                mainColor: Colors.red,
                                                useDefaultHoverColor: false,
                                                borderRadius: 8,
                                                child: const Center(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.close,
                                                        size: 35,
                                                        color: Colors.white,
                                                      ),
                                                      Text(
                                                        "Close",
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 8,
                                                      ),
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
                                                onTap: () {
                                                  vm.chatDriver();
                                                },
                                                mainColor: const Color(
                                                  0xFF007BFF,
                                                ),
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
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              Icons.send,
                                                              size: 35,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              "Reply",
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .white,
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
                              ),
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1000),
        boxShadow: [
          BoxShadow(
              color: const Color(
                0xFF030744,
              ).withOpacity(0.25),
              blurRadius: 2,
              offset: const Offset(0, 2))
        ],
      ),
      child: WidgetButton(
        onTap: () {
          onTap();
        },
        child: Center(
          child: Icon(
            icon,
            color: const Color(
              0xFF030744,
            ),
          ),
        ),
      ),
    );
  }
}
