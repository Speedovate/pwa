import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/view_models/profile.vm.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:pwa/widgets/top_cropped_network_image.widget.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  static final DateTime _phpStyleProfilePhotoStartDate = DateTime(2026, 6, 6);
  static const double _currentUserTopHalfVisibleFractionWeb = 0.55;
  static const double _currentUserTopHalfVisibleFractionMobile = 0.60;
  ProfileViewModel profileViewModel = ProfileViewModel();

  double _currentUserTopHalfVisibleFraction(bool isMobile) {
    return isMobile
        ? _currentUserTopHalfVisibleFractionMobile
        : _currentUserTopHalfVisibleFractionWeb;
  }

  Widget _buildTopCroppedLocalSelfiePreview(
    BoxConstraints constraints, {
    required double visibleFraction,
  }) {
    return SizedBox(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: constraints.maxWidth,
          maxWidth: constraints.maxWidth,
          minHeight: constraints.maxHeight / visibleFraction,
          maxHeight: constraints.maxHeight / visibleFraction,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scaleByDouble(
                selfieFileNeedsHorizontalFlip ? -1.0 : 1.0,
                1.0,
                1.0,
                1.0,
              ),
            child: Image.memory(
              selfieFile!,
              width: constraints.maxWidth,
              height: constraints.maxHeight / visibleFraction,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
      ),
    );
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

  bool _shouldUseTopHalfCurrentUserPhoto(bool isMobile) {
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (selfieFile == null) {
          Get.back(result: true);
        } else {
          AlertService().showAppAlert(
            title: "Are you sure?",
            content: "You're about to leave this page",
            hideCancel: false,
            confirmText: "Go back",
            confirmAction: () {
              Get.back(result: true);
              Get.back(result: true);
            },
          );
        }
      },
      child: ViewModelBuilder<ProfileViewModel>.reactive(
        viewModelBuilder: () => profileViewModel,
        onViewModelReady: (vm) => vm.initialise(),
        builder: (context, vm, child) {
          final mediaQuery = MediaQuery.of(context);
          final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
          final visibleFraction = _currentUserTopHalfVisibleFraction(isMobile);
          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                toolbarHeight: 0,
                backgroundColor: Colors.white,
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: isMobile ? mediaQuery.padding.top + 36 : 12,
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          WidgetButton(
                            onTap: () {
                              if (selfieFile == null) {
                                Get.back(result: true);
                              } else {
                                AlertService().showAppAlert(
                                  title: "Are you sure?",
                                  content: "You're about to leave this page",
                                  hideCancel: false,
                                  confirmText: "Go back",
                                  confirmAction: () {
                                    Get.back(result: true);
                                    Get.back(result: true);
                                  },
                                );
                              }
                            },
                            child: const SizedBox(
                              width: 58,
                              height: 58,
                              child: Center(
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
                          const SizedBox(width: 2),
                          const Text(
                            "Profile",
                            style: TextStyle(
                              height: 1,
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF030744),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: const Color(0xFF030744).withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          showImageSource(isEdit: true);
                        },
                        child: Stack(
                          children: [
                            selfieFile != null
                                ? ClipOval(
                                    child: SizedBox(
                                      width:
                                          (MediaQuery.of(context).size.width / 3)
                                              .clamp(0, 250),
                                      height:
                                          (MediaQuery.of(context).size.width / 3)
                                              .clamp(0, 250),
                                      child: selfieFileFromMobileCamera
                                          ? LayoutBuilder(
                                              builder: (
                                                context,
                                                constraints,
                                              ) {
                                                return _buildTopCroppedLocalSelfiePreview(
                                                  constraints,
                                                  visibleFraction:
                                                      visibleFraction,
                                                );
                                              },
                                            )
                                          : Transform(
                                              alignment: Alignment.center,
                                              transform: Matrix4.identity()
                                                ..scaleByDouble(
                                                  selfieFileNeedsHorizontalFlip
                                                      ? -1.0
                                                      : 1.0,
                                                  1.0,
                                                  1.0,
                                                  1.0,
                                                ),
                                              child: Image.memory(
                                                selfieFile!,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                    ),
                                  )
                                : SizedBox(
                                    width:
                                        (MediaQuery.of(context).size.width / 3)
                                            .clamp(0, 250),
                                    height:
                                        (MediaQuery.of(context).size.width / 3)
                                            .clamp(0, 250),
                                    child: ClipOval(
                                      child: _shouldUseTopHalfCurrentUserPhoto(
                                            isMobile,
                                          )
                                          ? LayoutBuilder(
                                              builder: (
                                                context,
                                                constraints,
                                              ) {
                                                final imageProvider =
                                                    safeNetworkImageProvider(
                                                  AuthService
                                                          .currentUser
                                                          ?.cPhoto ??
                                                      "",
                                                  cacheWidth: 600,
                                                );
                                                if (imageProvider == null) {
                                                  return Container(
                                                    color: const Color(
                                                      0xFF030744,
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .person_outline_outlined,
                                                      color: Colors.white,
                                                      size: 50,
                                                    ),
                                                  );
                                                }
                                                return TopCroppedNetworkImage(
                                                  imageProvider: imageProvider,
                                                  visibleFraction:
                                                      visibleFraction,
                                                  loadingChild:
                                                      CircularProgressIndicator(
                                                    strokeCap:
                                                        StrokeCap.round,
                                                    color: const Color(
                                                      0xFF007BFF,
                                                    ),
                                                    backgroundColor:
                                                        const Color(
                                                      0xFF007BFF,
                                                    ).withValues(
                                                      alpha: 0.25,
                                                    ),
                                                  ),
                                                  errorChild: Container(
                                                    color: const Color(
                                                      0xFF030744,
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .person_outline_outlined,
                                                      color: Colors.white,
                                                      size: 50,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : NetworkImageWidget(
                                              fit: BoxFit.cover,
                                              memCacheWidth: 600,
                                              imageUrl:
                                                  AuthService
                                                      .currentUser
                                                      ?.cPhoto ??
                                                  "",
                                              progressIndicatorBuilder: (
                                                context,
                                                imageUrl,
                                                progress,
                                              ) {
                                                return Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeCap:
                                                        StrokeCap.round,
                                                    color: const Color(
                                                      0xFF007BFF,
                                                    ),
                                                    backgroundColor:
                                                        const Color(
                                                          0xFF007BFF,
                                                        ).withValues(
                                                          alpha: 0.25,
                                                        ),
                                                  ),
                                                );
                                              },
                                              errorWidget:
                                                  (
                                                    context,
                                                    imageUrl,
                                                    progress,
                                                  ) {
                                                    return Container(
                                                      color: const Color(
                                                        0xFF030744,
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .person_outline_outlined,
                                                        color: Colors.white,
                                                        size: 50,
                                                      ),
                                                    );
                                                  },
                                            ),
                                    ),
                                  ),
                            Positioned(
                              right: (MediaQuery.of(context).size.width / 3)
                                      .clamp(0, 250) /
                                  20,
                              bottom: (MediaQuery.of(context).size.width / 3)
                                      .clamp(0, 250) /
                                  20,
                              child: Container(
                                width: (MediaQuery.of(context).size.width / 3)
                                        .clamp(0, 250) /
                                    5,
                                height: (MediaQuery.of(context).size.width / 3)
                                        .clamp(0, 250) /
                                    5,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(
                                      1000,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF030744).withValues(
                                        alpha: 0.25,
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
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    showImageSource(isEdit: true);
                                  },
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top:
                                            (MediaQuery.of(context).size.width /
                                                        3)
                                                    .clamp(0, 250) /
                                                80,
                                      ),
                                      child: Icon(
                                        Icons.photo_camera_outlined,
                                        color: const Color(0xFF030744),
                                        size:
                                            (MediaQuery.of(context).size.width /
                                                        3)
                                                    .clamp(0, 250) /
                                                7,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: const Row(
                            children: [
                              Text(
                                "Account Information",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color:
                                const Color(0xFF030744).withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Row(
                            children: [
                              Text(
                                "Name",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF030744)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Row(
                            children: [
                              Text(
                                capitalizeWords(
                                  "${AuthService.currentUser!.name}",
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: GestureDetector(
                            onTap: () {
                              // Clipboard.setData(
                              //   ClipboardData(
                              //     text: lowerCase(
                              //       AuthService.currentUser?.code,
                              //     ),
                              //   ),
                              // );
                              copyToClipboardWeb(
                                lowerCase(
                                  AuthService.currentUser?.code,
                                ),
                              );
                              ScaffoldMessenger.of(
                                Get.context!,
                              ).clearSnackBars();
                              ScaffoldMessenger.of(
                                Get.context!,
                              ).showSnackBar(
                                SnackBar(
                                  margin: const EdgeInsets.all(
                                    20,
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.grey.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  content: const Text(
                                    "Copied to clipboard.",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "Referral",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: const Color(0xFF030744)
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        lowerCase(
                                          "${AuthService.currentUser?.code}",
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF030744),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.copy,
                                        size: 14,
                                        color: Color(0xFF030744),
                                      ),
                                      const SizedBox(width: 2),
                                      const Text(
                                        "tap to copy",
                                        style: TextStyle(
                                          color: Color(0xFF030744),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Row(
                            children: [
                              Text(
                                "Email",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF030744)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Row(
                            children: [
                              Text(
                                "${AuthService.currentUser!.email}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      "${AuthService.currentUser?.phone}".contains(
                        "+639000000000",
                      )
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: SizedBox(
                                width: double.infinity.clamp(0, 800),
                                child: Row(
                                  children: [
                                    Text(
                                      "Phone",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(0xFF030744)
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      "${AuthService.currentUser?.phone}".contains(
                        "+639000000000",
                      )
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: SizedBox(
                                width: double.infinity.clamp(0, 800),
                                child: Row(
                                  children: [
                                    Text(
                                      "${AuthService.currentUser!.phone}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF030744),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      "${AuthService.currentUser?.phone}".contains(
                        "+639000000000",
                      )
                          ? const SizedBox.shrink()
                          : const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Row(
                            children: [
                              Text(
                                "Area",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF030744)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Row(
                            children: [
                              Text(
                                capitalizeWords(
                                  "${AuthService.currentUser!.branchName} (${AuthService.currentUser!.branchID})",
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Row(
                            children: [
                              Text(
                                "UID",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF030744)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: Row(
                            children: [
                              Text(
                                capitalizeWords(
                                  "${AuthService.currentUser!.id}",
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: ActionButton(
                          text: "Save",
                          mainColor: selfieFile == null
                              ? Colors.grey.shade300
                              : const Color(0xFF007BFF),
                          onTap: () async {
                            if (selfieFile != null) {
                              await vm.processUpdate();
                              setState(() {
                                selfieFile = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
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
}
