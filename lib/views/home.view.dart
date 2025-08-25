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
  final HomeViewModel homeViewModel = HomeViewModel();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    homeViewModel.dispose();
    super.dispose();
  }

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
                                  strokeWidth: 2,
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
                        const SizedBox(width: 12),
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
                        const SizedBox(width: 12),
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
          onDrawerChanged: (isOpened) {
            setState(() {});
          },
          backgroundColor: Colors.white,
          body: FutureBuilder<gmaps.LatLng?>(
            future: getMyLatLng(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              final center = snapshot.data!;
              return Stack(
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
                              viewModel: vm,
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
                                onTap: () {
                                  vm.zoomToCurrentLocation();
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
                                    onTap: () {},
                                  ),
                                  const SizedBox(height: 8),
                                  _FloatingButton(
                                    icon: Icons.share,
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
                                    onTap: () {
                                      vm.zoomIn();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _FloatingButton(
                                    icon: Icons.remove,
                                    onTap: () {
                                      vm.zoomOut();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 40),
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
