import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/widgets/list_tile.dart';
import 'package:pwa/views/history.view.dart';
import 'package:pwa/views/profile.view.dart';
import 'package:pwa/views/settings.view.dart';
import 'package:pwa/widgets/gmap.widget.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';
import 'package:pwa/widgets/cached_network_image.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  HomeViewModel homeViewModel = HomeViewModel();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HomeViewModel>.reactive(
      viewModelBuilder: () => homeViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return Scaffold(
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
                  child: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      child: GestureDetector(
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
                        // focusColor: const Color(0xFF030744).withOpacity(
                        //   0.1,
                        // ),
                        // hoverColor: const Color(0xFF030744).withOpacity(
                        //   0.1,
                        // ),
                        // splashColor: const Color(0xFF030744).withOpacity(
                        //   0.1,
                        // ),
                        // highlightColor: const Color(0xFF030744).withOpacity(
                        //   0.1,
                        // ),
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
                                      child: CachedNetworkImageWidget(
                                        fit: BoxFit.cover,
                                        memCacheWidth: 600,
                                        imageUrl:
                                            AuthService.currentUser?.cPhoto ??
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
                                            color: const Color(0xFF030744),
                                            child: const Icon(
                                              MingCuteIcons.mgc_user_3_line,
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
                                    MingCuteIcons.mgc_right_line,
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
                          MingCuteIcons.mgc_history_line,
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
                          MingCuteIcons.mgc_settings_3_line,
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
                    MingCuteIcons.mgc_headphone_line,
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
                    MingCuteIcons.mgc_code_line,
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
          backgroundColor: Colors.white,
          body: FutureBuilder<gmaps.LatLng?>(
            future: getMyLatLng(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
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
                                center: snapshot.data!,
                                viewModel: vm,
                              ),
                              Positioned(
                                top: 20,
                                left: 20,
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
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        child: SizedBox(
                                          child: GestureDetector(
                                            // hoverDuration: const Duration(
                                            //   milliseconds: 500,
                                            // ),
                                            onTap: () async {
                                              Scaffold.of(context).openDrawer();
                                            },
                                            // borderRadius:
                                            //     const BorderRadius.all(
                                            //   Radius.circular(
                                            //     1000,
                                            //   ),
                                            // ),
                                            // focusColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // hoverColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // splashColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // highlightColor:
                                            //     const Color(0xFF030744)
                                            //         .withOpacity(
                                            //   0.2,
                                            // ),
                                            child: const Center(
                                              child: Icon(
                                                MingCuteIcons.mgc_menu_line,
                                                color: Color(0xFF030744),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
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
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        child: SizedBox(
                                          child: GestureDetector(
                                            // hoverDuration: const Duration(
                                            //   milliseconds: 500,
                                            // ),
                                            onTap: () async {
                                              vm.zoomToCurrentLocation();
                                            },
                                            // borderRadius:
                                            //     const BorderRadius.all(
                                            //   Radius.circular(
                                            //     1000,
                                            //   ),
                                            // ),
                                            // focusColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // hoverColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // splashColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // highlightColor:
                                            //     const Color(0xFF030744)
                                            //         .withOpacity(
                                            //   0.2,
                                            // ),
                                            child: const Center(
                                              child: Icon(
                                                MingCuteIcons.mgc_aiming_line,
                                                color: Color(0xFF030744),
                                              ),
                                            ),
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
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        child: SizedBox(
                                          child: GestureDetector(
                                            // hoverDuration: const Duration(
                                            //   milliseconds: 500,
                                            // ),
                                            onTap: () async {},
                                            // borderRadius:
                                            //     const BorderRadius.all(
                                            //   Radius.circular(
                                            //     1000,
                                            //   ),
                                            // ),
                                            // focusColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // hoverColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // splashColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // highlightColor:
                                            //     const Color(0xFF030744)
                                            //         .withOpacity(
                                            //   0.2,
                                            // ),
                                            child: const Center(
                                              child: Icon(
                                                MingCuteIcons
                                                    .mgc_refresh_2_line,
                                                color: Color(0xFF030744),
                                              ),
                                            ),
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
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        child: SizedBox(
                                          child: GestureDetector(
                                            // hoverDuration: const Duration(
                                            //   milliseconds: 500,
                                            // ),
                                            onTap: () {},
                                            // borderRadius:
                                            //     const BorderRadius.all(
                                            //   Radius.circular(
                                            //     1000,
                                            //   ),
                                            // ),
                                            // focusColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // hoverColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // splashColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // highlightColor:
                                            //     const Color(0xFF030744)
                                            //         .withOpacity(
                                            //   0.2,
                                            // ),
                                            child: const Center(
                                              child: Icon(
                                                MingCuteIcons
                                                    .mgc_share_forward_line,
                                                color: Color(0xFF030744),
                                              ),
                                            ),
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
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        child: SizedBox(
                                          child: GestureDetector(
                                            // hoverDuration: const Duration(
                                            //   milliseconds: 500,
                                            // ),
                                            onTap: () async {
                                              vm.zoomIn();
                                            },
                                            // borderRadius:
                                            //     const BorderRadius.all(
                                            //   Radius.circular(
                                            //     1000,
                                            //   ),
                                            // ),
                                            // focusColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // hoverColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // splashColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // highlightColor:
                                            //     const Color(0xFF030744)
                                            //         .withOpacity(
                                            //   0.2,
                                            // ),
                                            child: const Center(
                                              child: Icon(
                                                MingCuteIcons.mgc_add_line,
                                                color: Color(0xFF030744),
                                              ),
                                            ),
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
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                            1000,
                                          ),
                                        ),
                                        child: SizedBox(
                                          child: GestureDetector(
                                            // hoverDuration: const Duration(
                                            //   milliseconds: 500,
                                            // ),
                                            onTap: () {
                                              vm.zoomOut();
                                            },
                                            // borderRadius:
                                            //     const BorderRadius.all(
                                            //   Radius.circular(
                                            //     1000,
                                            //   ),
                                            // ),
                                            // focusColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // hoverColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // splashColor: const Color(0xFF030744)
                                            //     .withOpacity(
                                            //   0.2,
                                            // ),
                                            // highlightColor:
                                            //     const Color(0xFF030744)
                                            //         .withOpacity(
                                            //   0.2,
                                            // ),
                                            child: const Center(
                                              child: Icon(
                                                MingCuteIcons.mgc_minimize_line,
                                                color: Color(0xFF030744),
                                              ),
                                            ),
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
