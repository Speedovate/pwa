import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:google_maps/google_maps.dart' as gmaps;
import 'package:pwa/widgets/gmap.widget.dart';

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
                    GoogleMapWidget(
                      center: snapshot.data!,
                      viewModel: vm,
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
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        onPressed: () {
                          vm.map?.zoom= 21;
                          vm.notifyListeners();
                        },
                        backgroundColor: const Color(
                          0xFFFFFFFF,
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Color(
                            0xFF000000,
                          ),
                        ),
                      ),
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
