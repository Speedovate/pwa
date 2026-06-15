// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/views/map.view.dart';
import 'package:pwa/views/load.view.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/constants/lotties.dart';
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
import 'package:pwa/widgets/text_field.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/push.service.dart';
import 'package:pwa/view_models/splash.vm.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/partner_button.dart';
import 'package:pwa/widgets/partner_display.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/widgets/list_tile.widget.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:pwa/widgets/quick_chat_pills.widget.dart';
import 'package:pwa/widgets/top_cropped_network_image.widget.dart';
import 'package:pwa/widgets/upgrade.widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  static final DateTime _phpStyleProfilePhotoStartDate = DateTime(2026, 6, 6);
  static const double _currentUserTopHalfVisibleFractionWeb = 0.55;
  static const double _currentUserTopHalfVisibleFractionMobile = 0.60;
  static const Duration _homeMapDragUnlockDelay = Duration(seconds: 1);
  ValueNotifier<int> itemsIndex = ValueNotifier(0);
  final HomeViewModel homeViewModel = HomeViewModel();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<double> _keyboardInsetNotifier = ValueNotifier(0);
  late Future<gmaps.LatLng?> _initialCenterFuture;
  Timer? _homeMapInteractionDelayTimer;
  gmaps.LatLng? _homeMapCenter;
  bool _isIOSMenuOpen = false;
  String? _activePartnerDisplay;
  bool _hasQueuedAutomaticPartnerDisplays = false;
  bool _isShowingAutomaticPartnerDisplay = false;
  final List<String> _pendingAutomaticPartnerDisplays = [];
  bool _acceptedDefaultLocationFallback = false;
  bool _keepHomeMapInteractionBlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    homeViewModel.showMapLoadingIndicator
        .addListener(_handleHomeMapLoadingIndicatorChanged);
    _keyboardInsetNotifier.value = _currentKeyboardInset();
    _initialCenterFuture = _loadInitialCenter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handlePendingHomeDrawerDialog());
      unawaited(
        _requestStartupPermissions(),
      );
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final nextKeyboardInset = _currentKeyboardInset();
    if ((_keyboardInsetNotifier.value - nextKeyboardInset).abs() <= 0.5) {
      return;
    }
    _keyboardInsetNotifier.value = nextKeyboardInset;
  }

  double _currentKeyboardInset() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.first;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  void _handleHomeMapLoadingIndicatorChanged() {
    final isVisible = homeViewModel.showMapLoadingIndicator.value;
    _homeMapInteractionDelayTimer?.cancel();
    if (isVisible) {
      if (!_keepHomeMapInteractionBlocked && mounted) {
        setState(() {
          _keepHomeMapInteractionBlocked = true;
        });
      }
      return;
    }
    _homeMapInteractionDelayTimer = Timer(
      _homeMapDragUnlockDelay,
      () {
        if (!mounted) {
          return;
        }
        setState(() {
          _keepHomeMapInteractionBlocked = false;
        });
      },
    );
  }

  Future<void> _handlePendingHomeDrawerDialog() async {
    final pendingDialog = consumeHomeDrawerDialog();
    if (pendingDialog == null || !mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    if (isIOSLikeBrowser()) {
      setState(() {
        _isIOSMenuOpen = true;
      });
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    AlertService().showAppAlert(
      asset: AppLotties.success,
      title: pendingDialog.title,
      content: pendingDialog.content,
      confirmAction: () {
        Get.back();
      },
    );
  }

  Future<gmaps.LatLng?> _loadInitialCenter({
    bool forceLocationRequest = false,
  }) async {
    await homeViewModel.ensureInitialOngoingOrderLoaded();
    if (isIOSLikeBrowser()) {
      _homeMapCenter = defaultLatLng;
      return defaultLatLng;
    }
    if (homeViewModel.ongoingOrder != null) {
      _homeMapCenter = defaultLatLng;
      return defaultLatLng;
    }
    if (lastKnownRealLatLng != null && !forceLocationRequest) {
      return lastKnownRealLatLng;
    }
    if (lastGeolocationErrorMessage != null && !forceLocationRequest) {
      if (_acceptedDefaultLocationFallback) {
        _homeMapCenter = initLatLng ?? defaultLatLng;
        return _homeMapCenter;
      }
      return null;
    }
    final latLng = await getMyLatLng(
      forceFresh: true,
      requestPermission: false,
    );
    if (lastGeolocationErrorMessage != null &&
        !_acceptedDefaultLocationFallback) {
      if (AuthService.inReviewMode()) {
        _homeMapCenter = latLng ?? defaultLatLng;
        return _homeMapCenter;
      }
      return null;
    }
    return latLng;
  }

  Future<void> _requestStartupPermissions() async {
    await PushService.requestNotificationPermissionsIfNeeded();
    if (kIsWeb) {
      return;
    }
    final latLng = await getMyLatLng(
      forceFresh: true,
      requestPermission: true,
    );
    if (!mounted ||
        latLng == null ||
        homeViewModel.isResolvingInitialOngoingOrder ||
        homeViewModel.ongoingOrder != null) {
      return;
    }
    setState(() {
      _homeMapCenter = latLng;
      _initialCenterFuture = Future.value(latLng);
    });
  }

  void _retryInitialCenter() {
    setState(() {
      _acceptedDefaultLocationFallback = false;
      lastGeolocationErrorMessage = null;
      _initialCenterFuture = _loadInitialCenter(
        forceLocationRequest: true,
      );
    });
  }

  Future<void> _useDefaultInitialCenter() async {
    setState(() {
      _acceptedDefaultLocationFallback = true;
      _homeMapCenter = defaultLatLng;
      _initialCenterFuture = Future.value(defaultLatLng);
    });
    await homeViewModel.recenterHomeMap(
      fallbackTarget: defaultLatLng,
      allowSinglePointFit: true,
    );
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

  void _closeHomeDrawer() {
    _closeIOSMenu();
  }

  void _showPartnerDisplay(String partner) {
    setState(() {
      isAdSeen = true;
      isAd1Seen = true;
      if (partner == "mnb") {
        isAdSeen = false;
      } else if (partner == "sbb") {
        isAd1Seen = false;
      }
      showBranch = false;
      _activePartnerDisplay = partner;
    });
  }

  Future<void> _showPartnerDisplayWithBanners(String partner) async {
    _pendingAutomaticPartnerDisplays.clear();
    _isShowingAutomaticPartnerDisplay = false;
    if (gBanners.isEmpty) {
      await SplashViewModel().getBanners();
    }
    _showPartnerDisplay(partner);
  }

  Future<void> _queueAutomaticPartnerDisplaysIfNeeded(HomeViewModel vm) async {
    if (_hasQueuedAutomaticPartnerDisplays ||
        _activePartnerDisplay != null ||
        AuthService.inReviewMode() ||
        vm.ongoingOrder != null ||
        !isBool(AppStrings.homeSettingsObject?["show_ad"] ?? true)) {
      return;
    }

    _hasQueuedAutomaticPartnerDisplays = true;
    if (gBanners.isEmpty) {
      await SplashViewModel().getBanners();
    }
    if (!mounted || _activePartnerDisplay != null) {
      return;
    }

    _pendingAutomaticPartnerDisplays.clear();
    if (_hasValidBannerImages(
      _partnerBannersExcludingHosts([
        "mnb.com",
        "sbb.com",
      ]),
    )) {
      _pendingAutomaticPartnerDisplays.add("ppc");
    }
    _pendingAutomaticPartnerDisplays
      ..add("mnb")
      ..add("sbb");
    _showNextAutomaticPartnerDisplay();
  }

  bool _hasValidBannerImages(List<BannerModel> banners) {
    return banners.any((banner) {
      return sanitizeImageUrl(banner.photo).isNotEmpty;
    });
  }

  void _showNextAutomaticPartnerDisplay() {
    if (!mounted) {
      return;
    }
    if (_pendingAutomaticPartnerDisplays.isEmpty) {
      _isShowingAutomaticPartnerDisplay = false;
      return;
    }
    _isShowingAutomaticPartnerDisplay = true;
    _showPartnerDisplay(_pendingAutomaticPartnerDisplays.removeAt(0));
  }

  Future<void> _closePartnerDisplay({
    Future<void> Function()? beforeClose,
  }) async {
    await beforeClose?.call();
    if (!mounted) {
      return;
    }
    final nextAutomaticPartner = _isShowingAutomaticPartnerDisplay &&
            _pendingAutomaticPartnerDisplays.isNotEmpty
        ? _pendingAutomaticPartnerDisplays.removeAt(0)
        : null;
    setState(() {
      _activePartnerDisplay = nextAutomaticPartner;
      showBranch = false;
    });
    if (nextAutomaticPartner == null) {
      _isShowingAutomaticPartnerDisplay = false;
    }
  }

  void _clearPartnerDisplay() {
    _pendingAutomaticPartnerDisplays.clear();
    _isShowingAutomaticPartnerDisplay = false;
    setState(() {
      _activePartnerDisplay = null;
      showBranch = false;
    });
  }

  String _currentUserPhotoFileName() {
    final rawUrl = (AuthService.currentUser?.cPhoto ?? "").trim();
    if (rawUrl.isEmpty) {
      return "";
    }

    final uri = Uri.tryParse(rawUrl);
    return uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : rawUrl.split("/").last;
  }

  bool _isMobileNamedProfilePhoto() {
    return _currentUserPhotoFileName().toLowerCase().startsWith("mobile_");
  }

  bool _isPhpStyleProfilePhoto() {
    return _currentUserPhotoFileName().toLowerCase().startsWith("php");
  }

  bool _shouldUseTopHalfCurrentUserPhoto() {
    final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
    final shouldApplyPlatformRule = isMobile || kIsWeb;
    final isMobileNamedProfilePhoto = _isMobileNamedProfilePhoto();
    final isPhpStyleProfilePhoto = _isPhpStyleProfilePhoto();
    final createdAt = AuthService.currentUser?.createdAt;
    if (!shouldApplyPlatformRule) {
      return false;
    }

    if (isMobileNamedProfilePhoto) {
      return true;
    }

    if (createdAt == null) {
      return false;
    }

    final normalizedDate = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );
    final result = isPhpStyleProfilePhoto &&
        !normalizedDate.isBefore(_phpStyleProfilePhotoStartDate);
    return result;
  }

  double _currentUserTopHalfVisibleFraction() {
    final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
    return isMobile
        ? _currentUserTopHalfVisibleFractionMobile
        : _currentUserTopHalfVisibleFractionWeb;
  }

  Widget _buildCurrentUserDrawerAvatar() {
    if (_shouldUseTopHalfCurrentUserPhoto()) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final visibleFraction = _currentUserTopHalfVisibleFraction();
          final imageProvider = safeNetworkImageProvider(
            AuthService.currentUser?.cPhoto ?? "",
            cacheWidth: 600,
          );
          if (imageProvider == null) {
            return _buildHomeAvatarFallback();
          }
          return TopCroppedNetworkImage(
            imageProvider: imageProvider,
            visibleFraction: visibleFraction,
            loadingChild: _buildHomeAvatarLoading(),
            errorChild: _buildHomeAvatarFallback(),
          );
        },
      );
    }

    return NetworkImageWidget(
      fit: BoxFit.cover,
      memCacheWidth: 600,
      imageUrl: AuthService.currentUser?.cPhoto ?? "",
      progressIndicatorBuilder: (
        context,
        imageUrl,
        progress,
      ) {
        return _buildHomeAvatarLoading();
      },
      errorWidget: (context, imageUrl, progress) {
        return _buildHomeAvatarFallback();
      },
    );
  }

  String _driverImageUrlWithCacheBust(HomeViewModel vm) {
    final rawUrl = (vm.ongoingOrder?.driver?.cPhoto ?? "").trim();
    final driverId = vm.ongoingOrder?.driver?.id;
    if (rawUrl.isEmpty || driverId == null) {
      return rawUrl;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return rawUrl;
    }

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        "driver_id": "$driverId",
      },
    ).toString();
  }

  Widget _buildHomeAvatarLoading({
    Color backgroundColor = Colors.white,
  }) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeCap: StrokeCap.round,
              strokeWidth: 2,
              color: Color(0xFF007BFF),
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeAvatarFallback() {
    return const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF030744),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.person_outline_outlined,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeImageLoading({
    Color backgroundColor = Colors.white,
  }) {
    return SizedBox.expand(
      child: ColoredBox(
        color: backgroundColor,
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeCap: StrokeCap.round,
              strokeWidth: 2.5,
              color: Color(0xFF007BFF),
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeImageFallback() {
    return Container(
      color: const Color(0x14030744),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Color(0xFF030744),
        ),
      ),
    );
  }

  bool _hasAssignedDriver(HomeViewModel vm) => vm.ongoingOrder?.driver != null;

  Widget _buildDriverAvatar(HomeViewModel vm) {
    if (!_hasAssignedDriver(vm)) {
      return _buildHomeAvatarLoading();
    }

    return NetworkImageWidget(
      fit: BoxFit.cover,
      memCacheWidth: 600,
      imageUrl: _driverImageUrlWithCacheBust(vm),
      progressIndicatorBuilder: (
        context,
        imageUrl,
        progress,
      ) {
        return _buildHomeAvatarLoading();
      },
      errorWidget: (
        context,
        imageUrl,
        progress,
      ) {
        return _buildHomeAvatarFallback();
      },
    );
  }

  Widget _buildDriverPreviewImage(HomeViewModel vm) {
    if (!_hasAssignedDriver(vm)) {
      return _buildHomeImageLoading();
    }

    return NetworkImageWidget(
      imageUrl: _driverImageUrlWithCacheBust(vm),
      memCacheWidth: 600,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (
        context,
        imageUrl,
        progress,
      ) {
        return _buildHomeImageLoading();
      },
      errorWidget: (
        context,
        imageUrl,
        error,
      ) {
        return _buildHomeImageFallback();
      },
    );
  }

  bool _bannerMatchesHost(dynamic banner, String host) {
    final normalizedHost = host.toLowerCase();
    final link = (banner.link ?? "").trim().toLowerCase();
    final uri = Uri.tryParse(link);
    final linkHost = uri?.host.toLowerCase() ?? "";
    return link == normalizedHost ||
        link.startsWith("$normalizedHost/") ||
        link == "https://$normalizedHost" ||
        link.startsWith("https://$normalizedHost/") ||
        link == "http://$normalizedHost" ||
        link.startsWith("http://$normalizedHost/") ||
        linkHost == normalizedHost ||
        linkHost.endsWith(".$normalizedHost");
  }

  List<BannerModel> _partnerBannersForHost(String host) {
    return gBanners.where((banner) {
      return _bannerMatchesHost(banner, host);
    }).map((banner) {
      return BannerModel(
        photo: banner.photo ?? "",
        link: banner.link ?? "",
      );
    }).toList();
  }

  List<BannerModel> _partnerBannersExcludingHosts(List<String> hosts) {
    return gBanners.where((banner) {
      return !hosts.any((host) => _bannerMatchesHost(banner, host));
    }).map((banner) {
      return BannerModel(
        photo: banner.photo ?? "",
        link: banner.link ?? "",
      );
    }).toList();
  }

  Future<void> _openPartnerBannerLink(BannerModel banner) async {
    final rawLink = banner.link.trim();
    if (rawLink.isEmpty) {
      return;
    }

    final normalizedLink =
        rawLink.contains("://") ? rawLink : "https://$rawLink";
    final uri = Uri.tryParse(normalizedLink);
    if (uri == null) {
      return;
    }

    final host = uri.host.toLowerCase();
    if (host == "facebook.com" || host == "www.facebook.com") {
      final facebookAppUri = Uri.parse(
        "fb://facewebmodal/f?href=${Uri.encodeComponent(normalizedLink)}",
      );
      try {
        if (await canLaunchUrl(facebookAppUri) &&
            await launchUrl(
              facebookAppUri,
              mode: LaunchMode.externalApplication,
            )) {
          return;
        }
      } catch (_) {}
    }

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _openSupportChannel([HomeViewModel? vm]) async {
    final canRequestCancellation = vm != null &&
        vm.ongoingOrder != null &&
        !vm.isEnrouteOrBeyondStatus(vm.ongoingOrder?.status);
    await showFacebookSupportDialog(
      context,
      showRequestCancellation: canRequestCancellation,
      onRequestCancellation: !canRequestCancellation
          ? null
          : () async {
              await vm.sendQuickChatMessage(
                "Request cancellation",
                isRequestCancellation: true,
                openChatAfter: true,
              );
            },
    );
  }

  bool _canShowRequestCancellationPill(String? status) {
    final normalized = (status ?? "").trim().toLowerCase();
    return ![
      "enroute",
      "delivered",
      "completed",
      "successful",
      "cancelled",
    ].contains(normalized);
  }

  String? _homeRequestMessageType(String? message) {
    final normalized = (message ?? "").trim().toLowerCase();
    if (normalized == "request cancellation") {
      return "cancellation";
    }
    if (normalized == "request pass") {
      return "pass";
    }
    return null;
  }

  bool _shouldShowAcceptedCancelRequestActions(String? message) {
    final normalized = (message ?? "").trim().toLowerCase();
    return normalized.contains("has accepted") &&
        normalized.contains("cancel request");
  }

  Widget _buildHomeQuickChatPills(HomeViewModel vm) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userQuickChatDoc.snapshots(),
      builder: (context, snapshot) {
        final options = parseQuickChatOptions(snapshot.data?.data());
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: QuickChatPills(
            options: options,
            horizontalPadding: 20,
            showRequestCancellation: _canShowRequestCancellationPill(
                  vm.ongoingOrder?.status,
                ) &&
                !vm.hasAcceptedCancelRequest,
            onSelected: (option) async {
              await vm.sendQuickChatMessage(option);
            },
            onRequestCancellation: () async {
              await vm.sendQuickChatMessage(
                "Request cancellation",
                isRequestCancellation: true,
                openChatAfter: true,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHomeRequestCancellationActions(HomeViewModel vm) {
    return _buildHomeRequestActions(
      vm,
      requestType: "cancellation",
      color: Colors.red,
    );
  }

  Widget _buildHomeRequestPassActions(HomeViewModel vm) {
    return _buildHomeRequestActions(
      vm,
      requestType: "pass",
      color: const Color(0xFF007BFF),
    );
  }

  Widget _buildHomeAcceptedCancelRequestActions(HomeViewModel vm) {
    Widget buildPill({
      required String label,
      required Color color,
      required Future<void> Function() onTap,
    }) {
      return WidgetButton(
        onTap: () async => onTap(),
        mainColor: color.withValues(alpha: 0.08),
        interactionColor: color.withValues(alpha: 0.18),
        useDefaultHoverColor: false,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(1000)),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 0,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        height: 45,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 2,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return buildPill(
                label: "Cancel",
                color: Colors.red,
                onTap: () async {
                  vm.confirmAcceptedCancelRequestCancel();
                },
              );
            }
            return buildPill(
              label: "Get a new driver now!",
              color: const Color(0xFF007BFF),
              onTap: () async {
                vm.confirmAcceptedCancelRequestRebook();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHomeRequestActions(
    HomeViewModel vm, {
    required String requestType,
    required Color color,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          fbStore.collection("orders").doc(vm.ongoingOrder?.code).snapshots(),
      builder: (context, snapshot) {
        Widget buildPill({
          required String label,
          required Future<void> Function() onTap,
        }) {
          final isUpdating = requestType == "cancellation"
              ? vm.isUpdatingRequestCancellation
              : vm.isUpdatingRequestPass;
          return WidgetButton(
            onTap: isUpdating ? () {} : () async => onTap(),
            mainColor: color.withValues(alpha: 0.08),
            interactionColor: color.withValues(alpha: 0.18),
            useDefaultHoverColor: false,
            disableGestureDetection: isUpdating,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(1000)),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                  child: isUpdating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      : Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                        ),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: SizedBox(
            height: 45,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 2,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return buildPill(
                    label: "Reject",
                    onTap: () => requestType == "cancellation"
                        ? vm.updateRequestCancellationStatus("rejected")
                        : vm.updateRequestPassStatus("rejected"),
                  );
                }
                return buildPill(
                  label: "Accept",
                  onTap: () => requestType == "cancellation"
                      ? vm.updateRequestCancellationStatus("accepted")
                      : vm.updateRequestPassStatus("accepted"),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeDrawer(HomeViewModel vm, {bool useScaffoldDrawer = false}) {
    final mediaQuery = MediaQuery.of(context);
    final content = Container(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(top: mediaQuery.padding.top),
        child: Column(
          children: [
            WidgetButton(
              borderRadius: 0,
              suppressInteraction: true,
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
                  showSuccess("Copied to clipboard.");
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
                        child: _buildCurrentUserDrawerAvatar(),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !AuthService.isLoggedIn()
                                ? "Login account"
                                : capitalizeWords(
                                    "${AuthService.currentUser!.name}",
                                  ),
                            style: const TextStyle(
                              height: 1.05,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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
              ).withValues(alpha: 0.1),
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
                onTap: () async {
                  _closeIOSMenu();
                  final scaffoldState = _scaffoldKey.currentState;
                  if (!(isIOSLikeBrowser()) &&
                      (scaffoldState?.isDrawerOpen ?? false)) {
                    Navigator.of(context).pop();
                    await Future<void>.delayed(
                        const Duration(milliseconds: 16));
                  }
                  final selection = await _navigateWithoutTransition(
                    HistoryView(
                      vm,
                      onUseHistoryRoute: _closeHomeDrawer,
                    ),
                  );
                  await _syncHomeAfterHistoryRouteSelection(
                    vm,
                    selection,
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
                _openSupportChannel(homeViewModel);
              },
            ),
            if (AuthService.isLoggedIn() && !AuthService.inReviewMode())
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
            if (AuthService.isLoggedIn() && !AuthService.inReviewMode())
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: fbStore
                    .collection("access")
                    .doc("pwa_partners")
                    .snapshots(),
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
              onTap: () async {
                if (kIsWeb && AuthService.device() == "huawei") {
                  await refreshWebAppWithCacheBust();
                  return;
                }
                await launchUrl(
                  Uri.parse("https://ppctoda.com"),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
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

  Future<T?> _navigateWithoutTransition<T>(Widget page) {
    return Navigator.push<T>(
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
        ).withValues(alpha: 0.25),
      ),
    );
  }

  bool _sameLatLng(gmaps.LatLng? a, gmaps.LatLng? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.lat == b.lat && a.lng == b.lng;
  }

  Address? _cloneAddress(Address? address) {
    if (address == null) {
      return null;
    }
    return Address(
      addressLine: address.addressLine,
      countryName: address.countryName,
      countryCode: address.countryCode,
      featureName: address.featureName,
      postalCode: address.postalCode,
      adminArea: address.adminArea,
      subAdminArea: address.subAdminArea,
      locality: address.locality,
      subLocality: address.subLocality,
      thoroughfare: address.thoroughfare,
      subThoroughfare: address.subThoroughfare,
      gMapPlaceId: address.gMapPlaceId,
      coordinates: Coordinates(
        address.coordinates.latitude,
        address.coordinates.longitude,
      ),
    );
  }

  bool _isBookingSelectionFlow(HomeViewModel vm) {
    return vm.ongoingOrder == null || vm.ongoingOrder?.status == "cancelled";
  }

  Future<void> _syncHomeAfterMapSelection(
    HomeViewModel vm, {
    required bool isPickupFlow,
    Address? preservedPickup,
  }) async {
    if (!mounted) {
      return;
    }

    if (isPickupFlow) {
      vm.syncPickupDisplayFromAddress();
    } else if (preservedPickup != null) {
      pickupAddress = preservedPickup;
      vm.restorePickupDisplay();
    }

    setState(() {});

    if (!_isBookingSelectionFlow(vm) || pickupAddress == null) {
      return;
    }

    if (dropoffAddress != null) {
      await vm.previewSelectedRouteOnHome(
        pickup: pickupAddress!,
        dropoff: dropoffAddress!,
        animateMap: true,
      );
      return;
    }

    if (kIsWeb) {
      vm.cancelPendingCameraMove();
      vm.blockCamera = true;
      vm.syncPickupDisplayFromAddress();
      vm.ignoreCameraMovesFor(const Duration(milliseconds: 800));
      final currentZoom = vm.map?.zoom ?? 15;
      vm.zoomToLocation(
        pickupAddress!.latLng,
        zoom: currentZoom,
        animate: false,
      );
      vm.notifyListeners();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        vm.blockCamera = false;
        vm.notifyListeners();
      });
      return;
    }

    vm.blockCamera = true;
    vm.notifyListeners();
    vm.syncPickupDisplayFromAddress();
    vm.zoomToLocation(
      pickupAddress!.latLng,
      zoom: kIsWeb ? 15 : 16,
      animate: false,
    );
    await Future.delayed(
      kIsWeb
          ? const Duration(milliseconds: 80)
          : const Duration(milliseconds: 500),
    );
    vm.blockCamera = false;
    vm.notifyListeners();
  }

  Future<void> _syncHomeAfterHistoryRouteSelection(
    HomeViewModel vm,
    dynamic selection,
  ) async {
    if (!mounted || selection is! Map<String, dynamic>) {
      return;
    }

    final pickup = selection["pickup"];
    final dropoff = selection["dropoff"];
    if (pickup is! Address || dropoff is! Address) {
      return;
    }

    await vm.previewSelectedRouteOnHome(
      pickup: pickup,
      dropoff: dropoff,
      animateMap: true,
    );
  }

  String _locationErrorHint() {
    final error = lastGeolocationErrorMessage ?? "";
    if (error.contains("POSITION_UNAVAILABLE")) {
      return "Please enable device location, then try again. Or use the default location to continue right away.";
    }
    if (error.contains("TIMEOUT")) {
      return "Please try again. Or use the default location to continue right away.";
    }
    if (error.contains("PERMISSION_DENIED")) {
      return "Please allow location for this app, then try again. Or use the default location to continue right away.";
    }
    return "Please allow location for this app and enable device location, then try again. Or use the default location to continue right away.";
  }

  String _locationErrorTitle() {
    final error = lastGeolocationErrorMessage ?? "";
    if (error.contains("POSITION_UNAVAILABLE")) {
      return "Device Location Disabled";
    }
    if (error.contains("TIMEOUT")) {
      return "Location Took Too Long";
    }
    if (error.contains("PERMISSION_DENIED")) {
      return "App Location Blocked";
    }
    return "Location Required";
  }

  String _locationLoadingHint() {
    final error = lastGeolocationErrorMessage ?? "";
    if (error.contains("POSITION_UNAVAILABLE")) {
      return "Please keep device location enabled. Or use the default location to continue right away.";
    }
    return "Please wait. Or use the default location to continue right away.";
  }

  Widget _buildSelectionDialogOption({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return WidgetButton(
      borderRadius: 12,
      useDefaultHoverColor: false,
      mainColor: selected ? const Color(0xFFEFF6FF) : Colors.white,
      interactionColor: const Color(0xFF007BFF).withValues(alpha: 0.12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(
            Radius.circular(12),
          ),
          border: Border.all(
            color: selected ? const Color(0xFF007BFF) : const Color(0xFF030744),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  height: 1,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? const Color(0xFF007BFF)
                      : const Color(0xFF030744),
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color:
                  selected ? const Color(0xFF007BFF) : const Color(0xFF030744),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodDialog(HomeViewModel vm) {
    int selectedPaymentId = vm.paymentId;
    AlertService().showAppAlert(
      isCustom: true,
      customWidget: StatefulBuilder(
        builder: (context, dialogSetState) {
          final mediaQuery = MediaQuery.of(context);
          return Container(
            width: (mediaQuery.size.width - 70).clamp(0, 420),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(
                Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select Payment Method",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF030744),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSelectionDialogOption(
                    title: "Cash",
                    selected: selectedPaymentId == 1,
                    onTap: () {
                      dialogSetState(() {
                        selectedPaymentId = 1;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSelectionDialogOption(
                    title: "Load",
                    selected: selectedPaymentId == 8,
                    onTap: () {
                      dialogSetState(() {
                        selectedPaymentId = 8;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: WidgetButton(
                      borderRadius: 12,
                      mainColor: const Color(0xFF007BFF),
                      useDefaultHoverColor: false,
                      onTap: () {
                        vm.applyPaymentMethodSelection(selectedPaymentId);
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                      child: const Center(
                        child: Text(
                          "Apply",
                          style: TextStyle(
                            height: 1,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
    );
  }

  void _showPromoDialog(HomeViewModel vm) {
    bool isApplyingPromo = false;
    vm.promoCodeTEC.text = vm.appliedCoupon?.code ?? vm.promoCodeTEC.text;
    AlertService().showAppAlert(
      isCustom: true,
      customWidget: StatefulBuilder(
        builder: (context, dialogSetState) {
          final mediaQuery = MediaQuery.of(context);
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              top: 24,
              bottom: mediaQuery.viewInsets.bottom,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: Container(
                width: (mediaQuery.size.width - 70).clamp(0, 420),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Enter Promo Code",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF030744),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFieldWidget(
                        controller: vm.promoCodeTEC,
                        floatLabel: false,
                        hintText: "Promo Code",
                        labelText: "Promo Code",
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        obscureText: false,
                        showPrefix: false,
                        showSuffix: vm.appliedCoupon != null,
                        suffixIcon: Icons.close,
                        onChanged: (value) {
                          final upperValue = value.toUpperCase();
                          if (value == upperValue) {
                            return;
                          }
                          vm.promoCodeTEC.value = TextEditingValue(
                            text: upperValue,
                            selection: TextSelection.collapsed(
                              offset: upperValue.length,
                            ),
                          );
                        },
                        onSuffixTap: () {
                          dialogSetState(() {
                            vm.clearAppliedPromo();
                          });
                        },
                        autoFocus: true,
                        maxLines: 1,
                        minLines: 1,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: WidgetButton(
                          borderRadius: 12,
                          mainColor: vm.appliedCoupon != null
                              ? Colors.red
                              : isApplyingPromo
                                  ? const Color(0xFF007BFF)
                                      .withValues(alpha: 0.6)
                                  : const Color(0xFF007BFF),
                          useDefaultHoverColor: false,
                          onTap: () async {
                            if (isApplyingPromo) {
                              return;
                            }
                            FocusManager.instance.primaryFocus?.unfocus();
                            if (vm.appliedCoupon != null) {
                              dialogSetState(() {
                                vm.clearAppliedPromo();
                              });
                              return;
                            }
                            final promoCode = vm.promoCodeTEC.text;
                            dialogSetState(() {
                              isApplyingPromo = true;
                            });
                            try {
                              final resolvedPromo =
                                  await vm.resolvePromoCode(promoCode);
                              if (!mounted) {
                                return;
                              }
                              Get.back();
                              unawaited(Future<void>.delayed(
                                const Duration(milliseconds: 240),
                                () async {
                                  if (!mounted) {
                                    return;
                                  }
                                  vm.applyResolvedPromoCode(
                                    resolvedPromo.coupon,
                                    resolvedPromo.code,
                                  );
                                },
                              ));
                            } catch (e) {
                              dialogSetState(() {
                                isApplyingPromo = false;
                              });
                              ScaffoldMessenger.of(Get.context!)
                                  .clearSnackBars();
                              ScaffoldMessenger.of(Get.context!).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text(
                                    "$e",
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return;
                          },
                          child: Center(
                            child: Text(
                              vm.appliedCoupon != null ? "Remove" : "Apply",
                              style: const TextStyle(
                                height: 1,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _homeMapInteractionDelayTimer?.cancel();
    homeViewModel.showMapLoadingIndicator
        .removeListener(_handleHomeMapLoadingIndicatorChanged);
    WidgetsBinding.instance.removeObserver(this);
    _keyboardInsetNotifier.dispose();
    itemsIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HomeViewModel>.reactive(
      viewModelBuilder: () => homeViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        final mediaQuery = MediaQuery.of(context);
        vm.updateRouteBoundsTopInset(mediaQuery.padding.top);
        final isProvider = isBool(AuthService.currentUser?.isProvider);
        final ongoingDiscount = vm.ongoingOrder?.discount ?? 0;
        final ongoingMarkupAmount =
            (vm.order?["markup_amount"] as num?)?.toDouble() ?? 0;
        final double bookingCardSize =
            ((mediaQuery.size.width - 64) / 3).clamp(0, 120).toDouble();
        const bottomSheetBottomSpacing = 32.0;
        final ongoingSourceLabel = vm.ongoingOrder?.taxiOrder?.isWalkIn == true
            ? "Via Spot"
            : isProvider && ongoingMarkupAmount > 0
                ? "Via App | Guest"
                : isProvider && ongoingDiscount > 0
                    ? "Via App | Staff"
                    : "Via App";
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || vm.isResolvingInitialOngoingOrder) {
            return;
          }
          unawaited(_queueAutomaticPartnerDisplaysIfNeeded(vm));
        });
        return Scaffold(
          key: _scaffoldKey,
          resizeToAvoidBottomInset: false,
          drawer: isIOSLikeBrowser()
              ? null
              : _buildHomeDrawer(
                  vm,
                  useScaffoldDrawer: true,
                ),
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              FutureBuilder<gmaps.LatLng?>(
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
                            const SizedBox(
                              width: 100,
                              height: 100,
                              child: NetworkImageWidget(
                                imageUrl: AppImages.logo,
                                memCacheWidth: 600,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _locationErrorTitle(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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
                                color: const Color(0xFF030744)
                                    .withValues(alpha: 0.7),
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
                                  color: Color(0xFF007BFF),
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
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: 12,
                                        left: 12,
                                        right: 12,
                                        bottom: 14,
                                      ),
                                      child: NetworkImageWidget(
                                        imageUrl: AppImages.logo,
                                        memCacheWidth: 600,
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
                                        ).withValues(alpha: 0.25),
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
                                color: const Color(0xFF030744)
                                    .withValues(alpha: 0.7),
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
                                  color: Color(0xFF007BFF),
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
                  final hasActiveOngoingOrder = vm.ongoingOrder != null &&
                      vm.ongoingOrder?.status != "cancelled" &&
                      !vm.isCompletedReceiptStatus(vm.ongoingOrder?.status);
                  final hasBookingSelection =
                      pickupAddress != null || dropoffAddress != null;
                  if (currentCenter == null ||
                      (_sameLatLng(currentCenter, defaultLatLng) &&
                          !_sameLatLng(resolvedCenter, defaultLatLng))) {
                    _homeMapCenter = resolvedCenter;
                  }
                  final center = _homeMapCenter ?? resolvedCenter;
                  return SizedBox(
                    height: mediaQuery.size.height,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: RepaintBoundary(
                                child: Stack(
                                  children: [
                                    ValueListenableBuilder<bool>(
                                      valueListenable:
                                          vm.showMapLoadingIndicator,
                                      builder:
                                          (_, showMapLoadingIndicator, __) {
                                        final canInteractWithMap =
                                            !_keepHomeMapInteractionBlocked &&
                                                !showMapLoadingIndicator &&
                                                !vm.isMapInteractionLocked;
                                        return GoogleMapWidget(
                                          center: vm.mapCenter ?? center,
                                          enableGestures: !vm.isDisabled &&
                                              !vm.showAnalytics &&
                                              (hasActiveOngoingOrder ||
                                                  ((hasBookingSelection ||
                                                          _activePartnerDisplay ==
                                                              null) &&
                                                      canInteractWithMap)),
                                          markers: vm.markers,
                                          polylines: vm.polylines,
                                          onMapCreated: (map) {
                                            vm.setMap(map);
                                            WidgetsBinding.instance
                                                .addPostFrameCallback(
                                                    (_) async {
                                              if (!mounted ||
                                                  !AuthService.isLoggedIn()) {
                                                return;
                                              }
                                              await vm
                                                  .ensureInitialOngoingOrderLoaded();
                                              await vm
                                                  .loadUIByOngoingOrderStatus(
                                                forceStop: true,
                                                forceRedraw: true,
                                              );
                                              await LoadViewModel()
                                                  .getLoadBalance();
                                            });
                                          },
                                          onCameraMoveStart: () {
                                            try {
                                              final hasPickupAndDropoff =
                                                  pickupAddress != null &&
                                                      dropoffAddress != null;
                                              if (vm.ongoingOrder != null &&
                                                  vm.ongoingOrder?.status !=
                                                      "cancelled") {
                                                vm.setDraggingOngoingMap(true);
                                              }
                                              if (vm.ongoingOrder == null &&
                                                  !hasPickupAndDropoff &&
                                                  !vm.isIgnoringCameraMove &&
                                                  !vm.blockCamera &&
                                                  canInteractWithMap) {
                                                vm.beginCameraMove();
                                              }
                                            } catch (e) {
                                              // Ignore transient map callback races.
                                            }
                                          },
                                          onCameraMove: (center) {
                                            try {
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                              final a = vm.disposed;
                                              final hasPickupAndDropoff =
                                                  pickupAddress != null &&
                                                      dropoffAddress != null;
                                              if (vm.ongoingOrder != null &&
                                                  vm.ongoingOrder?.status !=
                                                      "cancelled") {
                                                return;
                                              }
                                              if (vm.ongoingOrder == null &&
                                                  !hasPickupAndDropoff) {
                                                if (!vm.blockCamera &&
                                                    canInteractWithMap &&
                                                    vm.shouldProcessCameraMove(
                                                      center,
                                                    )) {
                                                  if (!a) {
                                                    vm.mapCameraMove(
                                                      "onCameraMove",
                                                      center,
                                                    );
                                                  }
                                                }
                                              }
                                            } catch (e) {
                                              // Ignore transient map callback races.
                                            }
                                          },
                                        );
                                      },
                                    ),
                                    Positioned(
                                      top: mediaQuery.padding.top + 20,
                                      left: 20,
                                      child: FloatingButton(
                                        icon: Icons.menu,
                                        onTap: () {
                                          _toggleHomeMenu();
                                        },
                                      ),
                                    ),
                                    !isBool(
                                              AuthService
                                                  .currentUser?.isProvider,
                                            ) ||
                                            AuthService.inReviewMode()
                                        ? const SizedBox()
                                        : Positioned(
                                            top: mediaQuery.padding.top + 20,
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
                                      top: mediaQuery.padding.top + 20,
                                      right: 20,
                                      child: FloatingButton(
                                        icon: Icons.my_location_outlined,
                                        onTap: () async {
                                          final a = vm.disposed;
                                          if (!a) {
                                            await vm.recenterHomeMap(
                                              allowSinglePointFit:
                                                  _acceptedDefaultLocationFallback,
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
                                                await SplashViewModel()
                                                    .getBanners();
                                                if (vm.ongoingOrder == null) {
                                                  await LoadViewModel()
                                                      .getLoadBalance();
                                                  if (pickupAddress != null &&
                                                      dropoffAddress != null) {
                                                    final preservedPickup =
                                                        _cloneAddress(
                                                      pickupAddress,
                                                    );
                                                    final preservedDropoff =
                                                        _cloneAddress(
                                                      dropoffAddress,
                                                    );
                                                    if (preservedPickup !=
                                                            null &&
                                                        preservedDropoff !=
                                                            null) {
                                                      vm.clearGMapDetails();
                                                      await vm
                                                          .previewSelectedRouteOnHome(
                                                        pickup: preservedPickup,
                                                        dropoff:
                                                            preservedDropoff,
                                                        animateMap: true,
                                                      );
                                                    }
                                                  }
                                                }
                                                await vm.recenterHomeMap();
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
                                              final referralPhrase = AuthService
                                                      .isLoggedIn()
                                                  ? " using my referral code ${AuthService.currentUser?.code}"
                                                  : "";
                                              share(
                                                "Hey there, you can now book tricycles on the PPC TODA app$referralPhrase! Here's the download link:",
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
                                              final c =
                                                  vm.selectedAddress.value;
                                              await vm.zoomIn();
                                              if (!a &&
                                                  b.isEmpty &&
                                                  c == null &&
                                                  pickupAddress == null) {
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
                                              final c =
                                                  vm.selectedAddress.value;
                                              await vm.zoomOut();
                                              if (!a &&
                                                  b.isEmpty &&
                                                  c == null &&
                                                  pickupAddress == null) {
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
                                    AuthService.inReviewMode() ||
                                            vm.ongoingOrder != null ||
                                            !isBool(
                                              AppStrings.homeSettingsObject?[
                                                      "show_ad"] ??
                                                  true,
                                            )
                                        ? const SizedBox.shrink()
                                        : ValueListenableBuilder<bool>(
                                            valueListenable:
                                                vm.showPartnerButtons,
                                            builder:
                                                (_, showPartnerButtons, __) {
                                              final showPpcButton =
                                                  _partnerBannersExcludingHosts([
                                                "mnb.com",
                                                "sbb.com",
                                              ]).any((banner) {
                                                return sanitizeImageUrl(
                                                  banner.photo,
                                                ).isNotEmpty;
                                              });
                                              return Positioned(
                                                left: 0,
                                                right: 0,
                                                bottom: showPartnerButtons
                                                    ? 20
                                                    : -500,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    PartnerButtonWidget(
                                                      image: AppImages.mnb,
                                                      show: true,
                                                      onTap: () async {
                                                        await _showPartnerDisplayWithBanners(
                                                          "mnb",
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(
                                                      width: 12,
                                                    ),
                                                    if (showPpcButton)
                                                      PartnerButtonWidget(
                                                        image: AppImages.logo,
                                                        show: true,
                                                        borderColor:
                                                            const Color(
                                                          0xFF007BFF,
                                                        ),
                                                        borderWidth: 1,
                                                        onTap: () async {
                                                          await _showPartnerDisplayWithBanners(
                                                            "ppc",
                                                          );
                                                        },
                                                      ),
                                                    if (showPpcButton)
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                    PartnerButtonWidget(
                                                      image: AppImages.sbb,
                                                      show: true,
                                                      onTap: () async {
                                                        await _showPartnerDisplayWithBanners(
                                                          "sbb",
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                    ValueListenableBuilder<bool>(
                                      valueListenable:
                                          vm.showMapLoadingIndicator,
                                      builder:
                                          (_, showMapLoadingIndicator, __) {
                                        if (!showMapLoadingIndicator) {
                                          return const SizedBox.shrink();
                                        }
                                        return Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 20,
                                          child: IgnorePointer(
                                            child: Center(
                                              child: SizedBox(
                                                width: 45,
                                                height: 45,
                                                child: Center(
                                                  child:
                                                      _homeLoadingIndicator(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
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
                                              AuthService
                                                  .currentUser?.isProvider,
                                            )
                                        ? const SizedBox()
                                        : Positioned(
                                            top: mediaQuery.padding.top + 80,
                                            left: 16,
                                            right: 16,
                                            child: Center(
                                              child: Container(
                                                width:
                                                    (mediaQuery.size.width - 32)
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
                                                      ).withValues(alpha: 0.25),
                                                      blurRadius: 2,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: SingleChildScrollView(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
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
                                                                color: Colors
                                                                    .red
                                                                    .withValues(
                                                                  alpha: 0.08,
                                                                ),
                                                                borderRadius:
                                                                    const BorderRadius
                                                                        .all(
                                                                  Radius
                                                                      .circular(
                                                                    999,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: const Text(
                                                                "Locked",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 12),
                                                        Container(
                                                          width:
                                                              double.infinity,
                                                          height: 56,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                const BorderRadius
                                                                    .all(
                                                              Radius.circular(
                                                                  8),
                                                            ),
                                                            border: Border.all(
                                                              color:
                                                                  const Color(
                                                                0xFF030744,
                                                              ),
                                                            ),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              vm.providerDisplayPaymentMode ==
                                                                      "cash"
                                                                  ? "Cash: Pay Your Driver"
                                                                  : "Load: Auto Deduction",
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style:
                                                                  const TextStyle(
                                                                height: 1.05,
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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
                                                                  border: Border
                                                                      .all(
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
                                                                          "₱${vm.providerTodayAmount.toStringAsFixed(0)}",
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          style:
                                                                              const TextStyle(
                                                                            height:
                                                                                1.05,
                                                                            fontSize:
                                                                                15,
                                                                            fontWeight:
                                                                                FontWeight.bold,
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
                                                                                FontWeight.bold,
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
                                                                  border: Border
                                                                      .all(
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
                                                                          "₱${vm.providerMonthAmount.toStringAsFixed(0)}",
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          style:
                                                                              const TextStyle(
                                                                            height:
                                                                                1.05,
                                                                            fontSize:
                                                                                15,
                                                                            fontWeight:
                                                                                FontWeight.bold,
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
                                                                            DateTime.now(),
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
                                                                                FontWeight.bold,
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
                                                                  border: Border
                                                                      .all(
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
                                                                          "₱${vm.providerTotalAmount.toStringAsFixed(0)}",
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          style:
                                                                              const TextStyle(
                                                                            height:
                                                                                1.05,
                                                                            fontSize:
                                                                                15,
                                                                            fontWeight:
                                                                                FontWeight.bold,
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
                                                                                FontWeight.bold,
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
                                                                  border: Border
                                                                      .all(
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
                                                                          "₱${vm.providerMarkupAmount.toStringAsFixed(0)}",
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          style:
                                                                              const TextStyle(
                                                                            height:
                                                                                1.05,
                                                                            fontSize:
                                                                                15,
                                                                            fontWeight:
                                                                                FontWeight.bold,
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
                                                                                FontWeight.bold,
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
                                                        Center(
                                                          child: WidgetButton(
                                                            onTap: () async {
                                                              await showFacebookSupportDialog(
                                                                  context);
                                                            },
                                                            borderRadius: 6,
                                                            mainColor: Colors
                                                                .transparent,
                                                            isTransparentColor:
                                                                true,
                                                            useDefaultHoverColor:
                                                                false,
                                                            suppressInteraction:
                                                                true,
                                                            child: RichText(
                                                              text:
                                                                  const TextSpan(
                                                                children: [
                                                                  TextSpan(
                                                                    text:
                                                                        "Need help? ",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      color:
                                                                          Color(
                                                                        0xFF030744,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        "Contact",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        " or ",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      color:
                                                                          Color(
                                                                        0xFF030744,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        "Message",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        " us!",
                                                                    style:
                                                                        TextStyle(
                                                                      height:
                                                                          1.15,
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      color:
                                                                          Color(
                                                                        0xFF030744,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
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
                                ValueListenableBuilder<bool>(
                                  valueListenable: vm.showBottomUi,
                                  builder: (_, showBottomUi, __) {
                                    return RepaintBoundary(
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
                                                          vm.ongoingOrder ==
                                                              null
                                                      ? Column(
                                                          children: [
                                                            Divider(
                                                              height: 1,
                                                              thickness: 1,
                                                              color:
                                                                  const Color(
                                                                0xFF030744,
                                                              ).withValues(
                                                                      alpha:
                                                                          0.1),
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
                                                                width: double
                                                                    .infinity
                                                                    .clamp(
                                                                  0,
                                                                  800,
                                                                ),
                                                                height:
                                                                    bookingCardSize,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .red
                                                                      .shade50,
                                                                  borderRadius:
                                                                      const BorderRadius
                                                                          .all(
                                                                    Radius
                                                                        .circular(
                                                                      8,
                                                                    ),
                                                                  ),
                                                                ),
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                  ),
                                                                  child: Column(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Row(
                                                                        children: [
                                                                          const Icon(
                                                                            Icons.warning,
                                                                            color:
                                                                                Colors.red,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                8,
                                                                          ),
                                                                          Text(
                                                                            locUnavailable
                                                                                ? "Service location is not available"
                                                                                : "An error occurred. Please try again",
                                                                            maxLines:
                                                                                1,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                            style:
                                                                                const TextStyle(
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Color(
                                                                                0xFF030744,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            12,
                                                                      ),
                                                                      ActionButton(
                                                                        onTap:
                                                                            () {
                                                                          if (locUnavailable) {
                                                                            vm.resetUnavailableLocationState();
                                                                          } else {
                                                                            vm.closeOrder();
                                                                          }
                                                                        },
                                                                        height:
                                                                            bookingCardSize /
                                                                                3,
                                                                        mainColor:
                                                                            Colors.red,
                                                                        text: locUnavailable
                                                                            ? "Try another location"
                                                                            : "Retry",
                                                                        style:
                                                                            const TextStyle(
                                                                          height:
                                                                              1.05,
                                                                          color:
                                                                              Colors.white,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      : vm.ongoingOrder !=
                                                                  null &&
                                                              vm.ongoingOrder
                                                                      ?.status !=
                                                                  "cancelled"
                                                          ? SizedBox(
                                                              height:
                                                                  bookingCardSize +
                                                                      20,
                                                              child: Column(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        Container(
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: vm.ongoingOrder?.status !=
                                                                                "pending"
                                                                            ? vm.ongoingOrder?.status == "cancelled"
                                                                                ? Colors.red
                                                                                : Colors.green
                                                                            : const Color(
                                                                                0xFF007BFF,
                                                                              ),
                                                                      ),
                                                                      child:
                                                                          Row(
                                                                        children: [
                                                                          Expanded(
                                                                            child:
                                                                                Center(
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.symmetric(
                                                                                  horizontal: 20,
                                                                                ),
                                                                                child: ConstrainedBox(
                                                                                  constraints: const BoxConstraints(
                                                                                    maxWidth: 800,
                                                                                  ),
                                                                                  child: Text(
                                                                                    "#${vm.ongoingOrder!.id}  |  ${() {
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
                                                                                    textAlign: TextAlign.center,
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
                                                                          height:
                                                                              4,
                                                                          color: vm.ongoingOrder?.status == "cancelled"
                                                                              ? Colors.red.shade100
                                                                              : Colors.green.shade100,
                                                                        )
                                                                      : Container(
                                                                          height:
                                                                              4,
                                                                          color:
                                                                              const Color(
                                                                            0xFF007BFF,
                                                                          ).withValues(
                                                                            alpha:
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
                                                                                Container(
                                                                              height: 50,
                                                                              decoration: BoxDecoration(
                                                                                color: const Color(
                                                                                  0xFF007BFF,
                                                                                ).withValues(alpha: 0.1),
                                                                                borderRadius: const BorderRadius.all(
                                                                                  Radius.circular(
                                                                                    8,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              child: const Row(
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
                                                                                      fontWeight: FontWeight.bold,
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
                                                                                Row(
                                                                              children: [
                                                                                GestureDetector(
                                                                                  onTap: !_hasAssignedDriver(vm)
                                                                                      ? null
                                                                                      : () {
                                                                                          AlertService().showAppAlert(
                                                                                            isCustom: true,
                                                                                            customWidget: PinchZoom(
                                                                                              child: SizedBox(
                                                                                                height: mediaQuery.size.width - 70,
                                                                                                child: _buildDriverPreviewImage(vm),
                                                                                              ),
                                                                                            ),
                                                                                          );
                                                                                        },
                                                                                  child: ClipOval(
                                                                                    child: SizedBox(
                                                                                      width: 48,
                                                                                      height: 48,
                                                                                      child: _buildDriverAvatar(vm),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(
                                                                                  width: 12,
                                                                                ),
                                                                                Expanded(
                                                                                  child: Column(
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
                                                                                            fontWeight: FontWeight.bold,
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
                                                                                  width: 44,
                                                                                  height: 44,
                                                                                  child: WidgetButton(
                                                                                    onTap: () {
                                                                                      launchUrlString(
                                                                                        "tel:${vm.ongoingOrder?.driver?.phone}",
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
                                                                                  width: 12,
                                                                                ),
                                                                                SizedBox(
                                                                                  width: 44,
                                                                                  height: 44,
                                                                                  child: WidgetButton(
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
                                                                  color:
                                                                      const Color(
                                                                    0xFF030744,
                                                                  ).withValues(
                                                                          alpha:
                                                                              0.1),
                                                                ),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),
                                                                Padding(
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
                                                                        Column(
                                                                      children: [
                                                                        Builder(
                                                                          builder:
                                                                              (context) {
                                                                            final previewVehicle =
                                                                                gVehicleTypes.firstWhere(
                                                                              (v) => v.slug == "tricycle",
                                                                              orElse: () => gVehicleTypes.first,
                                                                            );
                                                                            final squareSize =
                                                                                bookingCardSize;
                                                                            final tricycleCard =
                                                                                SizedBox(
                                                                              width: squareSize,
                                                                              height: squareSize,
                                                                              child: ConstrainedBox(
                                                                                constraints: const BoxConstraints(
                                                                                  maxWidth: 200,
                                                                                ),
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
                                                                                          child: NetworkImageWidget(
                                                                                            imageUrl: "${AppImages.baseUrl}${lowerCase(previewVehicle.name!)}.png",
                                                                                            memCacheWidth: 600,
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
                                                                                          fontWeight: FontWeight.bold,
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
                                                                              ),
                                                                            );
                                                                            if (AuthService.inReviewMode()) {
                                                                              return Row(
                                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                                children: [
                                                                                  tricycleCard,
                                                                                  const SizedBox(
                                                                                    width: 15,
                                                                                  ),
                                                                                  const Expanded(
                                                                                    child: Text(
                                                                                      "Your tricycle ride\nis one book away",
                                                                                      style: TextStyle(
                                                                                        height: 1.15,
                                                                                        fontSize: 25,
                                                                                        color: Color(
                                                                                          0xFF007BFF,
                                                                                        ),
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              );
                                                                            }
                                                                            return Row(
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                                tricycleCard,
                                                                                const SizedBox(
                                                                                  width: 15,
                                                                                ),
                                                                                Expanded(
                                                                                  child: SizedBox(
                                                                                    height: squareSize,
                                                                                    child: Column(
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
                                                                                                      : vm.paymentMethodLabel,
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
                                                                                                        : const Color(
                                                                                                            0xFF007BFF,
                                                                                                          ),
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                            onTap: () async {
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
                                                                                                } else {
                                                                                                  _showPaymentMethodDialog(
                                                                                                    vm,
                                                                                                  );
                                                                                                }
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
                                                                                                      : vm.promoSelectionLabel,
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
                                                                                                        : const Color(
                                                                                                            0xFF007BFF,
                                                                                                          ),
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                            onTap: () async {
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
                                                                                                  AlertService().showLoading();
                                                                                                  try {
                                                                                                    await vm.applyProviderStaffPromoCode();
                                                                                                    AlertService().stopLoading(
                                                                                                      forceStop: true,
                                                                                                    );
                                                                                                  } catch (e) {
                                                                                                    AlertService().stopLoading(
                                                                                                      forceStop: true,
                                                                                                    );
                                                                                                    ScaffoldMessenger.of(
                                                                                                      Get.context!,
                                                                                                    ).clearSnackBars();
                                                                                                    ScaffoldMessenger.of(
                                                                                                      Get.context!,
                                                                                                    ).showSnackBar(
                                                                                                      SnackBar(
                                                                                                        backgroundColor: Colors.red,
                                                                                                        content: Text(
                                                                                                          "$e",
                                                                                                          style: const TextStyle(
                                                                                                            color: Colors.white,
                                                                                                          ),
                                                                                                        ),
                                                                                                      ),
                                                                                                    );
                                                                                                  }
                                                                                                } else {
                                                                                                  _showPromoDialog(
                                                                                                    vm,
                                                                                                  );
                                                                                                }
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
                                                                                  onTap: () {
                                                                                    if (!AuthService.isLoggedIn()) {
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
                                                                                  borderRadius: 8,
                                                                                  child: SizedBox(
                                                                                    width: squareSize,
                                                                                    height: squareSize,
                                                                                    child: ConstrainedBox(
                                                                                      constraints: const BoxConstraints(
                                                                                        maxWidth: 200,
                                                                                      ),
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
                                                                                        child: Column(
                                                                                          children: [
                                                                                            const SizedBox(
                                                                                              height: 12,
                                                                                            ),
                                                                                            const Expanded(
                                                                                              child: Padding(
                                                                                                padding: EdgeInsets.symmetric(
                                                                                                  horizontal: 8,
                                                                                                ),
                                                                                                child: NetworkImageWidget(
                                                                                                  imageUrl: AppImages.load,
                                                                                                  memCacheWidth: 600,
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
                                                                                                fontWeight: FontWeight.bold,
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
                                                                            );
                                                                          },
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 20,
                                                    ),
                                                    child: SizedBox(
                                                      width:
                                                          double.infinity.clamp(
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
                                                                      const MapView(
                                                                    isPickup:
                                                                        true,
                                                                  ),
                                                                ),
                                                              );
                                                              if (mounted &&
                                                                  rebuild ==
                                                                      true) {
                                                                await _syncHomeAfterMapSelection(
                                                                  vm,
                                                                  isPickupFlow:
                                                                      true,
                                                                );
                                                              }
                                                            }
                                                          }
                                                        },
                                                        child: Container(
                                                          height: 50,
                                                          decoration:
                                                              const BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .all(
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
                                                              ValueListenableBuilder<
                                                                  bool>(
                                                                valueListenable:
                                                                    vm.clearPickupDisplay,
                                                                builder: (_,
                                                                    clearPickupDisplay,
                                                                    __) {
                                                                  return ValueListenableBuilder<
                                                                      bool>(
                                                                    valueListenable:
                                                                        vm.showMapLoadingIndicator,
                                                                    builder: (_,
                                                                        showMapLoadingIndicator,
                                                                        __) {
                                                                      if (clearPickupDisplay &&
                                                                          !showMapLoadingIndicator) {
                                                                        return const Padding(
                                                                          padding:
                                                                              EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                4,
                                                                          ),
                                                                          child:
                                                                              SizedBox(
                                                                            width:
                                                                                16,
                                                                            height:
                                                                                16,
                                                                            child:
                                                                                CircularProgressIndicator(
                                                                              strokeCap: StrokeCap.round,
                                                                              color: Color(
                                                                                0xFF007BFF,
                                                                              ),
                                                                              backgroundColor: Color(
                                                                                0x40007BFF,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }
                                                                      return const Icon(
                                                                        Icons
                                                                            .trip_origin,
                                                                        color:
                                                                            Color(
                                                                          0xFF007BFF,
                                                                        ),
                                                                      );
                                                                    },
                                                                  );
                                                                },
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    ValueListenableBuilder<
                                                                        bool>(
                                                                  valueListenable:
                                                                      vm.clearPickupDisplay,
                                                                  builder: (_,
                                                                      clearPickupDisplay,
                                                                      __) {
                                                                    final address =
                                                                        clearPickupDisplay
                                                                            ? null
                                                                            : pickupAddress;
                                                                    return Text(
                                                                      capitalizeWords(
                                                                        address
                                                                            ?.addressLine,
                                                                        alt:
                                                                            "Where from?",
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      style:
                                                                          const TextStyle(
                                                                        color:
                                                                            Color(
                                                                          0xFF030744,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
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
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 20,
                                                    ),
                                                    child: SizedBox(
                                                      height: vm.ongoingOrder !=
                                                              null
                                                          ? 30
                                                          : null,
                                                      width:
                                                          double.infinity.clamp(
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
                                                            if (vm.ongoingOrder ==
                                                                    null ||
                                                                vm.ongoingOrder
                                                                        ?.status ==
                                                                    "cancelled") {
                                                              final preservedPickup =
                                                                  _cloneAddress(
                                                                pickupAddress,
                                                              );
                                                              var rebuild =
                                                                  await Navigator
                                                                      .push(
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
                                                                      const MapView(
                                                                    isPickup:
                                                                        false,
                                                                  ),
                                                                ),
                                                              );
                                                              if (mounted &&
                                                                  rebuild ==
                                                                      true) {
                                                                await _syncHomeAfterMapSelection(
                                                                  vm,
                                                                  isPickupFlow:
                                                                      false,
                                                                  preservedPickup:
                                                                      preservedPickup,
                                                                );
                                                              }
                                                            }
                                                          }
                                                        },
                                                        borderRadius: 8,
                                                        useDefaultHoverColor:
                                                            false,
                                                        disableGestureDetection:
                                                            vm.ongoingOrder !=
                                                                null,
                                                        mainColor:
                                                            vm.ongoingOrder !=
                                                                    null
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xFFEAF1FE),
                                                        child: SizedBox(
                                                          height: 50,
                                                          child: Row(
                                                            children: [
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              const Icon(
                                                                Icons
                                                                    .trip_origin,
                                                                color:
                                                                    Colors.red,
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
                                                                    color:
                                                                        Color(
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
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 20,
                                                    ),
                                                    child: SizedBox(
                                                      width:
                                                          double.infinity.clamp(
                                                        0,
                                                        800,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          SizedBox(
                                                            width:
                                                                bookingCardSize,
                                                            child:
                                                                ConstrainedBox(
                                                              constraints:
                                                                  const BoxConstraints(
                                                                maxWidth: 200,
                                                              ),
                                                              child: Container(
                                                                height: 50,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  borderRadius:
                                                                      const BorderRadius
                                                                          .all(
                                                                    Radius
                                                                        .circular(
                                                                      8,
                                                                    ),
                                                                  ),
                                                                  border: Border
                                                                      .all(
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
                                                                            vm.ongoingOrder!.status !=
                                                                                "cancelled"
                                                                        ? () {
                                                                            if (vm.ongoingOrder?.status ==
                                                                                "pending") {
                                                                              return "Waiting";
                                                                            } else if (vm.ongoingOrder?.status ==
                                                                                "preparing") {
                                                                              final eta = (vm.ongoingOrder?.taxiOrder?.tripDetails?.eta ?? "").trim();
                                                                              if (eta.isEmpty || eta.toLowerCase() == "null") {
                                                                                return "Connecting";
                                                                              }
                                                                              if (eta.toLowerCase().contains("any") || eta.toLowerCase().contains("unknown")) {
                                                                                return "Any Second";
                                                                              }
                                                                              return capitalizeWords(
                                                                                formatEtaText(eta),
                                                                              );
                                                                            } else {
                                                                              return travelTime(
                                                                                vm.ongoingOrder!.taxiOrder?.tripDetails?.kmDistance ?? 0,
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
                                                                      color:
                                                                          Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 15),
                                                          Expanded(
                                                            child: ActionButton(
                                                              text: (() {
                                                                final order = vm
                                                                    .ongoingOrder;
                                                                if (vm
                                                                    .isOngoingOrderStatusUncertain) {
                                                                  return "CANCEL";
                                                                }
                                                                final status =
                                                                    (order?.status ??
                                                                            "")
                                                                        .trim()
                                                                        .toLowerCase();
                                                                if (order ==
                                                                        null ||
                                                                    status ==
                                                                        "cancelled") {
                                                                  return "BOOK";
                                                                } else if (status ==
                                                                    "enroute") {
                                                                  return "CANCEL";
                                                                } else if (vm
                                                                    .canOpenCancelFlow) {
                                                                  return "CANCEL";
                                                                } else if (status ==
                                                                        "pending" ||
                                                                    status ==
                                                                        "enroute" ||
                                                                    status ==
                                                                        "preparing" ||
                                                                    status ==
                                                                        "delivered") {
                                                                  return "CANCEL";
                                                                }
                                                                return "CANCEL";
                                                              })(),
                                                              mainColor: vm
                                                                      .isPreparing
                                                                  ? const Color(
                                                                      0xFF030744,
                                                                    ).withValues(
                                                                      alpha:
                                                                          0.2)
                                                                  : vm.ongoingOrder ==
                                                                              null ||
                                                                          vm.ongoingOrder!.status ==
                                                                              "cancelled"
                                                                      ? const Color(
                                                                          0xFF007BFF,
                                                                        )
                                                                      : vm.isOngoingOrderStatusUncertain
                                                                          ? const Color(
                                                                              0xFF007BFF,
                                                                            ).withValues(
                                                                              alpha: 0.1,
                                                                            )
                                                                          : vm.canOpenCancelFlow
                                                                              ? Colors.red.shade100
                                                                              : const Color(
                                                                                  0xFF007BFF,
                                                                                ).withValues(
                                                                                  alpha: 0.1,
                                                                                ),
                                                              onTap: () async {
                                                                if (!AuthService
                                                                    .isLoggedIn()) {
                                                                  Navigator
                                                                      .push(
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
                                                                  if (vm
                                                                      .isOngoingOrderStatusUncertain) {
                                                                    _openSupportChannel(
                                                                        vm);
                                                                    return;
                                                                  }
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
                                                                            Colors.green,
                                                                        content:
                                                                            Text(
                                                                          "Finalizing your details, please wait ...",
                                                                          style:
                                                                              TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  } else if (vm
                                                                          .ongoingOrder ==
                                                                      null) {
                                                                    if (!vm.busy(
                                                                        vm.vehicleTypes)) {
                                                                      vm.processNewOrder();
                                                                    }
                                                                  } else if (vm
                                                                          .ongoingOrder
                                                                          ?.status ==
                                                                      "enroute") {
                                                                    _openSupportChannel(
                                                                        vm);
                                                                  } else if (vm
                                                                      .canOpenCancelFlow) {
                                                                    vm.cancelOrder();
                                                                  } else {
                                                                    final status = (vm.ongoingOrder?.status ??
                                                                            "")
                                                                        .trim()
                                                                        .toLowerCase();
                                                                    if (status == "pending" ||
                                                                        status ==
                                                                            "enroute" ||
                                                                        status ==
                                                                            "preparing" ||
                                                                        status ==
                                                                            "delivered" ||
                                                                        status
                                                                            .isEmpty) {
                                                                      _openSupportChannel(
                                                                          vm);
                                                                    } else {
                                                                      _openSupportChannel(
                                                                          vm);
                                                                    }
                                                                  }
                                                                }
                                                              },
                                                              style: TextStyle(
                                                                height: 1.05,
                                                                fontSize: vm.ongoingOrder !=
                                                                            null &&
                                                                        vm.ongoingOrder!.status !=
                                                                            "cancelled"
                                                                    ? null
                                                                    : 16.0,
                                                                color: vm.ongoingOrder ==
                                                                            null ||
                                                                        vm.ongoingOrder!.status ==
                                                                            "cancelled"
                                                                    ? Colors
                                                                        .white
                                                                    : vm.isOngoingOrderStatusUncertain
                                                                        ? const Color(
                                                                            0xFF007BFF,
                                                                          )
                                                                        : vm.canOpenCancelFlow
                                                                            ? Colors.red
                                                                            : const Color(
                                                                                0xFF007BFF,
                                                                              ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 15),
                                                          SizedBox(
                                                            width:
                                                                bookingCardSize,
                                                            child:
                                                                ConstrainedBox(
                                                              constraints:
                                                                  const BoxConstraints(
                                                                maxWidth: 200,
                                                              ),
                                                              child: Container(
                                                                height: 50,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  borderRadius:
                                                                      const BorderRadius
                                                                          .all(
                                                                    Radius
                                                                        .circular(
                                                                      8,
                                                                    ),
                                                                  ),
                                                                  border: Border
                                                                      .all(
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
                                                                            vm.ongoingOrder!.status !=
                                                                                "cancelled"
                                                                        ? AuthService.inReviewMode()
                                                                            ? vm.isPreparing
                                                                                ? "•••"
                                                                                : "${vm.ongoingOrder!.taxiOrder?.tripDetails?.kmDistance?.toStringAsFixed(0)} km"
                                                                            : vm.isPreparing
                                                                                ? "•••"
                                                                                : "${isBool(AuthService.currentUser?.isProvider) ? "₱" : ""}${vm.displayedPendingDriverOngoingOrderFare.toStringAsFixed(0)}${" "}${vm.ongoingOrder!.paymentMethodId == 1 ? "Cash" : "Load"}"
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
                                                                                    : "${vm.selectedVehicle?.kmDistance?.toStringAsFixed(0)} km"
                                                                                : vm.isPreparing
                                                                                    ? "•••"
                                                                                    : "${isBool(AuthService.currentUser?.isProvider) ? "₱" : ""}${vm.total?.toStringAsFixed(0)}${" "}${vm.paymentId == 1 ? "Cash" : "Load"}",
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style:
                                                                        const TextStyle(
                                                                      color:
                                                                          Color(
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
                                                    height:
                                                        bottomSheetBottomSpacing,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    );
                                  },
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
                                      color:
                                          Colors.black.withValues(alpha: 0.18),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: mediaQuery.size.width * 0.84 > 320
                                        ? 320
                                        : mediaQuery.size.width * 0.84,
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
                        vm.ongoingOrder == null ||
                                vm.ongoingOrder?.status == "cancelled"
                            ? const SizedBox.shrink()
                            : !vm.isCompletedReceiptStatus(vm.lastStatus) ||
                                    !vm.isCompletedReceiptStatus(
                                      vm.ongoingOrder?.status,
                                    )
                                ? const SizedBox.shrink()
                                : bookingId != vm.ongoingOrder?.id
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
                                                  child: SingleChildScrollView(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const SizedBox(
                                                          height: 20,
                                                        ),
                                                        GestureDetector(
                                                          onTap:
                                                              !_hasAssignedDriver(
                                                                      vm)
                                                                  ? null
                                                                  : () {
                                                                      AlertService()
                                                                          .showAppAlert(
                                                                        isCustom:
                                                                            true,
                                                                        customWidget:
                                                                            PinchZoom(
                                                                          child:
                                                                              SizedBox(
                                                                            height:
                                                                                mediaQuery.size.width - 70,
                                                                            child:
                                                                                _buildDriverPreviewImage(
                                                                              vm,
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
                                                                  _buildDriverAvatar(
                                                                vm,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        Text(
                                                          capitalizeWords(
                                                            vm.ongoingOrder
                                                                ?.driver?.name,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                            height: 1.15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                              0xFF030744,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          capitalizeWords(
                                                            "${vm.ongoingOrder?.driver?.vehicle?.vehicleInfo}${vm.ongoingOrder?.driver?.franchiseNumber == null ? "" : "\n${vm.ongoingOrder?.driver?.franchiseNumber}"}${vm.ongoingOrder?.driver?.licenseNumber == null ? "" : " | ${vm.ongoingOrder?.driver?.licenseNumber}"}",
                                                            alt: "Driver Info",
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                            height: 1.15,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w400,
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
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  const BorderRadius
                                                                      .all(
                                                                Radius.circular(
                                                                  12,
                                                                ),
                                                              ),
                                                              border:
                                                                  Border.all(
                                                                width: 1,
                                                                color:
                                                                    const Color(
                                                                  0xFF030744,
                                                                ).withValues(
                                                                  alpha: 0.15,
                                                                ),
                                                              ),
                                                            ),
                                                            child: Column(
                                                              children: [
                                                                const SizedBox(
                                                                    height: 16),
                                                                Container(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: () {
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
                                                                      } else if (vm
                                                                          .isCompletedReceiptStatus(
                                                                        status,
                                                                      )) {
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
                                                                      Radius
                                                                          .circular(
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
                                                                    child: Text(
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
                                                                          return "Ongoing";
                                                                        } else if (status ==
                                                                            "failed") {
                                                                          return "Failed";
                                                                        } else if (status ==
                                                                            "cancelled") {
                                                                          return "Cancelled";
                                                                        } else if (vm
                                                                            .isCompletedReceiptStatus(
                                                                          status,
                                                                        )) {
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
                                                                          final status = vm
                                                                              .ongoingOrder
                                                                              ?.status;
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
                                                                          } else if (vm
                                                                              .isCompletedReceiptStatus(
                                                                            status,
                                                                          )) {
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
                                                                  "#${vm.ongoingOrder?.id}",
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
                                                                    height: 16),
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
                                                                    ).withValues(
                                                                      alpha:
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
                                                                      width: 12,
                                                                    ),
                                                                    const ClipOval(
                                                                      child:
                                                                          SizedBox(
                                                                        width:
                                                                            28,
                                                                        height:
                                                                            28,
                                                                        child:
                                                                            NetworkImageWidget(
                                                                          imageUrl:
                                                                              AppImages.logo,
                                                                          memCacheWidth:
                                                                              600,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            6),
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        "${capitalizeWords(
                                                                          vm
                                                                              .ongoingOrder
                                                                              ?.driver
                                                                              ?.vehicle
                                                                              ?.vehicleType
                                                                              ?.name,
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
                                                                    Text(
                                                                      ongoingSourceLabel,
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
                                                                    const SizedBox(
                                                                      width: 14,
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
                                                                    ).withValues(
                                                                      alpha:
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
                                                                      width: 14,
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
                                                                      width: 8,
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        capitalizeWords(
                                                                          vm.ongoingOrder?.taxiOrder
                                                                              ?.pickupAddress,
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
                                                                      width: 12,
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 14,
                                                                    ),
                                                                    const Icon(
                                                                      Icons
                                                                          .trip_origin,
                                                                      color: Colors
                                                                          .red,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        capitalizeWords(
                                                                          vm.ongoingOrder?.taxiOrder
                                                                              ?.dropoffAddress,
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
                                                                      width: 12,
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
                                                                    ).withValues(
                                                                      alpha:
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
                                                                      width: 14,
                                                                    ),
                                                                    Padding(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .all(
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
                                                                            color:
                                                                                Colors.green,
                                                                            width:
                                                                                2,
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
                                                                            style:
                                                                                TextStyle(
                                                                              height: 1,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.green,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
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
                                                                      "₱${vm.displayedPendingDriverOngoingOrderFare.toStringAsFixed(0)}",
                                                                      style:
                                                                          const TextStyle(
                                                                        color:
                                                                            Color(
                                                                          0xFF030744,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 12,
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 14,
                                                                    ),
                                                                    const Icon(
                                                                      Icons
                                                                          .credit_score_outlined,
                                                                      color: Colors
                                                                          .green,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
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
                                                                            Color(
                                                                          0xFF030744,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 14,
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
                                                            ).withValues(
                                                              alpha: 0.1,
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
                                      ),
                        isBool(vm.userSeen) ||
                                vm.dvrMessage == null ||
                                vm.dvrMessage == "null" ||
                                vm.ongoingOrder == null ||
                                vm.ongoingOrder?.status == "cancelled" ||
                                vm.dvrMessage == "null" ||
                                vm.dvrMessage == ""
                            ? const SizedBox.shrink()
                            : IgnorePointer(
                                child: Container(
                                  color: Colors.black.withValues(
                                    alpha: 0.5,
                                  ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: !_hasAssignedDriver(vm)
                                                  ? null
                                                  : () {
                                                      AlertService()
                                                          .showAppAlert(
                                                        isCustom: true,
                                                        customWidget: PinchZoom(
                                                          child: SizedBox(
                                                            height: mediaQuery
                                                                    .size
                                                                    .width -
                                                                70,
                                                            child:
                                                                _buildDriverPreviewImage(
                                                              vm,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              child: ClipOval(
                                                child: SizedBox(
                                                  width: 50,
                                                  height: 50,
                                                  child: _buildDriverAvatar(vm),
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: Color(
                                                        0xFF030744,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: WidgetButton(
                                                borderRadius: 8,
                                                mainColor:
                                                    const Color(0xFF007BFF),
                                                useDefaultHoverColor: false,
                                                onTap: () {
                                                  launchUrlString(
                                                    "tel:${vm.ongoingOrder?.driver?.phone}",
                                                  );
                                                },
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.phone,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(
                                        color: const Color(
                                          0xFF030744,
                                        ).withValues(
                                          alpha: 0.15,
                                        ),
                                        thickness: 1,
                                        height: 1,
                                      ),
                                      isPhotoUrlMessage(vm.dvrMessage)
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Text(
                                                "Message: ${vm.dvrMessage}",
                                              ),
                                            ),
                                      !isPhotoUrlMessage(vm.dvrMessage)
                                          ? const SizedBox()
                                          : GestureDetector(
                                              onTap: () {
                                                AlertService().showAppAlert(
                                                  isCustom: true,
                                                  customWidget: PinchZoom(
                                                    child: NetworkImageWidget(
                                                      imageUrl:
                                                          "${vm.dvrMessage}",
                                                      memCacheWidth: 600,
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
                                                  width: mediaQuery.size.width,
                                                  height: mediaQuery.size.width,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(
                                                      0xFF007BFF,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.all(
                                                      Radius.circular(10),
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        const BorderRadius.all(
                                                      Radius.circular(10),
                                                    ),
                                                    child: NetworkImageWidget(
                                                      imageUrl:
                                                          "${vm.dvrMessage}",
                                                      memCacheWidth: 600,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                      Builder(
                                        builder: (_) {
                                          final requestMessageType =
                                              _homeRequestMessageType(
                                            vm.dvrMessage,
                                          );
                                          if (isPhotoUrlMessage(
                                              vm.dvrMessage)) {
                                            return const SizedBox.shrink();
                                          }
                                          if (requestMessageType ==
                                              "cancellation") {
                                            return _buildHomeRequestCancellationActions(
                                              vm,
                                            );
                                          }
                                          if (_shouldShowAcceptedCancelRequestActions(
                                            vm.dvrMessage,
                                          )) {
                                            return _buildHomeAcceptedCancelRequestActions(
                                              vm,
                                            );
                                          }
                                          if (requestMessageType == "pass") {
                                            return _buildHomeRequestPassActions(
                                              vm,
                                            );
                                          }
                                          return _buildHomeQuickChatPills(vm);
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 20,
                                          right: 20,
                                          bottom: bottomSheetBottomSpacing,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 55,
                                                child: WidgetButton(
                                                  borderRadius: 10,
                                                  mainColor: Colors.red,
                                                  useDefaultHoverColor: false,
                                                  onTap: () {
                                                    fbStore
                                                        .collection("orders")
                                                        .doc(vm
                                                            .ongoingOrder?.code)
                                                        .update(
                                                      {
                                                        "userSeen": true,
                                                      },
                                                    );
                                                    vm.userSeen = true;
                                                    vm.notifyListeners();
                                                  },
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
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
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
                                                  borderRadius: 10,
                                                  mainColor: const Color(
                                                    0xFF007BFF,
                                                  ),
                                                  useDefaultHoverColor: false,
                                                  onTap: () {
                                                    vm.chatDriver();
                                                  },
                                                  child: Center(
                                                    child: vm.isBusy
                                                        ? const SizedBox(
                                                            width: 28,
                                                            height: 28,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2.5,
                                                              color:
                                                                  Colors.white,
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
                                                                  fontSize: 16,
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
                        () {
                          try {
                            final showPpc = _activePartnerDisplay == "ppc";
                            return PartnerDisplayWidget(
                              show: showPpc,
                              onClose: () {
                                unawaited(_closePartnerDisplay());
                              },
                              isLoggedIn: () => AuthService.isLoggedIn(),
                              onSelectDropoff: (
                                latLng,
                                branchName,
                              ) {},
                              banners: _partnerBannersExcludingHosts([
                                "mnb.com",
                                "sbb.com",
                              ]),
                              partnerName: "PPC TODA",
                              partnerDescription: "Tap an image to open link",
                              partnerImage: AppImages.logo,
                              branches: const [],
                              onBannerTap: _openPartnerBannerLink,
                            );
                          } catch (_) {
                            return const SizedBox();
                          }
                        }(),
                        () {
                          try {
                            final showMnb = _activePartnerDisplay == "mnb";
                            return PartnerDisplayWidget(
                              show: showMnb,
                              onClose: () async {
                                await _closePartnerDisplay(
                                  beforeClose: () async {
                                    await StorageService.prefs?.setBool(
                                      "is_ad_seen",
                                      true,
                                    );
                                    isAdSeen = true;
                                  },
                                );
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
                                _clearPartnerDisplay();
                              },
                              banners: _partnerBannersForHost("mnb.com"),
                              partnerName: "Max & Bunny",
                              partnerDescription:
                                  "Dine in and help a driver earn!",
                              partnerImage: AppImages.mnb,
                              branches: [
                                Branch(
                                  id: 1,
                                  name: "San Pedro Branch",
                                  latLng: const gmaps.LatLng(
                                    9.762115888944837,
                                    118.75241723828879,
                                  ),
                                ),
                                Branch(
                                  id: 2,
                                  name: "SM Branch",
                                  latLng: const gmaps.LatLng(
                                    9.743318345512021,
                                    118.7390989745996,
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
                            final showSbb = _activePartnerDisplay == "sbb";
                            return PartnerDisplayWidget(
                              show: showSbb,
                              onClose: () async {
                                await _closePartnerDisplay(
                                  beforeClose: () async {
                                    await StorageService.prefs
                                        ?.setBool("is_ad_1_seen", true);
                                    isAd1Seen = true;
                                  },
                                );
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
                                _clearPartnerDisplay();
                              },
                              banners: _partnerBannersForHost("sbb.com"),
                              partnerName: "Sabie Bakes",
                              partnerDescription:
                                  "Dine in and help a driver earn!",
                              partnerImage: AppImages.sbb,
                              branches: [
                                Branch(
                                  id: 1,
                                  name: "BM Road Branch",
                                  latLng: const gmaps.LatLng(
                                    9.765574270055104,
                                    118.76115291309709,
                                  ),
                                ),
                                Branch(
                                  id: 2,
                                  name: "SM Branch",
                                  latLng: const gmaps.LatLng(
                                    9.74394439548003,
                                    118.7398234327833,
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
                  );
                },
              ),
              if (AuthService.shouldUpgrade() &&
                  !AuthService.isUpgradeDismissed())
                const UpgradeWidget(),
            ],
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
              ).withValues(alpha: 0.25),
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
