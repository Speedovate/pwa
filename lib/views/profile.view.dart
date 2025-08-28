import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/view_models/profile.vm.dart';
import 'package:pwa/widgets/network_image.widget.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  ProfileViewModel profileViewModel = ProfileViewModel();

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
                      const SizedBox(height: 12),
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
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF030744),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: const Color(0xFF030744).withOpacity(0.1),
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
                                ? Container(
                                    width:
                                        (MediaQuery.of(context).size.width / 3)
                                            .clamp(0, 250),
                                    height:
                                        (MediaQuery.of(context).size.width / 3)
                                            .clamp(0, 250),
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        fit: BoxFit.cover,
                                        image: MemoryImage(selfieFile!),
                                      ),
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(
                                          1000,
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
                                      child: NetworkImageWidget(
                                        fit: BoxFit.cover,
                                        memCacheWidth: 600,
                                        imageUrl:
                                            AuthService.currentUser?.cPhoto ??
                                                "",
                                        progressIndicatorBuilder: (
                                          context,
                                          imageUrl,
                                          progress,
                                        ) {
                                          return CircularProgressIndicator(
                                            strokeCap: StrokeCap.round,
                                            color: const Color(
                                              0xFF007BFF,
                                            ),
                                            backgroundColor: const Color(
                                              0xFF007BFF,
                                            ).withOpacity(0.25),
                                          );
                                        },
                                        errorWidget:
                                            (context, imageUrl, progress) {
                                          return Container(
                                            color: const Color(0xFF030744),
                                            child: const Icon(
                                              Icons.person_outline_outlined,
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
                                      color:
                                          const Color(0xFF030744).withOpacity(
                                        0.25,
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
                                  fontSize: 15,
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
                            color: const Color(0xFF030744).withOpacity(0.1),
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
                                "Full Name",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
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
                                  fontWeight: FontWeight.w500,
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
                                "Email Address",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
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
                                  fontWeight: FontWeight.w500,
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
                                "Phone Number",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
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
                                "${AuthService.currentUser!.phone}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
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
                                "Current Area",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
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
                                  "${AuthService.currentUser!.branchName} - ${AuthService.currentUser!.branchID}",
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
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
                                "User ID",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
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
                                  fontWeight: FontWeight.w500,
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
