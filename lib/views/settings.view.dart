import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/change.view.dart';
import 'package:pwa/views/delete.view.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/view_models/settings.vm.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  SettingsViewModel settingsViewModel = SettingsViewModel();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<SettingsViewModel>.reactive(
      viewModelBuilder: () => settingsViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        final mediaQuery = MediaQuery.of(context);
        return GestureDetector(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Padding(
              padding: EdgeInsets.only(
                top: mediaQuery.padding.top,
                bottom: 12,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      WidgetButton(
                        onTap: () {
                          Get.back();
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
                        "Settings",
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
                  WidgetButton(
                    borderRadius: 0,
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
                              ChangeView(
                            isReset: false,
                            phone: AuthService.currentUser?.phone!,
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(
                        top: 16,
                        left: 16,
                        right: 12,
                        bottom: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outlined,
                            color: Color(0xFF030744),
                            size: 25,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Change Password",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF030744),
                            ),
                          ),
                          Expanded(child: SizedBox.shrink()),
                          Icon(
                            Icons.chevron_right,
                            color: Color(0xFF030744),
                            size: 25,
                          ),
                        ],
                      ),
                    ),
                  ),
                  !AuthService.inReviewMode()
                      ? const SizedBox.shrink()
                      : WidgetButton(
                          borderRadius: 0,
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
                                    const DeleteView(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(
                              top: 16,
                              left: 16,
                              right: 12,
                              bottom: 16,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outlined,
                                  color: Colors.red,
                                  size: 25,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Delete Account",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  WidgetButton(
                    borderRadius: 0,
                    onTap: () {
                      vm.logoutPressed();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(
                        top: 16,
                        left: 16,
                        right: 12,
                        bottom: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout,
                            color: Colors.red,
                            size: 25,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Logout Account",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
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
