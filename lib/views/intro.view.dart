import 'package:flutter/material.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/upgrade.widget.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:pwa/widgets/page_indicator.widget.dart';

class IntroView extends StatefulWidget {
  const IntroView({super.key});

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView> {
  List<String> items = ["a", "b", "c", "d", "e"];
  int itemsIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
                child: Column(
                  children: [
                    Expanded(
                      child: CarouselSlider(
                        items: items
                            .map(
                              (item) => Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 80,
                                    left: 50,
                                    right: 50,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MediaQuery.of(context).size.height >
                                                1024
                                            ? MainAxisAlignment.center
                                            : MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width >
                                                    MediaQuery.of(context)
                                                        .size
                                                        .height
                                                ? (MediaQuery.of(context)
                                                            .size
                                                            .height /
                                                        3)
                                                    .clamp(0, 250)
                                                : (MediaQuery.of(context)
                                                            .size
                                                            .width /
                                                        2.2)
                                                    .clamp(0, 250),
                                        height:
                                            MediaQuery.of(context).size.width >
                                                    MediaQuery.of(context)
                                                        .size
                                                        .height
                                                ? (MediaQuery.of(context)
                                                            .size
                                                            .height /
                                                        3)
                                                    .clamp(0, 250)
                                                : (MediaQuery.of(context)
                                                            .size
                                                            .width /
                                                        2.2)
                                                    .clamp(0, 250),
                                        child: Center(
                                          child: Image.asset(
                                            () {
                                              if (item == "e") {
                                                return AppImages.cashless;
                                              }
                                              if (item == "d") {
                                                return AppImages.security;
                                              }
                                              if (item == "c") {
                                                return AppImages.transparency;
                                              }
                                              if (item == "b") {
                                                return AppImages.overcharging;
                                              } else {
                                                return AppImages.convenience;
                                              }
                                            }(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        () {
                                          if (item == "e") {
                                            return "Cashless Payments";
                                          }
                                          if (item == "d") {
                                            return "Enhanced Security";
                                          }
                                          if (item == "c") {
                                            return "Price Transparency";
                                          }
                                          if (item == "b") {
                                            return "No To Overcharging";
                                          } else {
                                            return "Passenger Convenience";
                                          }
                                        }(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        () {
                                          if (item == "e") {
                                            return "No need to worry about cash or change anymore. You can now pay using digital options for seamless payments.";
                                          }
                                          if (item == "d") {
                                            return "Your safety always comes first. Ride with peace of mind knowing we’ve got your back every step of the way.";
                                          }
                                          if (item == "c") {
                                            return "Know the exact amount before you ride. With transparent pricing, you can travel confidently without surprises.";
                                          }
                                          if (item == "b") {
                                            return "No more overcharging. Fair prices every time so you can trust and enjoy your ride without having the need to worry.";
                                          } else {
                                            return "Booking is fast and simple for everyone. Enjoy smooth and reliable tricycle rides from start to finish with ease.";
                                          }
                                        }(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        options: CarouselOptions(
                          height: MediaQuery.of(context).size.height -
                              200 -
                              MediaQuery.of(context).padding.top,
                          initialPage: 0,
                          autoPlay: true,
                          viewportFraction: 1,
                          onPageChanged: (index, reason) {
                            setState(
                              () {
                                itemsIndex = index;
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    PageIndicatorWidget(
                      activeSize: 10,
                      inactiveSize: 6,
                      count: items.length,
                      currentIndex: itemsIndex,
                      activeColor: const Color(0xFF007BFF),
                      inactiveColor: const Color(0xFFA3C9FF),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      child: ActionButton(
                        text: "Login with phone",
                        onTap: () {
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
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      child: ActionButton(
                        text: "Continue as guest",
                        mainColor: const Color(0xFF030744),
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              reverseTransitionDuration: Duration.zero,
                              transitionDuration: Duration.zero,
                              pageBuilder: (
                                context,
                                a,
                                b,
                              ) =>
                                  const HomeView(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
          !AuthService.shouldUpgrade()
              ? const SizedBox()
              : const UpgradeWidget(),
        ],
      ),
    );
  }
}
