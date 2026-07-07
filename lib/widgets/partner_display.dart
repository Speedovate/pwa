import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/utils/functions.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/network_image.widget.dart';

class PartnerDisplayWidget extends StatefulWidget {
  final bool show;
  final VoidCallback onClose;
  final ValueChanged<bool>? onPressChanged;
  final bool Function() isLoggedIn;
  final void Function(gmaps.LatLng dropoff, String branchName) onSelectDropoff;
  final List<BannerModel> banners;
  final String partnerName;
  final String partnerDescription;
  final String partnerImage;
  final List<Branch> branches;
  final Future<void> Function(BannerModel banner)? onBannerTap;

  const PartnerDisplayWidget({
    super.key,
    required this.show,
    required this.onClose,
    this.onPressChanged,
    required this.isLoggedIn,
    required this.onSelectDropoff,
    required this.banners,
    required this.partnerName,
    required this.partnerDescription,
    required this.partnerImage,
    required this.branches,
    this.onBannerTap,
  });

  @override
  State<PartnerDisplayWidget> createState() => _PartnerDisplayWidgetState();
}

class _PartnerDisplayWidgetState extends State<PartnerDisplayWidget> {
  bool showBranch = false;
  int selectedBranch = 1;
  int bannerIndex = 0;

  static const Color primaryColor = Color(0xFF030744);
  static const Color accentColor = Color(0xFF007BFF);

  @override
  void initState() {
    super.initState();
    selectedBranch = _defaultBranchId;
  }

  @override
  void didUpdateWidget(covariant PartnerDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedBranchExists = widget.branches.any((branch) {
      return branch.id == selectedBranch;
    });
    if ((widget.show && !oldWidget.show) || !selectedBranchExists) {
      selectedBranch = _defaultBranchId;
    }
  }

  int get _defaultBranchId {
    if (widget.branches.any((branch) => branch.id == 1)) {
      return 1;
    }
    return widget.branches.isEmpty ? 0 : widget.branches.first.id;
  }

  void _resetDisplayState() {
    showBranch = false;
    selectedBranch = _defaultBranchId;
    bannerIndex = 0;
  }

