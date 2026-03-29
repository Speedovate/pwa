// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/map.view.dart';
import 'package:pwa/views/load.view.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:pwa/views/history.view.dart';
import 'package:pwa/views/partner_panel.view.dart';
import 'package:pwa/views/profile.view.dart';
import 'package:pwa/view_models/Load.vm.dart';
import 'package:pwa/views/settings.view.dart';
import 'package:pwa/widgets/gmap.widget.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/models/address.model.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/view_models/splash.vm.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/partner_button.dart';
import 'package:pwa/widgets/partner_display.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/widgets/list_tile.widget.dart';
import 'package:pwa/widgets/text_field.widget.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  ValueNotifier<int> itemsIndex = ValueNotifier(0);
  final HomeViewModel homeViewModel = HomeViewModel();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<gmaps.LatLng?> _initialCenterFuture;
  gmaps.LatLng? _homeMapCenter;
  bool _isIOSMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _initialCenterFuture = _loadInitialCenter();
  }

  Future<gmaps.LatLng?> _loadInitialCenter() async {
    if (isIOSLikeBrowser()) {
      _homeMapCenter = defaultLatLng;
      return defaultLatLng;
    }
    if (lastKnownRealLatLng != null) {
      return lastKnownRealLatLng;
    }
    if (lastGeolocationErrorMessage != null) {
      return null;
    }
    return await getMyLatLng(
      forceFresh: true,
    );
  }

  void _retryInitialCenter() {
    setState(() {
      _initialCenterFuture = _loadInitialCenter();
    });
  }

  void _useDefaultInitialCenter() {
    setState(() {
      _homeMapCenter = defaultLatLng;
      _initialCenterFuture = Future.value(defaultLatLng);
    });
  }

  void _toggleHomeMenu() {
    if (isIOSLikeBrowser()) {
      setState(() {
        _isIOSMenuOpen = !_isIOSMenuOpen;
      });
      return;
    }
    _scaffoldKey.currentState?.openDrawer();
  }

  void _closeIOSMenu() {
    if (!isIOSLikeBrowser() || !_isIOSMenuOpen) {
      return;
    }
    setState(() {
      _isIOSMenuOpen = false;
    });
  }

  Widget _buildHomeDrawer(HomeViewModel vm, {bool useScaffoldDrawer = false}) {
    final content = Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          WidgetButton(
            borderRadius: 0,
            onTap: () {
              _closeIOSMenu();
              if (!AuthService.isLoggedIn()) {
                setState(() {
                  isTourist = false;
                });
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
            onLongPress: () {
              if (AuthService.isLoggedIn()) {
                copyToClipboardWeb(
                  lowerCase(
                    AuthService.currentUser?.code,
                  ),
                );
                if (isIOSLikeBrowser()) {
                  _closeIOSMenu();
                } else {
                  Get.back();
                }
                ScaffoldMessenger.of(
                  Get.context!,
                ).clearSnackBars();
                ScaffoldMessenger.of(
                  Get.context!,
                ).showSnackBar(
                  SnackBar(
                    margin: const EdgeInsets.all(
                      20,
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    content: const Text(
                      "Copied to clipboard.",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !AuthService.isLoggedIn()
                              ? "Login Account"
                              : capitalizeWords(
                                  "${AuthService.currentUser!.name}",
                                ),
                          style: const TextStyle(
                            height: 1.05,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(
                              0xFF030744,
                            ),
                          ),
                        ),
                        !AuthService.isLoggedIn()
                            ? const SizedBox()
                            : const SizedBox(height: 4),
                        !AuthService.isLoggedIn()
                            ? const SizedBox()
                            : Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(
                                      0xFF030744,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    lowerCase(
                                      AuthService.currentUser?.code,
                                    ),
                                    style: const TextStyle(
                                      height: 1.05,
                                      fontSize: 12,
                                      color: Color(
                                        0xFF030744,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(
                      0xFF030744,
                    ),
                    size: 25,
                  ),
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
                _closeIOSMenu();
                _navigateWithoutTransition(
                  HistoryView(vm),
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
                _closeIOSMenu();
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
              _closeIOSMenu();
              launchUrlString(
                "sms://+639686410532",
              );
            },
          ),
          ListTileWidget(
            contentPadding: const EdgeInsets.only(
              left: 18,
              right: 16,
              top: 16,
              bottom: 16,
            ),
            leading: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(
                      0xFF030744,
                    ),
                    width: 2,
                  ),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(1000),
                  ),
                ),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.only(left: 0.5),
                    child: Text(
                      "₱",
                      style: TextStyle(
                        height: 1,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(
                          0xFF030744,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            title: const Text(
              "TODA Load",
              style: TextStyle(
                color: Color(
                  0xFF030744,
                ),
              ),
            ),
            onTap: () {
              _closeIOSMenu();
              Get.to(
                () => const LoadView(),
              );
            },
          ),
          if (AuthService.isLoggedIn())
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream:
                  fbStore.collection("access").doc("pwa_partners").snapshots(),
              builder: (context, snapshot) {
                final allowedUserIds = snapshot.data?.data()?["users"] ?? [];
                final currentUserId = "${AuthService.currentUser?.id}";
                final hasAccess = allowedUserIds.any(
                  (id) => "$id" == currentUserId,
                );
                if (!hasAccess) {
                  return const SizedBox.shrink();
                }
                return ListTileWidget(
                  leading: const Icon(
                    Icons.people_outline,
                    color: Color(
                      0xFF030744,
                    ),
                  ),
                  title: const Text(
                    "Partner Panel",
                    style: TextStyle(
                      color: Color(
                        0xFF030744,
                      ),
                    ),
                  ),
                  onTap: () {
                    _closeIOSMenu();
                    _navigateWithoutTransition(
                      const PartnerPanelView(),
                    );
                  },
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
                Clipboard.setData(
                  ClipboardData(
                    text: "$fcmToken",
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
    if (!useScaffoldDrawer) {
      return content;
    }
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: content,
    );
  }

  _navigateWithoutTransition(Widget page) {
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

  Widget _homeLoadingIndicator() {
    return SizedBox(
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
    );
  }

  bool _sameLatLng(gmaps.LatLng? a, gmaps.LatLng? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.lat == b.lat && a.lng == b.lng;
  }

  String _locationErrorHint() {
    final error = lastGeolocationErrorMessage ?? "";
    if (error.contains("POSITION_UNAVAILABLE")) {
      return "We could not get your current location yet. Please make sure Location Services are turned on and available for this browser, then try again. You can also use the default location to continue more quickly.";
    }
    if (error.contains("TIMEOUT")) {
      return "Getting your current location is taking longer than expected. Please try again, or use the default location to continue more quickly.";
    }
    if (error.contains("PERMISSION_DENIED")) {
      return "Location access is turned off for this browser. Please allow location access, then try again, or use the default location to continue more quickly.";
    }
    return "We could not get your current location yet. Please make sure Location is turned on, then try again or use the default location to continue more quickly.";
  }

  String _locationLoadingHint() {
    final error = lastGeolocationErrorMessage ?? "";
    if (error.contains("POSITION_UNAVAILABLE")) {
      return "We are still trying to get your current location. Please keep Location Services turned on for this browser. If you want to continue more quickly, you can use the default location for now.";
    }
    return "Please wait while we get your actual current location. If you want to continue more quickly, you can use the default location for now.";
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
          drawer: isIOSLikeBrowser()
              ? null
              : _buildHomeDrawer(
                  vm,
                  useScaffoldDrawer: true,
                ),
          backgroundColor: Colors.white,
          body: FutureBuilder<gmaps.LatLng?>(
            future: _initialCenterFuture,
            initialData: lastKnownRealLatLng,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: Image.asset(
                            AppImages.logo,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "Unable to get your current location yet.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF030744),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _locationErrorHint(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF030744).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ActionButton(
                            text: "Retry Location",
                            onTap: _retryInitialCenter,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ActionButton(
                            text: "Use Default Location",
                            mainColor: Colors.white,
                            style: const TextStyle(
                              color: Color(0xFF030744),
                              fontWeight: FontWeight.w600,
                            ),
                            onTap: _useDefaultInitialCenter,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
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
                        const SizedBox(height: 18),
                        const Text(
                          "Getting your current location",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF030744),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _locationLoadingHint(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF030744).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ActionButton(
                            text: "Use Default Location",
                            mainColor: Colors.white,
                            style: const TextStyle(
                              color: Color(0xFF030744),
                              fontWeight: FontWeight.w600,
                            ),
                            onTap: _useDefaultInitialCenter,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final resolvedCenter = snapshot.data!;
              final currentCenter = _homeMapCenter;
              final showBottomUi = vm.selectedAddress.value != null;
              final showPartnerButtons = showBottomUi &&
                  !vm.isCameraMovePending &&
                  !vm.isLoading &&
                  !vm.isInitializing;
              if (currentCenter == null ||
                  (_sameLatLng(currentCenter, defaultLatLng) &&
                      !_sameLatLng(resolvedCenter, defaultLatLng))) {
                _homeMapCenter = resolvedCenter;
              }
              final center = _homeMapCenter ?? resolvedCenter;
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
                            child: RepaintBoundary(
                              child: Stack(
                                children: [
                                  GoogleMapWidget(
                                    center: vm.mapCenter ?? center,
                                    enableGestures: isAdSeen &&
                                        isAd1Seen &&
                                        !vm.showReport &&
                                        !vm.isDisabled &&
                                        !vm.showAnalytics &&
                                        (isBool(vm.userSeen) ||
                                            vm.dvrMessage == null ||
                                            vm.dvrMessage == "null" ||
                                            vm.ongoingOrder == null ||
                                            vm.ongoingOrder?.status ==
                                                "cancelled" ||
                                            vm.dvrMessage == "null" ||
                                            vm.dvrMessage == "") &&
                                        !vm.isMapInteractionLocked,
                                    markers: vm.markers,
                                    polylines: vm.polylines,
                                    onMapCreated: (map) async {
                                      vm.setMap(map);
                                      if (AuthService.isLoggedIn()) {
                                        await vm.getOngoingOrder();
                                        await LoadViewModel().getLoadBalance();
                                      }
                                    },
                                    onCameraMoveStart: () {
                                      try {
                                        if (vm.ongoingOrder == null &&
                                            !vm.blockCamera &&
                                            !vm.isMapInteractionLocked &&
                                            vm.markers.isEmpty) {
                                          vm.beginCameraMove();
                                        }
                                      } catch (e) {
                                        debugPrint(
                                          "HomeView - onCameraMoveStart error: $e",
                                        );
                                      }
                                    },
                                    onCameraMove: (center) {
                                      try {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        final a = vm.disposed;
                                        final b = vm.markers;
                                        if (vm.ongoingOrder == null) {
                                          if (!vm.blockCamera &&
                                              !vm.isMapInteractionLocked &&
                                              vm.shouldProcessCameraMove(
                                                center,
                                              )) {
                                            if (!a && b.isEmpty) {
                                              vm.mapCameraMove(
                                                "onCameraMove",
                                                center,
                                              );
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
                                    child: FloatingButton(
                                      icon: Icons.menu,
                                      onTap: () {
                                        _toggleHomeMenu();
                                      },
                                    ),
                                  ),
                                  !isBool(
                                    AuthService.currentUser?.isProvider,
                                  )
                                      ? const SizedBox()
                                      : Positioned(
                                          top: 20,
                                          left: 20,
                                          right: 20,
                                          child: Center(
                                            child: FloatingButton(
                                              icon: vm.showAnalytics
                                                  ? Icons.close
                                                  : Icons.analytics_outlined,
                                              iconColor: vm.showAnalytics
                                                  ? Colors.red
                                                  : const Color(0xFF007BFF),
                                              onTap: () {
                                                setState(() {
                                                  vm.showAnalytics =
                                                      !vm.showAnalytics;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                  Positioned(
                                    top: 20,
                                    right: 20,
                                    child: FloatingButton(
                                      icon: Icons.my_location_outlined,
                                      onTap: () async {
                                        final a = vm.disposed;
                                        final target =
                                            await vm.zoomToCurrentLocation();
                                        if (!a && target != null) {
                                          vm.mapCameraMove(
                                            "myLocation",
                                            target,
                                            debounceDuration: Duration.zero,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    left: 20,
                                    bottom: 20,
                                    child: Column(
                                      children: [
                                        FloatingButton(
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
                                              await vm.getOngoingOrder(
                                                forceStop: true,
                                              );
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
                                                  vm.drawDropPolyLines(
                                                    "pickup-dropoff",
                                                    vm.ongoingOrder?.taxiOrder
                                                            ?.pickupLatLng ??
                                                        pickupAddress!.latLng,
                                                    vm.ongoingOrder?.taxiOrder
                                                            ?.dropoffLatLng ??
                                                        dropoffAddress!.latLng,
                                                    vm.ongoingOrder
                                                        ?.driverLatLng,
                                                  );
                                                  await vm
                                                      .fetchVehicleTypesPricing();
                                                  setState(() {
                                                    vm.isPreparing = false;
                                                  });
                                                }
                                              }
                                              AlertService().stopLoading(
                                                forceStop: true,
                                              );
                                            }
                                          },
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        FloatingButton(
                                          icon: Icons.share,
                                          onTap: () {
                                            share(
                                              "Hey there, you can now book tricycles on the PPC TODA (Beta) app! Here is the download link.",
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
                                        FloatingButton(
                                          icon: Icons.add,
                                          onTap: () async {
                                            final a = vm.disposed;
                                            final b = vm.markers;
                                            final c = vm.selectedAddress.value;
                                            await vm.zoomIn();
                                            if (!a && b.isEmpty && c == null) {
                                              vm.mapCameraMove(
                                                "zoomIn",
                                                vm.mapCenter,
                                              );
                                            }
                                          },
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        FloatingButton(
                                          icon: Icons.remove,
                                          onTap: () async {
                                            final a = vm.disposed;
                                            final b = vm.markers;
                                            final c = vm.selectedAddress.value;
                                            await vm.zoomOut();
                                            if (!a && b.isEmpty && c == null) {
                                              vm.mapCameraMove(
                                                "zoomOut",
                                                vm.mapCenter,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  vm.ongoingOrder != null ||
                                          !isBool(
                                            AppStrings.homeSettingsObject?[
                                                    "show_ad"] ??
                                                true,
                                          )
                                      ? const SizedBox.shrink()
                                      : Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom:
                                              showPartnerButtons ? 20 : -500,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              PartnerButtonWidget(
                                                image: AppImages.mnb,
                                                show: true,
                                                onTap: () async {
                                                  if (gBanners.isEmpty) {
                                                    await SplashViewModel()
                                                        .getBanners();
                                                  }
                                                  setState(() {
                                                    isAdSeen = false;
                                                    showBranch = false;
                                                  });
                                                },
                                              ),
                                              const SizedBox(
                                                width: 12,
                                              ),
                                              PartnerButtonWidget(
                                                image: AppImages.sbb,
                                                show: true,
                                                onTap: () async {
                                                  if (gBanners.isEmpty) {
                                                    await SplashViewModel()
                                                        .getBanners();
                                                  }
                                                  setState(() {
                                                    isAd1Seen = false;
                                                    showBranch = false;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                  vm.markers.isNotEmpty
                                      ? const SizedBox.shrink()
                                      : const Center(
                                          child: Padding(
                                            padding:
                                                EdgeInsets.only(bottom: 40),
                                            child: Icon(
                                              Icons.location_on,
                                              color: Color(
                                                0xFF007BFF,
                                              ),
                                              size: 50,
                                            ),
                                          ),
                                        ),
                                  !vm.showAnalytics ||
                                          !isBool(
                                            AuthService.currentUser?.isProvider,
                                          )
                                      ? const SizedBox()
                                      : Positioned(
                                          top: 80,
                                          left: 16,
                                          right: 16,
                                          child: Center(
                                            child: Container(
                                              width: (MediaQuery.of(context)
                                                          .size
                                                          .width -
                                                      32)
                                                  .clamp(0, 800),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    const BorderRadius.all(
                                                  Radius.circular(8),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(0.25),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: SingleChildScrollView(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Text(
                                                            "Payment Mode",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                0xFF030744,
                                                              ),
                                                            ),
                                                          ),
                                                          const Expanded(
                                                            child: SizedBox
                                                                .shrink(),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.red
                                                                  .withOpacity(
                                                                0.08,
                                                              ),
                                                              borderRadius:
                                                                  const BorderRadius
                                                                      .all(
                                                                Radius.circular(
                                                                  999,
                                                                ),
                                                              ),
                                                            ),
                                                            child: const Text(
                                                              "Locked",
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                      Container(
                                                        width: double.infinity,
                                                        height: 56,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              const BorderRadius
                                                                  .all(
                                                            Radius.circular(8),
                                                          ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFF030744,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            vm.providerPaymentMode ==
                                                                    "cash"
                                                                ? "Cash: Pay Your Driver"
                                                                : "Load: Auto Deduction",
                                                            textAlign: TextAlign
                                                                .center,
                                                            style:
                                                                const TextStyle(
                                                              height: 1.05,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Color(
                                                                0xFF030744,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              height: 56,
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    const BorderRadius
                                                                        .all(
                                                                  Radius
                                                                      .circular(
                                                                    8,
                                                                  ),
                                                                ),
                                                                border:
                                                                    Border.all(
                                                                  color:
                                                                      const Color(
                                                                    0xFF030744,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .today_outlined,
                                                                    size: 32,
                                                                    color:
                                                                        Color(
                                                                      0xFF030744,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 2,
                                                                  ),
                                                                  Column(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        "₱${vm.user?["today_amount"] ?? 0}",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            const TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const Text(
                                                                        "Today",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              height: 56,
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    const BorderRadius
                                                                        .all(
                                                                  Radius
                                                                      .circular(
                                                                    8,
                                                                  ),
                                                                ),
                                                                border:
                                                                    Border.all(
                                                                  color:
                                                                      const Color(
                                                                    0xFF030744,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .calendar_month_outlined,
                                                                    size: 32,
                                                                    color:
                                                                        Color(
                                                                      0xFF030744,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 2,
                                                                  ),
                                                                  Column(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        "₱${vm.user?["month_amount"] ?? 0}",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            const TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        DateFormat(
                                                                          "MMMM",
                                                                        ).format(
                                                                          DateTime
                                                                              .now(),
                                                                        ),
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            const TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
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
                                                      const SizedBox(
                                                          height: 16),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              height: 56,
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    const BorderRadius
                                                                        .all(
                                                                  Radius
                                                                      .circular(
                                                                    8,
                                                                  ),
                                                                ),
                                                                border:
                                                                    Border.all(
                                                                  color:
                                                                      const Color(
                                                                    0xFF030744,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .list_alt,
                                                                    size: 32,
                                                                    color:
                                                                        Color(
                                                                      0xFF030744,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 2,
                                                                  ),
                                                                  Column(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        "₱${vm.user?["total_amount"] ?? 0}",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            const TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const Text(
                                                                        "Total",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              height: 56,
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    const BorderRadius
                                                                        .all(
                                                                  Radius
                                                                      .circular(
                                                                    8,
                                                                  ),
                                                                ),
                                                                border:
                                                                    Border.all(
                                                                  color:
                                                                      const Color(
                                                                    0xFF030744,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .add_chart_outlined,
                                                                    size: 32,
                                                                    color:
                                                                        Color(
                                                                      0xFF030744,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 2,
                                                                  ),
                                                                  Column(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        "₱${vm.user?["markup_amount"] ?? 0}",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            const TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const Text(
                                                                        "Markup",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Color(
                                                                            0xFF030744,
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
                                                    ],
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
                          Column(
                            children: [
                              RepaintBoundary(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: showBottomUi
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                  child: !showBottomUi
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
                                                        padding:
                                                            const EdgeInsets
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
                                                                          : "An error occurred. Please try again",
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      style:
                                                                          const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w500,
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
                                                                  height: ((MediaQuery.of(context).size.width - 64) /
                                                                              3)
                                                                          .clamp(
                                                                              0,
                                                                              120) /
                                                                      3,
                                                                  mainColor:
                                                                      Colors
                                                                          .red,
                                                                  text: locUnavailable
                                                                      ? "Try another location"
                                                                      : "Retry",
                                                                  style:
                                                                      const TextStyle(
                                                                    height:
                                                                        1.05,
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
                                                        vm.ongoingOrder
                                                                ?.status !=
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
                                                                            width:
                                                                                double.infinity.clamp(
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
                                                                              style: const TextStyle(
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
                                                                    color: vm.ongoingOrder?.status ==
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
                                                                            Radius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            const Row(
                                                                          children: [
                                                                            SizedBox(
                                                                              width: 12,
                                                                            ),
                                                                            Icon(
                                                                              Icons.search,
                                                                              color: Color(
                                                                                0xFF007BFF,
                                                                              ),
                                                                            ),
                                                                            SizedBox(
                                                                              width: 8,
                                                                            ),
                                                                            Text(
                                                                              "We are doing our best to find a driver",
                                                                              style: TextStyle(
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
                                                                      child:
                                                                          Row(
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
                                                                                      vm.ongoingOrder?.driver?.cPhoto ?? "",
                                                                                      fit: BoxFit.cover,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                            child:
                                                                                ClipOval(
                                                                              child: SizedBox(
                                                                                width: 48,
                                                                                height: 48,
                                                                                child: NetworkImageWidget(
                                                                                  fit: BoxFit.cover,
                                                                                  memCacheWidth: 600,
                                                                                  imageUrl: vm.ongoingOrder?.driver?.cPhoto ?? "",
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
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Padding(
                                                                                  padding: const EdgeInsets.only(
                                                                                    right: 12,
                                                                                  ),
                                                                                  child: Text(
                                                                                    capitalizeWords(
                                                                                      vm.ongoingOrder?.driver?.name,
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
                                                                            width:
                                                                                44,
                                                                            height:
                                                                                44,
                                                                            child:
                                                                                WidgetButton(
                                                                              onTap: () {
                                                                                launchUrlString(
                                                                                  "tel://${vm.ongoingOrder?.driver?.phone}",
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
                                                                              onTap: () {
                                                                                vm.chatDriver();
                                                                              },
                                                                              mainColor: const Color(
                                                                                0xFF007BFF,
                                                                              ),
                                                                              borderRadius: 8,
                                                                              useDefaultHoverColor: false,
                                                                              child: const Center(
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
                                                                        width: ((MediaQuery.of(context).size.width - 64) / 3).clamp(
                                                                            0,
                                                                            120),
                                                                        height: ((MediaQuery.of(context).size.width - 64) / 3).clamp(
                                                                            0,
                                                                            120),
                                                                        child:
                                                                            Builder(
                                                                          builder:
                                                                              (context) {
                                                                            final previewVehicle =
                                                                                gVehicleTypes.firstWhere(
                                                                              (v) => v.slug == "tricycle",
                                                                              orElse: () => gVehicleTypes.first,
                                                                            );
                                                                            return ConstrainedBox(
                                                                              constraints: const BoxConstraints(
                                                                                maxWidth: 200,
                                                                              ),
                                                                              child: Container(
                                                                                height: 50,
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
                                                                                child: Column(
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
                                                                                          "assets/images/${lowerCase(previewVehicle.name!)}.png",
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      height: 8,
                                                                                    ),
                                                                                    Text(
                                                                                      capitalizeWords(
                                                                                        previewVehicle.name!,
                                                                                      ),
                                                                                      style: const TextStyle(
                                                                                        height: 1.05,
                                                                                        fontSize: 14,
                                                                                        color: Color(
                                                                                          0xFF007BFF,
                                                                                        ),
                                                                                        fontWeight: FontWeight.w500,
                                                                                      ),
                                                                                    ),
                                                                                    Text(
                                                                                      "${previewVehicle.maxSeat!} Seater",
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
                                                                            );
                                                                          },
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            15,
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
                                                                                  mainColor: isBool(
                                                                                    AuthService.currentUser?.isProvider,
                                                                                  )
                                                                                      ? vm.providerRiderTypeId == 1
                                                                                          ? const Color(
                                                                                              0xFF007BFF,
                                                                                            )
                                                                                          : Colors.white
                                                                                      : vm.paymentId == 1
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
                                                                                        isBool(
                                                                                          AuthService.currentUser?.isProvider,
                                                                                        )
                                                                                            ? "Guest"
                                                                                            : "Cash",
                                                                                        textAlign: TextAlign.center,
                                                                                        style: TextStyle(
                                                                                          fontWeight: FontWeight.bold,
                                                                                          color: isBool(
                                                                                            AuthService.currentUser?.isProvider,
                                                                                          )
                                                                                              ? vm.providerRiderTypeId == 1
                                                                                                  ? Colors.white
                                                                                                  : const Color(
                                                                                                      0xFF007BFF,
                                                                                                    )
                                                                                              : vm.paymentId == 1
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
                                                                                        Get.context!,
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
                                                                                      if (isBool(
                                                                                        AuthService.currentUser?.isProvider,
                                                                                      )) {
                                                                                        setState(() {
                                                                                          vm.setProviderRiderType(
                                                                                            1,
                                                                                          );
                                                                                        });
                                                                                        return;
                                                                                      }
                                                                                      setState(() {
                                                                                        vm.paymentId = 1;
                                                                                      });
                                                                                      vm.calculateTotalAmount();
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
                                                                                  mainColor: isBool(
                                                                                    AuthService.currentUser?.isProvider,
                                                                                  )
                                                                                      ? vm.providerRiderTypeId == 8
                                                                                          ? const Color(
                                                                                              0xFF007BFF,
                                                                                            )
                                                                                          : Colors.white
                                                                                      : vm.paymentId != 1
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
                                                                                        isBool(
                                                                                          AuthService.currentUser?.isProvider,
                                                                                        )
                                                                                            ? "Staff"
                                                                                            : "Load",
                                                                                        textAlign: TextAlign.center,
                                                                                        style: TextStyle(
                                                                                          fontWeight: FontWeight.bold,
                                                                                          color: isBool(
                                                                                            AuthService.currentUser?.isProvider,
                                                                                          )
                                                                                              ? vm.providerRiderTypeId == 8
                                                                                                  ? Colors.white
                                                                                                  : const Color(
                                                                                                      0xFF007BFF,
                                                                                                    )
                                                                                              : vm.paymentId != 1
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
                                                                                        Get.context!,
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
                                                                                      if (isBool(
                                                                                        AuthService.currentUser?.isProvider,
                                                                                      )) {
                                                                                        setState(() {
                                                                                          vm.setProviderRiderType(
                                                                                            8,
                                                                                          );
                                                                                        });
                                                                                        return;
                                                                                      }
                                                                                      setState(() {
                                                                                        vm.paymentId = 8;
                                                                                      });
                                                                                      vm.calculateTotalAmount();
                                                                                    }
                                                                                  },
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            15,
                                                                      ),
                                                                      WidgetButton(
                                                                        onTap:
                                                                            () {
                                                                          if (!AuthService
                                                                              .isLoggedIn()) {
                                                                            Navigator.push(
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
                                                                            Navigator.push(
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
                                                                              maxWidth: 200,
                                                                            ),
                                                                            child:
                                                                                Container(
                                                                              height: 50,
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
                                                                              child: Column(
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
                                                                                      fontSize: 14,
                                                                                      color: Color(
                                                                                        0xFF007BFF,
                                                                                      ),
                                                                                      fontWeight: FontWeight.w500,
                                                                                    ),
                                                                                  ),
                                                                                  const Text(
                                                                                    "TODA Load",
                                                                                    textAlign: TextAlign.center,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                            await Navigator
                                                                .push(
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
                                                            vm.isPreparing =
                                                                true;
                                                          });
                                                          vm.drawDropPolyLines(
                                                            "pickup-dropoff",
                                                            vm
                                                                    .ongoingOrder
                                                                    ?.taxiOrder
                                                                    ?.pickupLatLng ??
                                                                pickupAddress!
                                                                    .latLng,
                                                            vm
                                                                    .ongoingOrder
                                                                    ?.taxiOrder
                                                                    ?.dropoffLatLng ??
                                                                dropoffAddress!
                                                                    .latLng,
                                                            vm.ongoingOrder
                                                                ?.driverLatLng,
                                                          );
                                                          await vm
                                                              .fetchVehicleTypesPricing();
                                                          setState(() {
                                                            vm.isPreparing =
                                                                false;
                                                          });
                                                        } else {
                                                          vm.blockCamera = true;
                                                          vm.notifyListeners();
                                                          vm.zoomToLocation(
                                                            pickupAddress!
                                                                .latLng,
                                                          );
                                                          await Future.delayed(
                                                            const Duration(
                                                              milliseconds: 500,
                                                            ),
                                                          );
                                                          vm.blockCamera =
                                                              false;
                                                          vm.notifyListeners();
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
                                                              alt:
                                                                  "Where from?",
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                            await Navigator
                                                                .push(
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
                                                            vm.isPreparing =
                                                                true;
                                                          });
                                                          vm.drawDropPolyLines(
                                                            "pickup-dropoff",
                                                            vm
                                                                    .ongoingOrder
                                                                    ?.taxiOrder
                                                                    ?.pickupLatLng ??
                                                                pickupAddress!
                                                                    .latLng,
                                                            vm
                                                                    .ongoingOrder
                                                                    ?.taxiOrder
                                                                    ?.dropoffLatLng ??
                                                                dropoffAddress!
                                                                    .latLng,
                                                            vm.ongoingOrder
                                                                ?.driverLatLng,
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
                                                              alt:
                                                                  "Where to go?",
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                      width: ((MediaQuery.of(
                                                                          context)
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
                                                              color:
                                                                  const Color(
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
                                                                          (vm.ongoingOrder!.taxiOrder?.tripDetails?.eta ?? "").toLowerCase().contains("any") || (vm.ongoingOrder!.taxiOrder?.tripDetails?.eta ?? "").toLowerCase().contains("unknown")
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
                                                                              vm.selectedVehicle?.kmDistance ?? 0,
                                                                            ),
                                                              textAlign:
                                                                  TextAlign
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
                                                        text: (() {
                                                          final order =
                                                              vm.ongoingOrder;
                                                          final status =
                                                              order?.status;
                                                          if (order == null ||
                                                              status ==
                                                                  "cancelled") {
                                                            return "BOOK";
                                                          } else if (vm
                                                                      .dvrMessage ==
                                                                  null ||
                                                              vm.dvrMessage ==
                                                                  "null") {
                                                            return "CANCEL";
                                                          } else if (status ==
                                                                  "enroute" ||
                                                              status ==
                                                                  "preparing" ||
                                                              status ==
                                                                  "delivered") {
                                                            return "REPORT";
                                                          }
                                                          return "CANCEL";
                                                        })(),
                                                        mainColor: vm
                                                                .isPreparing
                                                            ? const Color(
                                                                0xFF030744,
                                                              ).withOpacity(0.2)
                                                            : vm.ongoingOrder !=
                                                                        null &&
                                                                    vm.ongoingOrder!
                                                                            .status !=
                                                                        "cancelled"
                                                                ? Colors.red
                                                                    .shade100
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
                                                                    Duration
                                                                        .zero,
                                                                transitionDuration:
                                                                    Duration
                                                                        .zero,
                                                                pageBuilder: (
                                                                  context,
                                                                  a,
                                                                  b,
                                                                ) =>
                                                                    const LoginView(),
                                                              ),
                                                            );
                                                          } else {
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                            if (vm.isPreparing ||
                                                                vm.ongoingOrder
                                                                        ?.status ==
                                                                    "cancelled") {
                                                              ScaffoldMessenger
                                                                  .of(
                                                                Get.context!,
                                                              ).clearSnackBars();
                                                              ScaffoldMessenger
                                                                  .of(
                                                                Get.context!,
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
                                                            } else if (vm
                                                                        .dvrMessage ==
                                                                    null ||
                                                                vm.dvrMessage ==
                                                                    "null") {
                                                              vm.cancelOrder();
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
                                                              : 16,
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
                                                      width: ((MediaQuery.of(
                                                                          context)
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
                                                              color:
                                                                  const Color(
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
                                                                      ? vm.isPreparing
                                                                          ? "•••"
                                                                          : "${vm.ongoingOrder!.taxiOrder?.tripDetails?.kmDistance?.toStringAsFixed(1)} km"
                                                                      : vm.isPreparing
                                                                          ? "•••"
                                                                          : "${isBool(AuthService.currentUser?.isProvider) ? "₱" : ""}${((vm.ongoingOrder?.total ?? 0) + (isBool(AuthService.currentUser?.isProvider) && (vm.ongoingOrder?.discount ?? 0) == 0 ? (vm.user?["markup_amount"] ?? 0) : 0)).toStringAsFixed(0)}${" "}${vm.ongoingOrder!.paymentMethodId == 1 ? "Cash" : "Load"}"
                                                                  : vm.selectedVehicle == null
                                                                      ? AuthService.inReviewMode()
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
                                                                              : "${isBool(AuthService.currentUser?.isProvider) ? "₱" : ""}${vm.total?.toStringAsFixed(0)}${" "}${vm.paymentId == 1 ? "Cash" : "Load"}",
                                                              textAlign:
                                                                  TextAlign
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
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isIOSLikeBrowser() && _isIOSMenuOpen)
                        Positioned.fill(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: _closeIOSMenu,
                                  child: Container(
                                    color: Colors.black.withOpacity(0.18),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.84 >
                                              320
                                          ? 320
                                          : MediaQuery.of(context).size.width *
                                              0.84,
                                  height: double.infinity,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: _buildHomeDrawer(vm),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                                  child: _homeLoadingIndicator(),
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
                                                            height: 16,
                                                          ),
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
                                                                        "₱${((vm.ongoingOrder?.total ?? 0) + (isBool(AuthService.currentUser?.isProvider) && (vm.ongoingOrder?.discount ?? 0) == 0 ? (vm.user?["markup_amount"] ?? 0) : 0)).toStringAsFixed(0)}",
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
                                                                fontSize: 14,
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
                                                              height: 16,
                                                            ),
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
                                                                  fontSize: 14,
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
                                                                  fontSize: 14,
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
                                                                              "sms://+639686410532",
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
                              vm.dvrMessage == "" ||
                              vm.dvrMessage == null ||
                              vm.dvrMessage == "null" ||
                              vm.ongoingOrder == null ||
                              vm.ongoingOrder?.status == "cancelled"
                          ? const SizedBox()
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
                                      padding: const EdgeInsets.all(20),
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
                                            child: Material(
                                              color: const Color(
                                                0xFF007BFF,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.all(
                                                Radius.circular(
                                                  8,
                                                ),
                                              ),
                                              child: Ink(
                                                child: InkWell(
                                                  onTap: () {
                                                    launchUrlString(
                                                      "tel://${vm.ongoingOrder?.driver?.phone}",
                                                    );
                                                  },
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                    Radius.circular(
                                                      8,
                                                    ),
                                                  ),
                                                  focusColor: const Color(
                                                    0xFF030744,
                                                  ).withOpacity(
                                                    0.2,
                                                  ),
                                                  hoverColor: const Color(
                                                    0xFF030744,
                                                  ).withOpacity(
                                                    0.2,
                                                  ),
                                                  splashColor: const Color(
                                                    0xFF030744,
                                                  ).withOpacity(
                                                    0.2,
                                                  ),
                                                  highlightColor: const Color(
                                                    0xFF030744,
                                                  ).withOpacity(
                                                    0.2,
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.phone,
                                                      color: Colors.white,
                                                    ),
                                                  ),
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
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        "${capitalizeWords(vm.ongoingOrder?.driver?.name)} (Driver): ${"${vm.dvrMessage}".contains("https") ? "Sent a photo" : "${vm.dvrMessage}"}",
                                      ),
                                    ),
                                    !"${vm.dvrMessage}".contains("https")
                                        ? const SizedBox()
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
                                            child: Container(
                                              height: 55,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: Ink(
                                                  decoration:
                                                      const BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.all(
                                                      Radius.circular(10),
                                                    ),
                                                  ),
                                                  child: InkWell(
                                                    onTap: () {
                                                      fbStore
                                                          .collection("orders")
                                                          .doc(vm.ongoingOrder
                                                              ?.code)
                                                          .update(
                                                        {
                                                          "userSeen": true,
                                                        },
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    focusColor: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(
                                                      0.1,
                                                    ),
                                                    hoverColor: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(
                                                      0.1,
                                                    ),
                                                    splashColor: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(
                                                      0.1,
                                                    ),
                                                    highlightColor: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(
                                                      0.1,
                                                    ),
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
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          SizedBox(width: 8),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: Container(
                                              height: 55,
                                              decoration: const BoxDecoration(
                                                color: Color(
                                                  0xFF007BFF,
                                                ),
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: Ink(
                                                  decoration:
                                                      const BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.all(
                                                      Radius.circular(10),
                                                    ),
                                                  ),
                                                  child: InkWell(
                                                    onTap: () {
                                                      vm.chatDriver();
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      10,
                                                    ),
                                                    focusColor: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(
                                                      0.1,
                                                    ),
                                                    hoverColor: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(
                                                      0.1,
                                                    ),
                                                    splashColor: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(
                                                      0.1,
                                                    ),
                                                    highlightColor: const Color(
                                                      0xFF030744,
                                                    ).withOpacity(
                                                      0.1,
                                                    ),
                                                    child: Center(
                                                      child: vm.isBusy
                                                          ? const SizedBox(
                                                              width: 28,
                                                              height: 28,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2.5,
                                                                color: Colors
                                                                    .white,
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
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Text(
                                                                  "Reply",
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        16,
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
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      () {
                        try {
                          return PartnerDisplayWidget(
                            show: !isAdSeen &&
                                vm.ongoingOrder == null &&
                                isBool(
                                  AppStrings.homeSettingsObject?["show_ad"] ??
                                      true,
                                ),
                            onClose: () async {
                              await StorageService.prefs?.setBool(
                                "is_ad_seen",
                                true,
                              );
                              setState(() {
                                isAdSeen = true;
                                showBranch = false;
                              });
                            },
                            isLoggedIn: () => AuthService.isLoggedIn(),
                            onSelectDropoff: (
                              latLng,
                              branchName,
                            ) {
                              dropoffAddress = Address(
                                addressLine: branchName,
                                coordinates: Coordinates(
                                  double.parse("${latLng.lat}"),
                                  double.parse("${latLng.lng}"),
                                ),
                              );
                              vm.drawDropPolyLines(
                                "pickup-dropoff",
                                pickupAddress!.latLng,
                                latLng,
                                null,
                              );
                              vm.fetchVehicleTypesPricing();
                              setState(() {
                                showBranch = false;
                              });
                            },
                            banners: [
                              BannerModel(photo: "${gBanners[0].photo}"),
                              BannerModel(photo: "${gBanners[1].photo}"),
                            ],
                            partnerName: "Max & Bunny",
                            partnerDescription:
                                "Dine in and help a driver earn!",
                            partnerImage: AppImages.mnb,
                            branches: [
                              Branch(
                                id: 1,
                                name: "SM Branch",
                                latLng: const gmaps.LatLng(
                                  9.743318345512021,
                                  118.7390989745996,
                                ),
                              ),
                              Branch(
                                id: 2,
                                name: "San Pedro Branch",
                                latLng: const gmaps.LatLng(
                                  9.762115888944837,
                                  118.75241723828879,
                                ),
                              ),
                            ],
                          );
                        } catch (_) {
                          return const SizedBox();
                        }
                      }(),
                      () {
                        try {
                          return PartnerDisplayWidget(
                            show: !isAd1Seen &&
                                vm.ongoingOrder == null &&
                                isBool(AppStrings
                                        .homeSettingsObject?["show_ad_1"] ??
                                    true),
                            onClose: () async {
                              await StorageService.prefs
                                  ?.setBool("is_ad_1_seen", true);
                              setState(() {
                                isAd1Seen = true;
                                showBranch = false;
                              });
                            },
                            isLoggedIn: () => AuthService.isLoggedIn(),
                            onSelectDropoff: (
                              latLng,
                              branchName,
                            ) {
                              dropoffAddress = Address(
                                addressLine: branchName,
                                coordinates: Coordinates(
                                  double.parse("${latLng.lat}"),
                                  double.parse("${latLng.lng}"),
                                ),
                              );
                              vm.drawDropPolyLines(
                                "pickup-dropoff",
                                pickupAddress!.latLng,
                                latLng,
                                null,
                              );
                              vm.fetchVehicleTypesPricing();
                              setState(() {
                                showBranch = false;
                              });
                            },
                            banners: [
                              BannerModel(photo: "${gBanners[2].photo}"),
                              BannerModel(photo: "${gBanners[3].photo}"),
                            ],
                            partnerName: "Sabie Bakes",
                            partnerDescription:
                                "Dine in and help a driver earn!",
                            partnerImage: AppImages.sbb,
                            branches: [
                              Branch(
                                id: 1,
                                name: "SM Branch",
                                latLng: const gmaps.LatLng(
                                  9.74394439548003,
                                  118.7398234327833,
                                ),
                              ),
                              Branch(
                                id: 2,
                                name: "BM Road Branch",
                                latLng: const gmaps.LatLng(
                                  9.765574270055104,
                                  118.76115291309709,
                                ),
                              ),
                            ],
                          );
                        } catch (_) {
                          return const SizedBox();
                        }
                      }(),
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

class FloatingButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const FloatingButton({
    super.key,
    this.iconColor = const Color(0xFF030744),
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
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
