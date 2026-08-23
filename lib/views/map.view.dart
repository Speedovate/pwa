import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/view_models/map.vm.dart';
import 'package:pwa/widgets/gmap.widget.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:carousel_slider/carousel_slider.dart';
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
  static const Duration _mapDragUnlockDelay = Duration(seconds: 1);
  final MapViewModel mapViewModel = MapViewModel();
  final SuggestionsController<Address> _searchSuggestionsController =
      SuggestionsController<Address>();
  static const double _minimumPickupDropoffDistanceMeters = 100;
  Timer? _mapInteractionDelayTimer;
  bool _keepMapInteractionBlocked = false;
  DateTime? _lastDesktopSiteSearchTapAt;
  int _searchFieldStabilizerToken = 0;

  bool get _isDesktopSitePhoneWeb =>
      kIsWeb && isDesktopSiteOnPhoneBrowser();

  bool _sameCoordinates(Address a, Address b) {
    return a.coordinates.latitude == b.coordinates.latitude &&
        a.coordinates.longitude == b.coordinates.longitude;
  }

  bool _isTooCloseToExistingSelection(Address a, Address b) {
    final distanceMeters = Geolocator.distanceBetween(
      a.coordinates.latitude,
      a.coordinates.longitude,
      b.coordinates.latitude,
      b.coordinates.longitude,
    );
    return distanceMeters <= _minimumPickupDropoffDistanceMeters;
  }

  @override
  void initState() {
    super.initState();
    mapViewModel.searchFocusNode.addListener(_handleSearchFocusChange);
    mapViewModel.addListener(_handleMapLoadingChanged);
  }

  void _handleSearchFocusChange() {
    if (!_isDesktopSitePhoneWeb || mapViewModel.searchFocusNode.hasFocus) {
      return;
    }
    final lastTapAt = _lastDesktopSiteSearchTapAt;
    if (lastTapAt == null ||
        DateTime.now().difference(lastTapAt) >
            const Duration(milliseconds: 1200)) {
      return;
    }
    _scheduleSearchFieldFocusStabilizer();
  }

  void _recordSearchFieldTap() {
    if (!_isDesktopSitePhoneWeb) {
      return;
    }
    _lastDesktopSiteSearchTapAt = DateTime.now();
    _scheduleSearchFieldFocusStabilizer();
  }

  void _scheduleSearchFieldFocusStabilizer() {
    if (!_isDesktopSitePhoneWeb) {
      return;
    }
    final token = ++_searchFieldStabilizerToken;
    const delays = <int>[0, 80, 180, 320, 520, 820];
    for (final delayMs in delays) {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted ||
            token != _searchFieldStabilizerToken ||
            mapViewModel.searchFocusNode.hasFocus) {
          return;
        }
        final lastTapAt = _lastDesktopSiteSearchTapAt;
        if (lastTapAt == null ||
            DateTime.now().difference(lastTapAt) >
                const Duration(milliseconds: 1200)) {
          return;
        }
        mapViewModel.searchFocusNode.requestFocus();
      });
    }
  }

  void _handleMapLoadingChanged() {
    final isVisible = mapViewModel.isLoading;
    if (_mapInteractionDelayTimer != null) {
      tempTimerDebug(
        "map_view.interaction_delay",
        "cancel_before_reschedule",
        details: {
          "instanceId": tempTimerInstanceId(_mapInteractionDelayTimer),
        },
      );
    }
    _mapInteractionDelayTimer?.cancel();
    _mapInteractionDelayTimer = null;
    if (isVisible) {
      if (!_keepMapInteractionBlocked && mounted) {
        setState(() {
          _keepMapInteractionBlocked = true;
        });
      }
      return;
    }
    final instanceId = nextTempTimerInstanceId("map_view.interaction_delay");
    tempTimerDebug(
      "map_view.interaction_delay",
      "schedule",
      details: {
        "instanceId": instanceId,
      },
    );
    _mapInteractionDelayTimer = Timer(
      _mapDragUnlockDelay,
      () {
        _mapInteractionDelayTimer = null;
        tempTimerDebug(
          "map_view.interaction_delay",
          "fire",
          details: {
            "instanceId": instanceId,
          },
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _keepMapInteractionBlocked = false;
        });
      },
    );
    if (_mapInteractionDelayTimer != null) {
      attachTempTimerInstanceId(_mapInteractionDelayTimer!, instanceId);
    }
  }

  @override
  void dispose() {
    mapViewModel.searchFocusNode.removeListener(_handleSearchFocusChange);
    if (_mapInteractionDelayTimer != null) {
      tempTimerDebug(
        "map_view.interaction_delay",
        "dispose_cancel",
        details: {
          "instanceId": tempTimerInstanceId(_mapInteractionDelayTimer),
        },
      );
    }
    _mapInteractionDelayTimer?.cancel();
    _mapInteractionDelayTimer = null;
    mapViewModel.removeListener(_handleMapLoadingChanged);
    _searchSuggestionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<MapViewModel>.reactive(
      viewModelBuilder: () => mapViewModel,
      onViewModelReady: (vm) => vm.initialise(
        isPickup: widget.isPickup,
      ),
      builder: (context, vm, child) {
        final mediaQuery = MediaQuery.of(context);
        final forcedWidth = _isDesktopSitePhoneWeb
            ? browserScreenShortSide()
            : mediaQuery.size.width;
        final effectiveMediaQuery = _isDesktopSitePhoneWeb && forcedWidth > 0
            ? mediaQuery.copyWith(
                size: Size(forcedWidth, mediaQuery.size.height),
              )
            : mediaQuery;
        return MediaQuery(
          data: effectiveMediaQuery,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: kIsWeb
                  ? null
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _searchSuggestionsController.close();
                    },
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: effectiveMediaQuery.size.width,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: effectiveMediaQuery.size.width,
                      height: effectiveMediaQuery.size.height,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: effectiveMediaQuery.padding.top,
                          bottom: 12,
                        ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 58,
                                height: 58,
                                child: WidgetButton(
                                  onTap: () {
                                    Get.back();
                                  },
                                  mainColor: Colors.transparent,
                                  isTransparentColor: true,
                                  useDefaultHoverColor: false,
                                  interactionColor: const Color(0x14030744),
                                  borderRadius: 1000,
                                  child: const Center(
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
                              const SizedBox(width: 4),
                              Expanded(
                                child: TypeAheadField<Address>(
                                  hideOnEmpty: true,
                                  hideOnLoading: false,
                                  controller: vm.searchTEC,
                                  focusNode: vm.searchFocusNode,
                                  suggestionsController:
                                      _searchSuggestionsController,
                                  debounceDuration: const Duration(
                                    seconds: 1,
                                  ),
                                  onSelected: (Address address) async {
                                    setState(() {
                                      vm.skipCamera = true;
                                    });
                                    _searchSuggestionsController.close();
                                    await vm.addressSelected(
                                      address,
                                      animate: true,
                                      isPickup: widget.isPickup,
                                    );
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    await Future.delayed(
                                      const Duration(
                                        milliseconds: 500,
                                      ),
                                    );
                                    setState(() {
                                      vm.skipCamera = false;
                                    });
                                  },
                                  loadingBuilder: (context) => SizedBox(
                                    height: 50,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
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
                                              ).withValues(alpha: 0.25),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  emptyBuilder: (context) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      "Try another keyword, or find on map!",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF030744)
                                            .withValues(alpha: 0.5),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  errorBuilder: (context, error) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      "An error occurred. Please try again",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF030744)
                                            .withValues(alpha: 0.5),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  itemBuilder: (context, suggestion) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        const ClipOval(
                                          child: NetworkImageWidget(
                                            imageUrl: AppImages.logo,
                                            memCacheWidth: 600,
                                            height: 25,
                                            width: 25,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            capitalizeWords(
                                              suggestion.addressLine,
                                            ),
                                            style: const TextStyle(
                                              height: 1,
                                              fontSize: 13,
                                              color: Color(0xFF030744),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  decorationBuilder: (context, child) =>
                                      Material(
                                    elevation: 4,
                                    color: Colors.white,
                                    shape: const RoundedRectangleBorder(),
                                    child: child,
                                  ),
                                  suggestionsCallback: (keyword) async {
                                    if (keyword.trim().isEmpty) return [];
                                    return await vm.fetchPlaces(keyword);
                                  },
                                  itemSeparatorBuilder: (context, index) =>
                                      Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: const Color(0xFF030744)
                                        .withValues(alpha: 0.1),
                                  ),
                                  builder: (context, controller, focusNode) =>
                                      TextField(
                                    focusNode: focusNode,
                                    controller: controller,
                                    onTap: _recordSearchFieldTap,
                                    onTapOutside: _isDesktopSitePhoneWeb
                                        ? (_) {}
                                        : null,
                                    textInputAction: TextInputAction.search,
                                    textAlignVertical: TextAlignVertical.center,
                                    scrollPadding: const EdgeInsets.only(
                                      left: 24,
                                      top: 24,
                                      right: 24,
                                      bottom: 120,
                                    ),
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF030744),
                                    ),
                                    decoration: InputDecoration(
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF030744)
                                            .withValues(alpha: 0.5),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF007BFF)
                                          .withValues(alpha: 0.1),
                                      prefixIcon: Icon(
                                        Icons.trip_origin,
                                        color: widget.isPickup
                                            ? const Color(0xFF007BFF)
                                            : Colors.red,
                                      ),
                                      suffixIcon: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          controller.clear();
                                          if (controller != vm.searchTEC) {
                                            vm.searchTEC.clear();
                                          }
                                          _searchSuggestionsController.close(
                                            retainFocus: true,
                                          );
                                          _searchSuggestionsController
                                              .refresh();
                                        },
                                        child: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: Center(
                                            child: Icon(
                                              Icons.clear,
                                              color: const Color(0xFF030744)
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
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
                            color:
                                const Color(0xFF030744).withValues(alpha: 0.1),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                GoogleMapWidget(
                                  center: initLatLng ?? defaultLatLng,
                                  enableGestures: !_keepMapInteractionBlocked &&
                                      !vm.isHolding,
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _searchSuggestionsController.close();
                                  },
                                  onMapCreated: (map) => vm.setMap(
                                    isPickup: widget.isPickup,
                                    map: map,
                                  ),
                                  onCameraMoveStart: () {
                                    try {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      vm.beginCameraMoveVisual();
                                    } catch (e) {
                                      // Ignore transient camera callback issues.
                                    }
                                  },
                                  onCameraMove: (center) {
                                    try {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      final a = vm.disposed;
                                      if (!a &&
                                          !_keepMapInteractionBlocked &&
                                          !vm.skipCamera &&
                                          vm.shouldProcessCameraMove(center)) {
                                        vm.mapCameraMove(
                                          center,
                                          isPickup: widget.isPickup,
                                        );
                                      }
                                    } catch (e) {
                                      // Ignore transient camera callback issues.
                                    }
                                  },
                                ),
                                AuthService.inReviewMode() || gSpots.isEmpty
                                    ? const SizedBox()
                                    : Positioned(
                                        top: 20,
                                        left: 20,
                                        right: 85,
                                        child: Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(1000),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF030744)
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 2,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            child: Listener(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onPointerDown: (_) {
                                                setState(() {
                                                  vm.isHolding = true;
                                                });
                                              },
                                              onPointerUp: (_) {
                                                setState(() {
                                                  vm.isHolding = false;
                                                });
                                              },
                                              onPointerCancel: (_) {
                                                setState(() {
                                                  vm.isHolding = false;
                                                });
                                              },
                                              child: CarouselSlider(
                                                items: gSpots.map((spot) {
                                                  return WidgetButton(
                                                    onTap: () async {
                                                      await vm
                                                          .selectSpotAddress(
                                                        spot,
                                                        isPickup:
                                                            widget.isPickup,
                                                      );
                                                    },
                                                    child: Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 12,
                                                        ),
                                                        child: Text(
                                                          spot.addressLine
                                                                  ?.split(
                                                                      ",")[0] ??
                                                              'Unknown',
                                                          style:
                                                              const TextStyle(
                                                            height: 1.05,
                                                            fontSize: 14,
                                                            color: Color(
                                                                0xFF030744),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                options: CarouselOptions(
                                                  height: 45,
                                                  autoPlay: true,
                                                  viewportFraction: 1,
                                                  autoPlayInterval:
                                                      const Duration(
                                                    seconds: 5,
                                                  ),
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  enableInfiniteScroll:
                                                      gSpots.length > 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                Positioned(
                                  top: 20,
                                  right: 20,
                                  child: _FloatingButton(
                                    icon: Icons.my_location_outlined,
                                    onTap: () async {
                                      final target =
                                          await vm.zoomToCurrentLocation();
                                      if (!vm.disposed &&
                                          target != null &&
                                          vm.lastCurrentLocationRecenterMoved) {
                                        vm.mapCameraMove(
                                          target,
                                          isPickup: widget.isPickup,
                                          debounceDuration: Duration.zero,
                                        );
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
                                          if (vm.selectedAddress.value ==
                                              null) {
                                            if (!vm.disposed) {
                                              vm.mapCameraMove(
                                                vm.mapCenter,
                                                isPickup: widget.isPickup,
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      _FloatingButton(
                                        icon: Icons.remove,
                                        onTap: () async {
                                          await vm.zoomOut();
                                          if (vm.selectedAddress.value ==
                                              null) {
                                            if (!vm.disposed) {
                                              vm.mapCameraMove(
                                                vm.mapCenter,
                                                isPickup: widget.isPickup,
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 40),
                                    child: Icon(
                                      Icons.location_on,
                                      color: widget.isPickup
                                          ? const Color(0xFF007BFF)
                                          : Colors.red,
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
                                color: const Color(0xFF030744)
                                    .withValues(alpha: 0.1),
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: ValueListenableBuilder<Address?>(
                                  valueListenable: vm.selectedAddress,
                                  builder: (context, address, _) {
                                    return ValueListenableBuilder<Address?>(
                                      valueListenable:
                                          vm.visualPlaceholderAddress,
                                      builder:
                                          (context, visualPlaceholder, __) {
                                        final displayAddress =
                                            address ?? visualPlaceholder;
                                        return Container(
                                          height: 75,
                                          width: double.infinity.clamp(0, 800),
                                          decoration: BoxDecoration(
                                            color: gVehicleTypes.isEmpty ||
                                                    mapUnavailable
                                                ? Colors.red.shade50
                                                : const Color(0xFF007BFF)
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(8),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 16),
                                              if (vm.showLoadingVisual)
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 4,
                                                  ),
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeCap:
                                                          StrokeCap.round,
                                                      color: widget.isPickup
                                                          ? const Color(
                                                              0xFF007BFF)
                                                          : Colors.red,
                                                      backgroundColor:
                                                          widget.isPickup
                                                              ? const Color(
                                                                  0xFF007BFF,
                                                                ).withValues(
                                                                  alpha: 0.25,
                                                                )
                                                              : Colors.red
                                                                  .withValues(
                                                                  alpha: 0.25,
                                                                ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Icon(
                                                  gVehicleTypes.isEmpty ||
                                                          mapUnavailable
                                                      ? Icons.warning
                                                      : Icons.trip_origin,
                                                  color: gVehicleTypes
                                                              .isEmpty ||
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
                                                        ? const SizedBox
                                                            .shrink()
                                                        : Text(
                                                            capitalizeWords(
                                                                vm.showLoadingVisual
                                                                    ? null
                                                                    : displayAddress?.addressLine?.split(",")[
                                                                            0] ??
                                                                        "",
                                                                alt: widget
                                                                        .isPickup
                                                                    ? "Pickup"
                                                                    : "Dropoff"),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              height: 1.05,
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Color(
                                                                  0xFF030744),
                                                            ),
                                                          ),
                                                    Text(
                                                      gVehicleTypes.isEmpty ||
                                                              mapUnavailable
                                                          ? mapUnavailable
                                                              ? "Service location is not available"
                                                              : "An error occurred. Please try again"
                                                          : capitalizeWords(
                                                              vm
                                                                      .showLoadingVisual
                                                                  ? null
                                                                  : !(displayAddress?.addressLine ??
                                                                              "")
                                                                          .contains(
                                                                              ",")
                                                                      ? displayAddress
                                                                          ?.addressLine
                                                                      : displayAddress
                                                                          ?.addressLine
                                                                          ?.split(
                                                                              ", ")
                                                                          .sublist(
                                                                              1)
                                                                          .join(
                                                                              ", "),
                                                              alt:
                                                                  "Fetching details, please wait ...",
                                                            ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: gVehicleTypes
                                                                  .isEmpty ||
                                                              mapUnavailable
                                                          ? const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Color(
                                                                0xFF030744,
                                                              ),
                                                            )
                                                          : const TextStyle(
                                                              height: 1.05,
                                                              fontSize: 13,
                                                              color: Color(
                                                                0xFF030744,
                                                              ),
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
                                      return ValueListenableBuilder<Address?>(
                                        valueListenable:
                                            vm.visualPlaceholderAddress,
                                        builder:
                                            (context, visualPlaceholder, __) {
                                          final shouldRequireVehicleTypes =
                                              !kIsWeb && gVehicleTypes.isEmpty;
                                          final shouldRetry =
                                              shouldRequireVehicleTypes ||
                                                  mapUnavailable;
                                          final effectiveAddress =
                                              address ?? visualPlaceholder;
                                          final hasEffectiveAddress =
                                              effectiveAddress != null;
                                          return Material(
                                            color: vm.showLoadingVisual ||
                                                    !hasEffectiveAddress
                                                ? const Color(0xFF030744)
                                                    .withValues(alpha: 0.25)
                                                : const Color(0xFF007BFF),
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(8),
                                            ),
                                            child: ActionButton(
                                              onTap: () {
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                                if (shouldRetry) {
                                                  vm.setMap(
                                                    isPickup: widget.isPickup,
                                                    map: vm.map!,
                                                  );
                                                } else {
                                                  if (!vm.showLoadingVisual &&
                                                      hasEffectiveAddress) {
                                                    final conflictsWithExistingSelection = widget
                                                            .isPickup
                                                        ? dropoffAddress !=
                                                                null &&
                                                            (_sameCoordinates(
                                                                  effectiveAddress,
                                                                  dropoffAddress!,
                                                                ) ||
                                                                _isTooCloseToExistingSelection(
                                                                  effectiveAddress,
                                                                  dropoffAddress!,
                                                                ))
                                                        : pickupAddress !=
                                                                null &&
                                                            (_sameCoordinates(
                                                                  effectiveAddress,
                                                                  pickupAddress!,
                                                                ) ||
                                                                _isTooCloseToExistingSelection(
                                                                  effectiveAddress,
                                                                  pickupAddress!,
                                                                ));
                                                    if (conflictsWithExistingSelection) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .clearSnackBars();
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          backgroundColor:
                                                              Colors.red,
                                                          content: Text(
                                                            "Pickup and dropoff must differ",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    if (widget.isPickup) {
                                                      pickupAddress =
                                                          effectiveAddress;
                                                    } else {
                                                      dropoffAddress =
                                                          effectiveAddress;
                                                    }
                                                    Navigator.pop(
                                                        context, true);
                                                  }
                                                }
                                              },
                                              mainColor: shouldRetry
                                                  ? Colors.red
                                                  : const Color(0xFF007BFF),
                                              text: shouldRetry
                                                  ? "Retry"
                                                  : vm.showLoadingVisual
                                                      ? "•••"
                                                      : hasEffectiveAddress
                                                          ? "Confirm ${widget.isPickup ? "Pickup" : "Dropoff"}"
                                                          : "•••",
                                            ),
                                          );
                                        },
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
		            ),
		          ),
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
              color: const Color(0xFF030744).withValues(alpha: 0.25),
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
