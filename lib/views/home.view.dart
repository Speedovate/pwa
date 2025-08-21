import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/widgets/gmap.widget.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';
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
          backgroundColor: const Color(0xFFFFFFFF),
          body: FutureBuilder<gmaps.LatLng>(
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
                                        child: Ink(
                                          child: InkWell(
                                            hoverDuration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            onTap: () async {},
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            focusColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            hoverColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            splashColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            highlightColor:
                                                const Color(0xFF030744)
                                                    .withOpacity(
                                              0.2,
                                            ),
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
                                        child: Ink(
                                          child: InkWell(
                                            hoverDuration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            onTap: () async {
                                              vm.zoomToCurrentLocation();
                                            },
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            focusColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            hoverColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            splashColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            highlightColor:
                                                const Color(0xFF030744)
                                                    .withOpacity(
                                              0.2,
                                            ),
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
                                        child: Ink(
                                          child: InkWell(
                                            hoverDuration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            onTap: () async {},
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            focusColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            hoverColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            splashColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            highlightColor:
                                                const Color(0xFF030744)
                                                    .withOpacity(
                                              0.2,
                                            ),
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
                                        child: Ink(
                                          child: InkWell(
                                            hoverDuration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            onTap: () {},
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            focusColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            hoverColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            splashColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            highlightColor:
                                                const Color(0xFF030744)
                                                    .withOpacity(
                                              0.2,
                                            ),
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
                                        child: Ink(
                                          child: InkWell(
                                            hoverDuration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            onTap: () async {
                                              vm.zoomIn();
                                            },
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            focusColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            hoverColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            splashColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            highlightColor:
                                                const Color(0xFF030744)
                                                    .withOpacity(
                                              0.2,
                                            ),
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
                                        child: Ink(
                                          child: InkWell(
                                            hoverDuration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            onTap: () {
                                              vm.zoomOut();
                                            },
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            focusColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            hoverColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            splashColor: const Color(0xFF030744)
                                                .withOpacity(
                                              0.2,
                                            ),
                                            highlightColor:
                                                const Color(0xFF030744)
                                                    .withOpacity(
                                              0.2,
                                            ),
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
                          color: const Color(0xFFFFFFFF),
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
