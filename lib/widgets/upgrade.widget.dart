import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/network_image.widget.dart';

class UpgradeWidget extends StatelessWidget {
  const UpgradeWidget({super.key});

  void _closeUpgrade() {
    AuthService.dismissUpgradeForSession();
    Get.forceAppUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final isForced = AuthService.isUpgradeForced();
    final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
    final inheritedMediaQuery = MediaQuery.of(context);
    final rootViewMediaQuery = MediaQueryData.fromView(View.of(context));
    final rootMediaQuery = inheritedMediaQuery.copyWith(
      size: rootViewMediaQuery.size,
      padding: rootViewMediaQuery.padding,
      viewPadding: rootViewMediaQuery.viewPadding,
      viewInsets: rootViewMediaQuery.viewInsets,
      systemGestureInsets: rootViewMediaQuery.systemGestureInsets,
    );

    return Positioned.fill(
      child: MediaQuery(
        data: rootMediaQuery,
        child: Material(
          color: Colors.white,
          child: Container(
            width: rootMediaQuery.size.width,
            height: rootMediaQuery.size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade300,
                  Colors.white,
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              minimum: const EdgeInsets.only(
                bottom: 16,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          isMobile ? rootMediaQuery.padding.top + 26 : 26,
                          24,
                          0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 32),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                    child: NetworkImageWidget(
                                      imageUrl: AppImages.logo,
                                      memCacheWidth: 600,
                                      height: 50,
                                      width: 50,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              child: !isForced
                                  ? WidgetButton(
                                      onTap: _closeUpgrade,
                                      mainColor: Colors.transparent,
                                      isTransparentColor: true,
                                      useDefaultHoverColor: false,
                                      interactionColor: const Color(0x14030744),
                                      borderRadius: 1000,
                                      child: const SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: Center(
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const Expanded(flex: 1, child: SizedBox.shrink()),
                      SizedBox(
                        height: rootMediaQuery.size.height / 3,
                        child: Lottie.asset(
                          AppLotties.update,
                          fit: BoxFit.cover,
                          delegates: LottieDelegates(
                            values: [
                              ValueDelegate.color(
                                [
                                  '**',
                                  'Smoke',
                                  '**',
                                ],
                                value: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "New version available",
                        style: TextStyle(
                          height: 1.05,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF030744),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isForced
                            ? "Your current application's version is no"
                                "\nlonger supported, we apologize for any"
                                "\ninconvenience we may have caused you"
                            : "A newer version is available."
                                "\nYou can update now, or skip this"
                                "\nversion and continue using the app.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.15,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: const Color(
                            0xFF030744,
                          ).withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            await showFacebookSupportDialog(context);
                          },
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "Need help now? ",
                                  style: TextStyle(
                                    height: 1.15,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(
                                      0xFF030744,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                const TextSpan(
                                  text: "Contact",
                                  style: TextStyle(
                                    height: 1.15,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF007BFF),
                                  ),
                                ),
                                TextSpan(
                                  text: " or ",
                                  style: TextStyle(
                                    height: 1.15,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(
                                      0xFF030744,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                const TextSpan(
                                  text: "Message",
                                  style: TextStyle(
                                    height: 1.15,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF007BFF),
                                  ),
                                ),
                                TextSpan(
                                  text: " us!",
                                  style: TextStyle(
                                    height: 1.15,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(
                                      0xFF030744,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ActionButton(
                          text: "Update",
                          onTap: () async {
                            if (GetPlatform.isWeb) {
                              await refreshWebAppWithCacheBust();
                              return;
                            }
                            await openExternalUrl(
                              AuthService.upgradeDownloadLink(),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: !isForced ? 14 : 16),
                      if (!isForced) ...[
                        TextButton(
                          onPressed: _closeUpgrade,
                          child: const Text(
                            "Skip for now",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF007BFF),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
