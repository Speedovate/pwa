import 'package:lottie/lottie.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UpgradeWidget extends StatelessWidget {
  const UpgradeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
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
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              const SizedBox(height: 52),
              ClipOval(
                child: Image.asset(
                  "assets/images/logo.png",
                  height: 50,
                  width: 50,
                ),
              ),
              const Expanded(flex: 1, child: SizedBox()),
              SizedBox(
                height: MediaQuery.of(context).size.height / 3,
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
              const Expanded(child: SizedBox()),
              const Text(
                "New version available",
                style: TextStyle(
                  height: 1.05,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF030744),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your current application's version is no"
                "\nlonger supported, we apologize for any"
                "\ninconvenience we may have caused you",
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.15,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF030744).withOpacity(0.5),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "Need help? ",
                          style: TextStyle(
                            height: 1.15,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF030744).withOpacity(0.5),
                          ),
                        ),
                        TextSpan(
                          text: "Contact",
                          style: const TextStyle(
                            height: 1.15,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007BFF),
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrlString(
                                "sms://+639122078420",
                                mode: LaunchMode.externalNonBrowserApplication,
                              );
                            },
                        ),
                        TextSpan(
                          text: " or ",
                          style: TextStyle(
                            height: 1.15,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF030744).withOpacity(0.5),
                          ),
                        ),
                        TextSpan(
                          text: "Message",
                          style: const TextStyle(
                            height: 1.15,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007BFF),
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrlString(
                                "https://www.facebook.com/ppctodaofficial",
                                mode: LaunchMode.externalNonBrowserApplication,
                              );
                            },
                        ),
                        TextSpan(
                          text: " us!",
                          style: TextStyle(
                            height: 1.15,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF030744).withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                ),
                child: ActionButton(
                  text: "Update",
                  onTap: () {
                    launchUrlString(
                      "https://ppctoda.framer.website",
                      mode: LaunchMode.externalNonBrowserApplication,
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
