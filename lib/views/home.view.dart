import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/views/history.view.dart';
import 'package:pwa/views/profile.view.dart';
import 'package:pwa/views/settings.view.dart';
import 'package:pwa/widgets/gmap.widget.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
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
  HomeViewModel homeViewModel = HomeViewModel();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
            shape: const RoundedRectangleBorder(),
            child: Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top,
                ),
                Container(
                  color: Colors.white,
                  child: WidgetButton(
                    borderRadius: 0,
                    onTap: () {
                      if (!AuthService.isLoggedIn()) {
                        Get.to(
                          () => const LoginView(),
                        );
                      } else {
                        setState(() {
                          agreed = false;
                          selfieFile = null;
                        });
                        Get.to(
                          () => const ProfileView(),
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: NetworkImageWidget(
                                    fit: BoxFit.cover,
                                    memCacheWidth: 600,
                                    imageUrl:
                                        AuthService.currentUser?.cPhoto ?? "",
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
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: Text(
                                  !AuthService.isLoggedIn()
                                      ? "Login Account"
                                      : capitalizeWords(
                                          "${AuthService.currentUser!.name}",
                                        ),
                                  style: const TextStyle(
                                    height: 1.05,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF030744),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF030744),
                                size: 25,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1.05,
                  thickness: 1,
                  color: const Color(0xFF030744).withOpacity(0.1),
                ),
                !AuthService.isLoggedIn()
                    ? const SizedBox()
                    : ListTileWidget(
                        leading: const Icon(
                          Icons.history,
                          color: Color(0xFF030744),
                        ),
                        title: const Text(
                          "History",
                          style: TextStyle(
                            color: Color(0xFF030744),
                            fontSize: 15,
                          ),
                        ),
                        onTap: () {
                          Get.to(
                            () => const HistoryView(),
                          );
                        },
                      ),
                !AuthService.isLoggedIn()
                    ? const SizedBox()
                    : ListTileWidget(
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
                            Get.to(
                              () => const LoginView(),
                            );
                          } else {
                            Get.to(
                              () => const SettingsView(),
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
                      mode: LaunchMode.externalNonBrowserApplication,
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
                        mode: LaunchMode.externalNonBrowserApplication,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          onDrawerChanged: (value) {
            setState(() {});
          },
          backgroundColor: Colors.white,
          body: FutureBuilder<gmaps.LatLng?>(
            future: getMyLatLng(),
            builder: (context, myLatLng) {
              initLatLng = myLatLng.data ?? gmaps.LatLng(9.7638, 118.7473);
              if (!myLatLng.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              GoogleMapWidget(
                                center: myLatLng.data!,
                                enableGestures: !isBool(
                                  _scaffoldKey.currentState?.isDrawerOpen,
                                ),
                                viewModel: vm,
                              ),
                              Positioned(
                                top: 20,
                                left: 20,
                                child: Column(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        return Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF030744)
                                                    .withOpacity(
                                                  0.25,
                                                ),
                                                spreadRadius: 0,
                                                blurRadius: 2,
                                                offset: const Offset(
                                                  0,
                                                  2,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: WidgetButton(
                                            onTap: () async {
                                              Scaffold.of(context).openDrawer();
                                            },
                                            child: const Center(
                                              child: Icon(
                                                Icons.menu,
                                                color: Color(0xFF030744),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 20,
                                right: 20,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF030744)
                                                .withOpacity(
                                              0.25,
                                            ),
                                            spreadRadius: 0,
                                            blurRadius: 2,
                                            offset: const Offset(
                                              0,
                                              2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: WidgetButton(
                                        onTap: () async {
                                          vm.zoomToCurrentLocation();
                                        },
                                        child: const Center(
                                          child: Icon(
                                            Icons.my_location_outlined,
                                            color: Color(0xFF030744),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 20,
                                bottom: 20,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF030744)
                                                .withOpacity(
                                              0.25,
                                            ),
                                            spreadRadius: 0,
                                            blurRadius: 2,
                                            offset: const Offset(
                                              0,
                                              2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: WidgetButton(
                                        onTap: () async {},
                                        child: const Center(
                                          child: Icon(
                                            Icons.cached_outlined,
                                            color: Color(0xFF030744),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF030744)
                                                .withOpacity(
                                              0.25,
                                            ),
                                            spreadRadius: 0,
                                            blurRadius: 2,
                                            offset: const Offset(
                                              0,
                                              2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: WidgetButton(
                                        onTap: () {},
                                        child: const Center(
                                          child: Icon(
                                            Icons.share,
                                            color: Color(0xFF030744),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 20,
                                bottom: 20,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF030744)
                                                .withOpacity(
                                              0.25,
                                            ),
                                            spreadRadius: 0,
                                            blurRadius: 2,
                                            offset: const Offset(
                                              0,
                                              2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: WidgetButton(
                                        onTap: () async {
                                          vm.zoomIn();
                                        },
                                        child: const Center(
                                          child: Icon(
                                            Icons.add,
                                            color: Color(0xFF030744),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF030744)
                                                .withOpacity(
                                              0.25,
                                            ),
                                            spreadRadius: 0,
                                            blurRadius: 2,
                                            offset: const Offset(
                                              0,
                                              2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: WidgetButton(
                                        onTap: () {
                                          vm.zoomOut();
                                        },
                                        child: const Center(
                                          child: Icon(
                                            Icons.remove,
                                            color: Color(0xFF030744),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: 40,
                                  ),
                                  child: Icon(
                                    Icons.location_on_sharp,
                                    color: Color(0xFF007BFF),
                                    size: 50,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          color: Colors.white,
                          child: const Column(
                            children: [
                              Text("data"),
                              Text("data"),
                              Text("data"),
                              Text("data"),
                              Text("data"),
                              Text("data"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
