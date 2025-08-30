// ignore_for_file: depend_on_referenced_packages

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:pwa/models/order.model.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:pwa/view_models/chat.vm.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/order.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:pwa/widgets/network_image.widget.dart';

class ChatView extends StatefulWidget {
  const ChatView(
    this.chatEntity,
    this.order, {
    this.readOnly = false,
    super.key,
  });

  final ChatEntity chatEntity;
  final Order order;
  final bool readOnly;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  var _index = 0;
  bool isMediaLoading = false;
  late TextEditingController _controller;

  Key _getKey() => Key('selectable-text-$_index');

  void _removeSelection() => setState(() => _index++);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        fbStore
            .collection(
              "orders",
            )
            .doc(widget.order.code)
            .update(
          {
            "userSeen": true,
          },
        );
        Get.back();
      },
      child: ViewModelBuilder<ChatViewModel>.reactive(
        viewModelBuilder: () => ChatViewModel(widget.chatEntity),
        onViewModelReady: (model) => model.initialise(),
        builder: (context, vm, child) {
          return GestureDetector(
            onTap: () {
              _removeSelection();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () async {
                            fbStore
                                .collection(
                                  "orders",
                                )
                                .doc(widget.order.code)
                                .update(
                              {
                                "userSeen": true,
                              },
                            );
                            Get.back();
                          },
                          icon: const Padding(
                            padding: EdgeInsets.only(
                              top: 2,
                              right: 4,
                              bottom: 2,
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              color: Color(
                                0xFF030744,
                              ),
                              size: 38,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          "Chat Driver",
                          style: TextStyle(
                            height: 1,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                            color: Color(
                              0xFF030744,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: const Color(
                        0xFF030744,
                      ).withOpacity(
                        0.15,
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Builder(builder: (context) {
                            try {
                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      reverse: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: vm.messages.length,
                                      itemBuilder: (context, index) {
                                        if (vm.messages[index].text == "" ||
                                            vm.messages[index].text == "null") {
                                          return const SizedBox.shrink();
                                        } else if (vm.messages[index].user.id !=
                                            "${AuthService.currentUser?.id}") {
                                          return GestureDetector(
                                            onTap: () {
                                              if (vm.messages[index].text
                                                  .contains("https")) {
                                                AlertService().showAppAlert(
                                                  isCustom: true,
                                                  customWidget: PinchZoom(
                                                    child: Image.network(
                                                      vm.messages[index].text,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                top: vm.messages[index].user
                                                            .id ==
                                                        () {
                                                          try {
                                                            return vm
                                                                .messages[
                                                                    index + 1]
                                                                .user
                                                                .id;
                                                          } catch (e) {
                                                            return "";
                                                          }
                                                        }()
                                                    ? 0
                                                    : 12,
                                                left: 12,
                                                right: 12,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  vm.messages[index].user.id ==
                                                          () {
                                                            try {
                                                              return vm
                                                                  .messages[
                                                                      index - 1]
                                                                  .user
                                                                  .id;
                                                            } catch (e) {
                                                              return "";
                                                            }
                                                          }()
                                                      ? const SizedBox(
                                                          width: 35)
                                                      : ClipOval(
                                                          child: SizedBox(
                                                            width: 35,
                                                            height: 35,
                                                            child:
                                                                NetworkImageWidget(
                                                              fit: BoxFit.cover,
                                                              memCacheWidth:
                                                                  600,
                                                              imageUrl:
                                                                  "${vm.messages[index].user.profileImage}",
                                                              progressIndicatorBuilder:
                                                                  (
                                                                context,
                                                                imageUrl,
                                                                progress,
                                                              ) {
                                                                return const CircularProgressIndicator(
                                                                  color: Color(
                                                                    0xFF007BFF,
                                                                  ),
                                                                  strokeWidth:
                                                                      2,
                                                                );
                                                              },
                                                              errorWidget: (
                                                                context,
                                                                imageUrl,
                                                                progress,
                                                              ) {
                                                                return Container(
                                                                  color:
                                                                      const Color(
                                                                    0xFF030744,
                                                                  ),
                                                                  child:
                                                                      const Icon(
                                                                    Icons
                                                                        .person_outline_outlined,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                  const SizedBox(width: 12),
                                                  Flexible(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        vm.messages[index].user
                                                                    .id ==
                                                                () {
                                                                  try {
                                                                    return vm
                                                                        .messages[
                                                                            index +
                                                                                1]
                                                                        .user
                                                                        .id;
                                                                  } catch (e) {
                                                                    return "";
                                                                  }
                                                                }()
                                                            ? const SizedBox
                                                                .shrink()
                                                            : Text(
                                                                vm
                                                                    .messages[
                                                                        index]
                                                                    .user
                                                                    .getFullName(),
                                                                style:
                                                                    const TextStyle(
                                                                  height: 1.15,
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Container(
                                                          padding: vm
                                                                  .messages[
                                                                      index]
                                                                  .text
                                                                  .contains(
                                                            "https",
                                                          )
                                                              ? EdgeInsets.zero
                                                              : const EdgeInsets
                                                                  .all(
                                                                  10,
                                                                ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .grey.shade200,
                                                            borderRadius:
                                                                const BorderRadius
                                                                    .all(
                                                              Radius.circular(
                                                                8,
                                                              ),
                                                            ),
                                                            image: !vm
                                                                    .messages[
                                                                        index]
                                                                    .text
                                                                    .contains(
                                                              "https",
                                                            )
                                                                ? null
                                                                : DecorationImage(
                                                                    fit: BoxFit
                                                                        .cover,
                                                                    image:
                                                                        NetworkImage(
                                                                      vm.messages[index]
                                                                          .text,
                                                                    ),
                                                                  ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              vm.messages[index]
                                                                      .text
                                                                      .contains(
                                                                "https",
                                                              )
                                                                  ? SizedBox(
                                                                      width: MediaQuery.of(context)
                                                                              .size
                                                                              .width -
                                                                          124,
                                                                      height: MediaQuery.of(context)
                                                                              .size
                                                                              .width -
                                                                          124,
                                                                    )
                                                                  : SelectableText(
                                                                      vm.messages[index]
                                                                          .text,
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            15,
                                                                        height:
                                                                            1.15,
                                                                        color: Colors
                                                                            .black,
                                                                      ),
                                                                      key:
                                                                          _getKey(),
                                                                    ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Container(
                                                                margin: vm
                                                                        .messages[
                                                                            index]
                                                                        .text
                                                                        .contains(
                                                                  "https",
                                                                )
                                                                    ? const EdgeInsets
                                                                        .all(5)
                                                                    : EdgeInsets
                                                                        .zero,
                                                                padding: vm
                                                                        .messages[
                                                                            index]
                                                                        .text
                                                                        .contains(
                                                                  "https",
                                                                )
                                                                    ? const EdgeInsets
                                                                        .all(5)
                                                                    : EdgeInsets
                                                                        .zero,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  borderRadius:
                                                                      const BorderRadius
                                                                          .all(
                                                                    Radius
                                                                        .circular(
                                                                      5,
                                                                    ),
                                                                  ),
                                                                  color: vm
                                                                          .messages[
                                                                              index]
                                                                          .text
                                                                          .contains(
                                                                    "https",
                                                                  )
                                                                      ? Colors
                                                                          .black
                                                                          .withOpacity(
                                                                          0.5,
                                                                        )
                                                                      : Colors
                                                                          .transparent,
                                                                ),
                                                                child: Text(
                                                                  DateFormat(
                                                                    "h:mm a",
                                                                  ).format(
                                                                    vm
                                                                        .messages[
                                                                            index]
                                                                        .createdAt,
                                                                  ),
                                                                  style:
                                                                      TextStyle(
                                                                    height:
                                                                        1.15,
                                                                    fontSize:
                                                                        12,
                                                                    color: vm
                                                                            .messages[
                                                                                index]
                                                                            .text
                                                                            .contains(
                                                                      "https",
                                                                    )
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .black,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 50),
                                                ],
                                              ),
                                            ),
                                          );
                                        } else {
                                          return GestureDetector(
                                            onTap: () {
                                              if (vm.messages[index].text
                                                  .contains("https")) {
                                                AlertService().showAppAlert(
                                                  isCustom: true,
                                                  customWidget: PinchZoom(
                                                    child: Image.network(
                                                      vm.messages[index].text,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                top: vm.messages[index].user
                                                            .id ==
                                                        () {
                                                          try {
                                                            return vm
                                                                .messages[
                                                                    index + 1]
                                                                .user
                                                                .id;
                                                          } catch (e) {
                                                            return "";
                                                          }
                                                        }()
                                                    ? 4
                                                    : 12,
                                                left: 12,
                                                right: 12,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  const SizedBox(width: 50),
                                                  Flexible(
                                                    child: Container(
                                                      padding: vm
                                                              .messages[index]
                                                              .text
                                                              .contains(
                                                        "https",
                                                      )
                                                          ? EdgeInsets.zero
                                                          : const EdgeInsets
                                                              .all(
                                                              10,
                                                            ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF007BFF,
                                                        ),
                                                        borderRadius:
                                                            const BorderRadius
                                                                .all(
                                                          Radius.circular(
                                                            8,
                                                          ),
                                                        ),
                                                        image: !vm
                                                                .messages[index]
                                                                .text
                                                                .contains(
                                                          "https",
                                                        )
                                                            ? null
                                                            : DecorationImage(
                                                                fit: BoxFit
                                                                    .cover,
                                                                image:
                                                                    NetworkImage(
                                                                  vm
                                                                      .messages[
                                                                          index]
                                                                      .text,
                                                                ),
                                                              ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          vm.messages[index]
                                                                  .text
                                                                  .contains(
                                                            "https",
                                                          )
                                                              ? SizedBox(
                                                                  width: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width -
                                                                      124,
                                                                  height: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width -
                                                                      124,
                                                                )
                                                              : SelectableText(
                                                                  vm
                                                                      .messages[
                                                                          index]
                                                                      .text,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        15,
                                                                    height:
                                                                        1.15,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                  key:
                                                                      _getKey(),
                                                                ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          Container(
                                                            margin: vm
                                                                    .messages[
                                                                        index]
                                                                    .text
                                                                    .contains(
                                                              "https",
                                                            )
                                                                ? const EdgeInsets
                                                                    .all(5)
                                                                : EdgeInsets
                                                                    .zero,
                                                            padding: vm
                                                                    .messages[
                                                                        index]
                                                                    .text
                                                                    .contains(
                                                              "https",
                                                            )
                                                                ? const EdgeInsets
                                                                    .all(5)
                                                                : EdgeInsets
                                                                    .zero,
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  const BorderRadius
                                                                      .all(
                                                                Radius.circular(
                                                                  5,
                                                                ),
                                                              ),
                                                              color: vm
                                                                      .messages[
                                                                          index]
                                                                      .text
                                                                      .contains(
                                                                "https",
                                                              )
                                                                  ? Colors.black
                                                                      .withOpacity(
                                                                          0.5)
                                                                  : Colors
                                                                      .transparent,
                                                            ),
                                                            child: Text(
                                                              DateFormat(
                                                                "h:mm a",
                                                              ).format(
                                                                vm
                                                                    .messages[
                                                                        index]
                                                                    .createdAt,
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                height: 1.15,
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    height: chatFile == null
                                        ? null
                                        : MediaQuery.of(context).size.width,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          _controller.text != "" &&
                                                  _controller.text != "null"
                                              ? const SizedBox(width: 16)
                                              : const SizedBox(width: 8),
                                          _controller.text != "" &&
                                                  _controller.text != "null"
                                              ? const SizedBox.shrink()
                                              : SizedBox(
                                                  width: 38,
                                                  height: 38,
                                                  child: WidgetButton(
                                                    onTap: () async {
                                                      _removeSelection();
                                                      FocusManager
                                                          .instance.primaryFocus
                                                          ?.unfocus();
                                                      await showCameraSource(
                                                        cameraType: "chat",
                                                      );
                                                    },
                                                    borderRadius: 8,
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .camera_alt_outlined,
                                                        size: 30,
                                                        color: Color(
                                                          0xFF007BFF,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          _controller.text != "" &&
                                                  _controller.text != "null"
                                              ? const SizedBox.shrink()
                                              : SizedBox(
                                                  width: 38,
                                                  height: 38,
                                                  child: WidgetButton(
                                                    onTap: () async {
                                                      _removeSelection();
                                                      FocusManager
                                                          .instance.primaryFocus
                                                          ?.unfocus();
                                                      try {
                                                        final ImagePicker
                                                            picker =
                                                            ImagePicker();
                                                        final XFile? image =
                                                            await picker
                                                                .pickImage(
                                                          source: ImageSource
                                                              .gallery,
                                                        );
                                                        if (image != null) {
                                                          chatFile = await image
                                                              .readAsBytes();
                                                          Get.forceAppUpdate();
                                                        }
                                                      } catch (e) {
                                                        if (showParseText) {
                                                          debugPrint(
                                                            "Error picking image: $e",
                                                          );
                                                        }
                                                      }
                                                    },
                                                    borderRadius: 8,
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.image_outlined,
                                                        size: 30,
                                                        color: Color(
                                                          0xFF007BFF,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          _controller.text != "" &&
                                                  _controller.text != "null"
                                              ? const SizedBox.shrink()
                                              : const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _controller,
                                              decoration: InputDecoration(
                                                filled: true,
                                                border:
                                                    const OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.all(
                                                    Radius.circular(
                                                      8,
                                                    ),
                                                  ),
                                                  borderSide: BorderSide.none,
                                                ),
                                                fillColor: Colors.grey.shade200,
                                              ),
                                              onTap: () {
                                                _removeSelection();
                                              },
                                              onSubmitted: (message) async {
                                                if (!vm.isBusy &&
                                                    message != "" &&
                                                    message != "null") {
                                                  await vm.sendMessage(
                                                    ChatMessage(
                                                      text: message,
                                                      user: widget
                                                          .chatEntity.mainUser!
                                                          .toChatUser(),
                                                      createdAt: DateTime.now()
                                                          .toUtc(),
                                                    ),
                                                  );
                                                  _controller.clear();
                                                }
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: SizedBox(
                                              width: 49,
                                              height: 49,
                                              child: WidgetButton(
                                                onTap: () async {
                                                  if (!vm.isBusy &&
                                                      _controller.text != "" &&
                                                      _controller.text !=
                                                          "null") {
                                                    await vm.sendMessage(
                                                      ChatMessage(
                                                        text: _controller.text,
                                                        user: widget.chatEntity
                                                            .mainUser!
                                                            .toChatUser(),
                                                        createdAt:
                                                            DateTime.now()
                                                                .toUtc(),
                                                      ),
                                                    );
                                                    _controller.clear();
                                                  }
                                                },
                                                borderRadius: 8,
                                                child: Center(
                                                  child: vm.isBusy
                                                      ? const CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        )
                                                      : Icon(
                                                          Icons.send,
                                                          size: 30,
                                                          color: _controller
                                                                          .text ==
                                                                      "" ||
                                                                  _controller
                                                                          .text ==
                                                                      "null"
                                                              ? Colors.grey
                                                              : const Color(
                                                                  0xFF007BFF,
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
                                ],
                              );
                            } catch (e) {
                              return const SizedBox.shrink();
                            }
                          }),
                          chatFile == null
                              ? const SizedBox.shrink()
                              : Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height: MediaQuery.of(context)
                                            .size
                                            .width
                                            .clamp(0, 500),
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            fit: BoxFit.cover,
                                            image: MemoryImage(chatFile!),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 20,
                                        right: 20,
                                        bottom: 20,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 55,
                                                child: WidgetButton(
                                                  onTap: () async {
                                                    chatFile = null;
                                                  },
                                                  mainColor: Colors.red,
                                                  useDefaultHoverColor: false,
                                                  borderRadius: 8,
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
                                                          "Cancel",
                                                          style: TextStyle(
                                                            fontSize: 18,
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
                                                  onTap: () async {
                                                    vm.setBusy(true);
                                                    try {
                                                      await OrderRequest()
                                                          .postMedia(
                                                        widget.order.id!,
                                                        "driver",
                                                      );
                                                      await OrderRequest()
                                                          .getMedia(
                                                        widget.order.id!,
                                                      );
                                                      if (mediaList
                                                              .isNotEmpty &&
                                                          !vm.messages.any(
                                                            (message) =>
                                                                message.text.contains(
                                                                    mediaList
                                                                        .last
                                                                        .photoUrl!) &&
                                                                message.user
                                                                        .id ==
                                                                    "${AuthService.currentUser?.id}",
                                                          )) {
                                                        await vm.sendMessage(
                                                          ChatMessage(
                                                            text: mediaList
                                                                .last.photoUrl!,
                                                            user: widget
                                                                .chatEntity
                                                                .mainUser!
                                                                .toChatUser(),
                                                            createdAt:
                                                                DateTime.now()
                                                                    .toUtc(),
                                                          ),
                                                        );
                                                      }
                                                      chatFile = null;
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(Get
                                                              .overlayContext!)
                                                          .clearSnackBars();
                                                      ScaffoldMessenger.of(
                                                        Get.overlayContext!,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          backgroundColor:
                                                              Colors.red,
                                                          content: Text(
                                                            "Error: $e",
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    vm.setBusy(false);
                                                  },
                                                  mainColor:
                                                      const Color(0xFF007BFF),
                                                  useDefaultHoverColor: false,
                                                  borderRadius: 8,
                                                  child: Center(
                                                    child: vm.isBusy
                                                        ? const SizedBox(
                                                            width: 30,
                                                            height: 30,
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
                                                                "Send",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 18,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
