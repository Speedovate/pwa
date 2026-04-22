import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/widgets/network_image.widget.dart';

class PartnerDisplayWidget extends StatefulWidget {
  final bool show;
  final VoidCallback onClose;
  final bool Function() isLoggedIn;
  final void Function(gmaps.LatLng dropoff, String branchName) onSelectDropoff;
  final List<BannerModel> banners;
  final String partnerName;
  final String partnerDescription;
  final String partnerImage;
  final List<Branch> branches;

  const PartnerDisplayWidget({
    super.key,
    required this.show,
    required this.onClose,
    required this.isLoggedIn,
    required this.onSelectDropoff,
    required this.banners,
    required this.partnerName,
    required this.partnerDescription,
    required this.partnerImage,
    required this.branches,
  });

  @override
  State<PartnerDisplayWidget> createState() => _PartnerDisplayWidgetState();
}

class _PartnerDisplayWidgetState extends State<PartnerDisplayWidget> {
  bool showBranch = false;
  int selectedBranch = 0;
  int bannerIndex = 0;

  static const Color primaryColor = Color(0xFF030744);
  static const Color accentColor = Color(0xFF007BFF);

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final double clampedWidth = media.size.width.clamp(0.0, 500.0).toDouble();

    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    if (!showBranch) {
                      setState(() {
                        selectedBranch = 0;
                        showBranch = true;
                      });
                    }
                  },
                  child: Container(
                    width: clampedWidth - 40,
                    height: showBranch ? null : clampedWidth - 20,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: showBranch
                          ? _buildBranchSelection()
                          : _buildBannerCarousel(clampedWidth),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Tap to close",
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ---------------- BANNERS (WEB SAFE)
  List<Widget> _buildBannerCarousel(double clampedWidth) {
    final validBanners = widget.banners
        .where((banner) => sanitizeImageUrl(banner.photo).isNotEmpty)
        .toList();

    if (validBanners.isEmpty) return [];

    return [
      CarouselSlider(
        items: validBanners.map((banner) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              width: clampedWidth - 70,
              height: clampedWidth - 70,
              color: Colors.white,
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
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: primaryColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
        options: CarouselOptions(
          height: clampedWidth - 55,
          autoPlay: true,
          viewportFraction: 1,
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
      ClipOval(
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
                InkWell(
                  onTap: () {},
                  hoverDuration: const Duration(milliseconds: 500),
                  focusColor: primaryColor.withValues(alpha: 0.2),
                  hoverColor: primaryColor.withValues(alpha: 0.2),
                  splashColor: primaryColor.withValues(alpha: 0.2),
                  highlightColor: primaryColor.withValues(alpha: 0.2),
                ),
              ],
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
      const SizedBox(height: 16),
      ...widget.branches.map(_branchButton),
      const SizedBox(height: 22),
      _setDropoffButton(),
      const SizedBox(height: 22),
    ];
  }

  Widget _branchButton(Branch branch) {
    final isSelected = selectedBranch == branch.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedBranch = isSelected ? 0 : branch.id;
        });
      },
      child: Container(
        height: 50,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? accentColor : primaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Center(
          child: Text(
            branch.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? accentColor
                  : primaryColor.withValues(alpha: 0.6),
            ),
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
        child: Material(
          color: accentColor,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
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
                ScaffoldMessenger.of(Get.context!).showSnackBar(const SnackBar(
                  backgroundColor: Colors.red,
                  content: Text("Please select a dropoff branch"),
                ));
                return;
              }
              final branch =
                  widget.branches.firstWhere((b) => b.id == selectedBranch);
              widget.onSelectDropoff(
                branch.latLng,
                "${widget.partnerName} ${branch.name}",
              );
              setState(() {
                selectedBranch = 0;
                showBranch = false;
              });
              await StorageService.prefs?.setBool("is_ad_seen", true);
              await StorageService.prefs?.setBool("is_ad_1_seen", true);
              setState(() {
                isAdSeen = true;
                isAd1Seen = true;
              });
            },
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

  BannerModel({required this.photo});
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