  void _setPressActive(bool isPressed) {
    widget.onPressChanged?.call(isPressed);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final double clampedWidth = media.size.width.clamp(0.0, 500.0).toDouble();
    final hasValidBanners = _hasValidBanners;
    final opensBannerLinksOnly = widget.onBannerTap != null;
    final showBranchContent =
        !opensBannerLinksOnly && (showBranch || !hasValidBanners);

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _resetDisplayState();
          });
          widget.onClose();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Padding(
            padding: EdgeInsets.only(
              top: media.padding.top,
              bottom: media.padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    if (!showBranchContent && !opensBannerLinksOnly) {
                      setState(() {
                        selectedBranch = _defaultBranchId;
                        showBranch = true;
                      });
                    }
                  },
                  child: Listener(
                    onPointerDown: (_) => _setPressActive(true),
                    onPointerUp: (_) => _setPressActive(false),
                    onPointerCancel: (_) => _setPressActive(false),
                    child: Container(
                      width: clampedWidth - (showBranchContent ? 72 : 40),
                      height: showBranchContent ? null : clampedWidth - 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: showBranchContent
                            ? _buildBranchSelection()
                            : _buildBannerCarousel(clampedWidth),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Tap to skip",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ---------------- BANNERS (WEB SAFE)
  bool get _hasValidBanners {
    return widget.banners.any((banner) {
      return sanitizeImageUrl(banner.photo).isNotEmpty;
    });
  }

  List<Widget> _buildBannerCarousel(double clampedWidth) {
    final validBanners = widget.banners
        .where((banner) => sanitizeImageUrl(banner.photo).isNotEmpty)
        .toList();

    if (validBanners.isEmpty) {
      return [];
    }

    final hasMultipleBanners = validBanners.length > 1;

    return [
      CarouselSlider(
        items: validBanners.map((banner) {
          final bannerImage = Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              width: clampedWidth - 70,
              height: clampedWidth - 70,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: NetworkImageWidget(
                  imageUrl: banner.photo,
                  memCacheWidth: 600,
                  fit: BoxFit.cover,
                  progressIndicatorBuilder: (context, imageUrl, progress) {
                    return Container(
                      color: Colors.white,
                    );
                  },
                  errorWidget: (context, imageUrl, error) {
                    return Container(
                      color: Colors.white,
                    );
                  },
                ),
              ),
            ),
          );
          final onBannerTap = widget.onBannerTap;
          if (onBannerTap == null) {
            return bannerImage;
          }
          return WidgetButton(
            onTap: () async {
              await onBannerTap(banner);
            },
            borderRadius: 10,
            mainColor: Colors.transparent,
            isTransparentColor: true,
            useDefaultHoverColor: false,
            suppressInteraction: true,
            child: bannerImage,
          );
        }).toList(),
        options: CarouselOptions(
          height: clampedWidth - 55,
          autoPlay: hasMultipleBanners,
          enableInfiniteScroll: hasMultipleBanners,
          viewportFraction: 1,
          scrollPhysics:
              hasMultipleBanners ? null : const NeverScrollableScrollPhysics(),
          onPageChanged: (index, _) {
            setState(() => bannerIndex = index);
          },
        ),
      ),
      const SizedBox(height: 12),
      PageIndicatorWidget(
        count: validBanners.length,
        currentIndex: bannerIndex,
      ),
      const SizedBox(height: 12),
    ];
  }

  /// ---------------- BRANCH SELECTION
  List<Widget> _buildBranchSelection() {
    return [
      const SizedBox(height: 20),
      SizedBox(
        width: 66,
        height: 66,
        child: WidgetButton(
          onTap: () {
            if (!_hasValidBanners) {
              return;
            }
            setState(() {
              showBranch = false;
              bannerIndex = 0;
            });
          },
          borderRadius: 33,
          mainColor: Colors.transparent,
          isTransparentColor: true,
          useDefaultHoverColor: false,
          interactionColor: _hasValidBanners
              ? primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          child: ClipOval(
            child: SizedBox(
              width: 66,
              height: 66,
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    NetworkImageWidget(
                      imageUrl: widget.partnerImage,
                      memCacheWidth: 600,
                      fit: BoxFit.cover,
                      progressIndicatorBuilder: (context, imageUrl, progress) {
                        return const SizedBox.shrink();
                      },
                      errorWidget: (context, imageUrl, error) {
                        return Container(
                          color: Colors.white,
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: primaryColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox.expand(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        widget.partnerName,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        widget.partnerDescription,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      ...widget.branches.map(_branchButton),
      const SizedBox(height: 16),
      _setDropoffButton(),
      const SizedBox(height: 24),
    ];
  }

  Widget _branchButton(Branch branch) {
    final isSelected = selectedBranch == branch.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      child: WidgetButton(
        onTap: () {
          setState(() {
            selectedBranch = branch.id;
          });
        },
        borderRadius: 8,
        mainColor: Colors.transparent,
        isTransparentColor: true,
        useDefaultHoverColor: false,
        interactionColor: accentColor.withValues(alpha: 0.14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentColor : primaryColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  branch.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? accentColor : primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _setDropoffButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: SizedBox(
        height: 50,
        child: WidgetButton(
          onTap: () async {
            if (!widget.isLoggedIn()) {
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
              return;
            }
            if (selectedBranch == 0) {
              showError("Please select a dropoff branch");
              return;
            }
            final branch =
                widget.branches.firstWhere((b) => b.id == selectedBranch);
            widget.onSelectDropoff(
              branch.latLng,
              "${widget.partnerName} ${branch.name}",
            );
            setState(() {
              _resetDisplayState();
            });
            await StorageService.prefs?.setBool("is_ad_seen", true);
            await StorageService.prefs?.setBool("is_ad_1_seen", true);
            setState(() {
              isAdSeen = true;
              isAd1Seen = true;
            });
          },
          borderRadius: 8,
          mainColor: accentColor,
          useDefaultHoverColor: false,
          child: const Center(
            child: Text(
              "Set as Dropoff",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------- MODELS
class Branch {
  final int id;
  final String name;
  final gmaps.LatLng latLng;

  Branch({
    required this.id,
    required this.name,
    required this.latLng,
  });
}

class BannerModel {
  final String photo;
  final String link;

  BannerModel({
    required this.photo,
    this.link = "",
  });
}

/// ---------------- PAGE INDICATOR
class PageIndicatorWidget extends StatelessWidget {
  final int count;
  final int currentIndex;

  const PageIndicatorWidget({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  static const Color active = Color(0xFF007BFF);
  static const Color inactive = Color(0xFFA3C9FF);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return Container(
          width: isActive ? 10 : 6,
          height: isActive ? 10 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? active : inactive,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
