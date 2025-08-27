import 'package:pwa/utils/data.dart';
import 'package:pwa/views/map.view.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/load.view.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/login.view.dart';
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
    return ViewModelBuilder<HomeViewModel>.reactive(
      viewModelBuilder: () => homeViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return Scaffold(
          key: _scaffoldKey,
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 18),
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
                              progressIndicatorBuilder:
                                  (context, imageUrl, progress) {
                                return const CircularProgressIndicator(
                                  color: Color(0xFF007BFF),
                                );
                              },
                              errorWidget: (context, imageUrl, progress) {
                                return Container(
                                  color: const Color(0xFF030744),
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
                              color: Color(0xFF030744),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF030744), size: 25),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFF030744).withOpacity(0.1),
                ),
                if (AuthService.isLoggedIn())
                  ListTileWidget(
                    leading: const Icon(
                      Icons.history,
                      color: Color(0xFF030744),
                    ),
                    title: const Text(
                      "History",
                      style: TextStyle(color: Color(0xFF030744), fontSize: 15),
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
                      color: Color(0xFF030744),
                    ),
                    title: const Text(
                      "Settings",
                      style: TextStyle(
                        color: Color(0xFF030744),
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
                    color: Color(0xFF030744),
                  ),
                  title: const Text(
                    "Assistance",
                    style: TextStyle(
                      color: Color(0xFF030744),
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
                    color: Color(0xFF030744),
                  ),
                  title: Text(
                    "Version ${version ?? "1.0.0"} (${versionCode ?? "1"})",
                    style: const TextStyle(
                      color: Color(0xFF030744),
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
          body: SafeArea(
            child: FutureBuilder<gmaps.LatLng?>(
              future: getMyLatLng(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF007BFF),
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
                                    enableGestures: !isBool(
                                      _scaffoldKey.currentState?.isDrawerOpen,
                                    ),
                                    onMapCreated: (map) {
                                      vm.setMap(map);
                                    },
                                    onCameraMove: (center) {
                                      final a = vm.disposed;
                                      final b = vm.markers ?? [];
                                      if (!a && b.isEmpty) {
                                        vm.mapCameraMove(center);
                                        debugPrint("Map move");
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
                                        final b = vm.markers ?? [];
                                        final c = vm.selectedAddress.value;
                                        if (b.isEmpty) {
                                          await vm.zoomToCurrentLocation();
                                        } else {
                                          vm.drawDropPolyLines(
                                            "pickup-dropoff",
                                            pickupAddress!.latLng,
                                            dropoffAddress!.latLng,
                                            null,
                                          );
                                        }
                                        if (!a && b.isEmpty && c == null) {
                                          vm.mapCameraMove(vm.map?.center);
                                          debugPrint("Map move");
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
                                              await LoadViewModel()
                                                  .getLoadBalance();
                                              AlertService().stopLoading();
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        _FloatingButton(
                                          icon: Icons.share,
                                          onTap: () {},
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
                                            final b = vm.markers ?? [];
                                            final c = vm.selectedAddress.value;
                                            await vm.zoomIn();
                                            if (!a && b.isEmpty && c == null) {
                                              vm.mapCameraMove(vm.map?.center);
                                              debugPrint("Map move");
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        _FloatingButton(
                                          icon: Icons.remove,
                                          onTap: () async {
                                            final a = vm.disposed;
                                            final b = vm.markers ?? [];
                                            final c = vm.selectedAddress.value;
                                            await vm.zoomOut();
                                            if (!a && b.isEmpty && c == null) {
                                              vm.mapCameraMove(vm.map?.center);
                                              debugPrint("Map move");
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  (vm.markers ?? []).isNotEmpty
                                      ? const SizedBox.shrink()
                                      : const Center(
                                          child: Padding(
                                            padding:
                                                EdgeInsets.only(bottom: 40),
                                            child: Icon(
                                              Icons.location_on,
                                              color: Color(0xFF007BFF),
                                              size: 50,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.1),
                                ),
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  child: vm.selectedAddress.value == null
                                      ? const SizedBox.shrink()
                                      : Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            child: SizedBox(
                                              width:
                                                  double.infinity.clamp(0, 800),
                                              child: Column(
                                                children: [
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      SizedBox(
                                                        width: ((MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width -
                                                                    64) /
                                                                3)
                                                            .clamp(0, 120),
                                                        height: ((MediaQuery.of(
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
                                                              borderRadius:
                                                                  const BorderRadius
                                                                      .all(
                                                                Radius.circular(
                                                                  8,
                                                                ),
                                                              ),
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    const Color(
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
                                                                  child:
                                                                      Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                    ),
                                                                    child: Image
                                                                        .asset(
                                                                      "assets/images/${lowerCase(gVehicleTypes.firstWhere(
                                                                            (v) =>
                                                                                v.slug ==
                                                                                "tricycle",
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
                                                                          (v) =>
                                                                              v.slug ==
                                                                              "tricycle",
                                                                        )
                                                                        .name!,
                                                                  ),
                                                                  style:
                                                                      const TextStyle(
                                                                    height:
                                                                        1.05,
                                                                    fontSize:
                                                                        16,
                                                                    color:
                                                                        Color(
                                                                      0xFF007BFF,
                                                                    ),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "${gVehicleTypes.firstWhere(
                                                                        (v) =>
                                                                            v.slug ==
                                                                            "tricycle",
                                                                      ).maxSeat!} Seater",
                                                                  style:
                                                                      const TextStyle(
                                                                    height:
                                                                        1.05,
                                                                    fontSize:
                                                                        12,
                                                                    color:
                                                                        Color(
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
                                                      const SizedBox(width: 15),
                                                      Expanded(
                                                        child: SizedBox(
                                                          height: ((MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width -
                                                                      64) /
                                                                  3)
                                                              .clamp(0, 120),
                                                          child: Column(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    WidgetButton(
                                                                  borderRadius:
                                                                      8,
                                                                  mainColor:
                                                                      const Color(
                                                                    0xFF007BFF,
                                                                  ),
                                                                  useDefaultHoverColor:
                                                                      false,
                                                                  child:
                                                                      Container(
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
                                                                          Border
                                                                              .all(
                                                                        color:
                                                                            const Color(
                                                                          0xFF007BFF,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    child:
                                                                        const Center(
                                                                      child:
                                                                          Text(
                                                                        "Cash",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  onTap: () {},
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 15),
                                                              Expanded(
                                                                child:
                                                                    WidgetButton(
                                                                  borderRadius:
                                                                      8,
                                                                  child:
                                                                      Container(
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
                                                                          Border
                                                                              .all(
                                                                        color:
                                                                            const Color(
                                                                          0xFF007BFF,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    child:
                                                                        const Center(
                                                                      child:
                                                                          Text(
                                                                        "Load",
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Color(
                                                                            0xFF007BFF,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  onTap: () {},
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 15),
                                                      WidgetButton(
                                                        onTap: () {
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
                                                                    const LoadView(),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        borderRadius: 8,
                                                        child: SizedBox(
                                                          width: ((MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width -
                                                                      64) /
                                                                  3)
                                                              .clamp(0, 120),
                                                          height: ((MediaQuery.of(
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
                                                                    child:
                                                                        Padding(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                      ),
                                                                      child: Image
                                                                          .asset(
                                                                        "assets/images/load.png",
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          8),
                                                                  Text(
                                                                    "₱${gLoad == null ? AuthService.isLoggedIn() ? "•••" : "0" : gLoad?.balance?.toStringAsFixed(0)}",
                                                                    style:
                                                                        const TextStyle(
                                                                      height:
                                                                          1.05,
                                                                      fontSize:
                                                                          16,
                                                                      color:
                                                                          Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                  ),
                                                                  const Text(
                                                                    "TODA Load",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.05,
                                                                      fontSize:
                                                                          12,
                                                                      color:
                                                                          Color(
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
                                                  GestureDetector(
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
                                                            await vm
                                                                .drawDropPolyLines(
                                                              "pickup-dropoff",
                                                              pickupAddress!
                                                                  .latLng,
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
                                                  WidgetButton(
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
                                                            await vm
                                                                .drawDropPolyLines(
                                                              "pickup-dropoff",
                                                              pickupAddress!
                                                                  .latLng,
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
                                                    mainColor:
                                                        const Color(0xFFEAF1FE),
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
                                                  const SizedBox(height: 15),
                                                  Row(
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
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  const BorderRadius
                                                                      .all(
                                                                Radius.circular(
                                                                  8,
                                                                ),
                                                              ),
                                                              border:
                                                                  Border.all(
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
                                                                        vm.ongoingOrder?.status !=
                                                                            "cancelled"
                                                                    ? () {
                                                                        if (vm.ongoingOrder?.status ==
                                                                            "pending") {
                                                                          return "Waiting";
                                                                        } else if (vm.ongoingOrder?.status ==
                                                                            "preparing") {
                                                                          return capitalizeWords(
                                                                            (vm.ongoingOrder?.taxiOrder?.tripDetails?.eta ?? "").toLowerCase().contains("any") || (vm.ongoingOrder?.taxiOrder?.tripDetails?.eta ?? "").toLowerCase().contains("unknown")
                                                                                ? "Any Second"
                                                                                : formatEtaText(vm.ongoingOrder!.taxiOrder!.tripDetails!.eta!),
                                                                          );
                                                                        } else {
                                                                          return travelTime(
                                                                            vm.ongoingOrder?.taxiOrder?.tripDetails?.kmDistance ??
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
                                                          text: "BOOK",
                                                          onTap: () {},
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
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  const BorderRadius
                                                                      .all(
                                                                Radius.circular(
                                                                  8,
                                                                ),
                                                              ),
                                                              border:
                                                                  Border.all(
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
                                                                        vm.ongoingOrder?.status !=
                                                                            "cancelled"
                                                                    ? AuthService
                                                                            .inReviewMode()
                                                                        ? vm.isPreparing
                                                                            ? "•••"
                                                                            : "${vm.ongoingOrder?.taxiOrder?.tripDetails?.kmDistance?.toStringAsFixed(1)} km"
                                                                        : vm.isPreparing
                                                                            ? "•••"
                                                                            : "${((vm.ongoingOrder?.subTotal ?? 0) + (vm.ongoingOrder?.taxiOrder?.pickupFee ?? 0)).toStringAsFixed(0)} ${vm.ongoingOrder?.paymentMethodId == 1 ? "Cash" : "Load"}"
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
                                                                                : "${vm.selectedVehicle?.total?.toStringAsFixed(0)} ${vm.paymentMethodId == 1 ? "Cash" : "Load"}",
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
                                                  const SizedBox(height: 20),
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
                        !vm.isLoading
                            ? const SizedBox()
                            : const Positioned(
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
                                        color: Color(0xFF007BFF),
                                      ),
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
              color: const Color(0xFF030744).withOpacity(0.25),
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
            color: const Color(0xFF030744),
          ),
        ),
      ),
    );
  }
}
