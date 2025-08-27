import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/view_models/map.vm.dart';
import 'package:pwa/widgets/gmap.widget.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class MapView extends StatefulWidget {
  final bool isPickup;

  const MapView({
    required this.isPickup,
    super.key,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapViewModel mapViewModel = MapViewModel();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<MapViewModel>.reactive(
      viewModelBuilder: () => mapViewModel,
      onViewModelReady: (vm) => vm.initialise(
        isPickup: widget.isPickup,
      ),
      builder: (context, vm, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: Stack(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {
                              Get.back();
                            },
                            icon: const Padding(
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
                          const SizedBox(width: 4),
                          Expanded(
                            child: TypeAheadField<Address>(
                              hideOnLoading: false,
                              controller: vm.searchTEC,
                              focusNode: vm.searchFocusNode,
                              debounceDuration: const Duration(
                                seconds: 1,
                              ),
                              onSelected: (Address address) {
                                vm.addressSelected(
                                  address,
                                  animate: true,
                                  isPickup: widget.isPickup,
                                );
                              },
                              emptyBuilder: (context) => ListTile(
                                title: Text(
                                  "Location not found, try it on the map",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF030744)
                                        .withOpacity(0.5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              errorBuilder: (context, error) => ListTile(
                                title: Text(
                                  "An error occurred, please try again",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF030744)
                                        .withOpacity(0.5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              itemBuilder: (context, suggestion) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 16,
                                ),
                                leading: ClipOval(
                                  child: Image.asset(
                                    "assets/images/logo.png",
                                    height: 25,
                                  ),
                                ),
                                title: Text(
                                  capitalizeWords(suggestion.addressLine),
                                  style: const TextStyle(
                                    height: 1,
                                    fontSize: 13,
                                    color: Color(0xFF030744),
                                  ),
                                ),
                              ),
                              decorationBuilder: (context, child) => Material(
                                elevation: 4,
                                color: Colors.white,
                                shape: const RoundedRectangleBorder(),
                                child: child,
                              ),
                              suggestionsCallback: (keyword) async {
                                if (keyword.isNotEmpty && keyword != "null") {
                                  return await vm.fetchPlaces(keyword);
                                } else {
                                  return [];
                                }
                              },
                              itemSeparatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 1,
                                color: const Color(0xFF030744).withOpacity(0.1),
                              ),
                              builder: (context, controller, focusNode) =>
                                  TextField(
                                focusNode: focusNode,
                                controller: controller,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF030744),
                                ),
                                decoration: InputDecoration(
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    color: const Color(0xFF030744)
                                        .withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  filled: true,
                                  fillColor:
                                      const Color(0xFF007BFF).withOpacity(0.1),
                                  prefixIcon: Icon(
                                    Icons.trip_origin,
                                    color: widget.isPickup
                                        ? const Color(0xFF007BFF)
                                        : Colors.red,
                                  ),
                                  suffixIcon: GestureDetector(
                                    onTap: () => vm.searchTEC.clear(),
                                    child: Icon(
                                      Icons.clear,
                                      color: const Color(0xFF030744)
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  hintText:
                                      "Search ${widget.isPickup ? "Pickup" : "Dropoff"}",
                                  contentPadding:
                                      const EdgeInsets.fromLTRB(4, 8, 0, 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: const Color(0xFF030744).withOpacity(0.1),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            GoogleMapWidget(
                              center: initLatLng!,
                              onMapCreated: (map) => vm.setMap(
                                  isPickup: widget.isPickup, map: map),
                              onCameraMove: (center) {
                                if (!vm.disposed) {
                                  vm.mapCameraMove(
                                    center,
                                    isPickup: widget.isPickup,
                                  );
                                  debugPrint("Map move");
                                }
                              },
                            ),
                            Positioned(
                              top: 20,
                              right: 20,
                              child: _FloatingButton(
                                icon: Icons.my_location_outlined,
                                onTap: () async {
                                  await vm.zoomToCurrentLocation();
                                  if (vm.selectedAddress.value == null) {
                                    if (!vm.disposed) {
                                      vm.mapCameraMove(
                                        vm.map?.center,
                                        isPickup: widget.isPickup,
                                      );
                                      debugPrint("Map move");
                                    }
                                  }
                                },
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
                                      await vm.zoomIn();
                                      if (vm.selectedAddress.value == null) {
                                        if (!vm.disposed) {
                                          vm.mapCameraMove(
                                            vm.map?.center,
                                            isPickup: widget.isPickup,
                                          );
                                          debugPrint("Map move");
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _FloatingButton(
                                    icon: Icons.remove,
                                    onTap: () async {
                                      await vm.zoomOut();
                                      if (vm.selectedAddress.value == null) {
                                        if (!vm.disposed) {
                                          vm.mapCameraMove(
                                            vm.map?.center,
                                            isPickup: widget.isPickup,
                                          );
                                          debugPrint("Map move");
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 40),
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
                            color: const Color(0xFF030744).withOpacity(0.1),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ValueListenableBuilder<Address?>(
                              valueListenable: vm.selectedAddress,
                              builder: (context, address, _) {
                                return Container(
                                  height: 75,
                                  width: double.infinity.clamp(0, 800),
                                  decoration: BoxDecoration(
                                    color:
                                        gVehicleTypes.isEmpty || mapUnavailable
                                            ? Colors.red.shade50
                                            : const Color(0xFF007BFF)
                                                .withOpacity(0.1),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 16),
                                      if (vm.isLoading && address == null)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      else
                                        Icon(
                                          gVehicleTypes.isEmpty ||
                                                  mapUnavailable
                                              ? Icons.warning
                                              : Icons.trip_origin,
                                          color: gVehicleTypes.isEmpty ||
                                                  mapUnavailable ||
                                                  !widget.isPickup
                                              ? Colors.red
                                              : const Color(0xFF007BFF),
                                        ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            gVehicleTypes.isEmpty ||
                                                    mapUnavailable
                                                ? const SizedBox()
                                                : Text(
                                                    capitalizeWords(
                                                        address?.addressLine
                                                                ?.split(
                                                                    ",")[0] ??
                                                            "",
                                                        alt: widget.isPickup
                                                            ? "Pickup"
                                                            : "Dropoff"),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      height: 1.05,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Color(0xFF030744),
                                                    ),
                                                  ),
                                            Text(
                                              gVehicleTypes.isEmpty ||
                                                      mapUnavailable
                                                  ? mapUnavailable
                                                      ? "Service location is not available"
                                                      : "An error occurred, please try again"
                                                  : capitalizeWords(
                                                      !(address?.addressLine ??
                                                                  "")
                                                              .contains(",")
                                                          ? address?.addressLine
                                                          : address?.addressLine
                                                              ?.split(", ")
                                                              .sublist(1)
                                                              .join(", "),
                                                      alt:
                                                          "Fetching details, please wait ...",
                                                    ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                height: 1.05,
                                                fontSize: 13,
                                                color: Color(0xFF030744),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: SizedBox(
                              height: 50,
                              width: double.infinity.clamp(0, 800),
                              child: ValueListenableBuilder<Address?>(
                                valueListenable: vm.selectedAddress,
                                builder: (context, address, _) {
                                  return Material(
                                    color: address == null
                                        ? const Color(0xFF030744)
                                            .withOpacity(0.25)
                                        : const Color(0xFF007BFF),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(8),
                                    ),
                                    child: Ink(
                                      child: ActionButton(
                                        onTap: () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          if (widget.isPickup) {
                                            pickupAddress = address;
                                          } else {
                                            dropoffAddress = address;
                                          }
                                          Navigator.pop(context, true);
                                        },
                                        text: address == null
                                            ? "•••"
                                            : "Confirm ${widget.isPickup ? "Pickup" : "Dropoff"}",
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
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

  const _FloatingButton({required this.icon, required this.onTap});

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
        onTap: onTap,
        child: Center(child: Icon(icon, color: const Color(0xFF030744))),
      ),
    );
  }
}
