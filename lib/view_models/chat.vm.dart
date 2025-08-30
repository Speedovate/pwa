import 'dart:async';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/models/chat.model.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatViewModel extends BaseViewModel {
  ChatViewModel(this.chatEntity) {
    initialise();
  }

  final ChatEntity chatEntity;
  CollectionReference? chatRef;
  final List<String> messageKeys = [];
  final List<ChatMessage> messages = [];

  StreamSubscription<QuerySnapshot>? chatStreamListener;

  void initialise() async {
    setBusy(true);
    try {
      chatRef = fbStore.collection("${chatEntity.path}/Activity");
      await loadAllMessages();
      listenToNewMessages();
    } catch (e) {
      debugPrint('Error initializing ChatViewModel: $e');
    }
    notifyListeners();
    setBusy(false);
  }

  loadAllMessages() async {
    setBusy(true);
    try {
      QuerySnapshot<Object?>? chatData =
          await chatRef?.orderBy("timestamp").get();
      for (var document in chatData!.docs) {
        final docData = document.data() as Map<String, dynamic>;
        ChatMessage message = toChatMessage(
          document.id,
          docData,
          chatEntity,
        );
        final msgId = document.id;
        messages.insert(0, message);
        messageKeys.insert(0, msgId);
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

   listenToNewMessages() {
    chatStreamListener?.cancel();
    chatStreamListener = chatRef!
        .orderBy("timestamp")
        .limitToLast(1)
        .snapshots(includeMetadataChanges: true)
        .skip(1)
        .listen(
      (event) {
        if (!event.metadata.hasPendingWrites) {
          for (var document in event.docChanges) {
            final docData = document.doc.data() as Map<String, dynamic>?;
            if (docData != null) {
              ChatMessage message = toChatMessage(
                document.doc.id,
                docData,
                chatEntity,
              );
              final msgId = document.doc.id;
              if (!messageKeys.contains(msgId)) {
                messages.insert(0, message);
                messageKeys.insert(0, msgId);
              }
            }
          }
          notifyListeners();
        }
      },
      onError: (error) => debugPrint('Error in message listener: $error'),
    );
  }

  sendMessage(ChatMessage message) async {
    setBusy(true);
    try {
      await chatRef?.doc().set(Chat.jsonFrom(message)).timeout(
            const Duration(
              seconds: 30,
            ),
          );
      chatEntity.onMessageSent(
        message.text,
        chatEntity,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
    } finally {
      setBusy(false);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    chatStreamListener?.cancel();
    super.dispose();
  }

  ChatMessage toChatMessage(
    String docRef,
    Map<String, dynamic> docData,
    ChatEntity chatEntity,
  ) {
    final timestampData = docData["timestamp"];
    final DateTime messageTimestamp = _parseTimestamp(timestampData);
    return ChatMessage(
      user: chatEntity.peers[docData["userId"]]?.toChatUser() ??
          ChatUser(
            id: docData["userId"] ?? "unknown",
            firstName: "",
            lastName: "",
          ),
      text: docData["text"] ?? "",
      medias: (docData["photos"] as List<dynamic>?)
              ?.map(
                (e) => ChatMedia(
                  url: (e as Map<String, dynamic>?)?['url'] ?? e.toString(),
                  fileName: "",
                  type: MediaType.image,
                ),
              )
              .toList() ??
          [],
      createdAt: messageTimestamp,
      customProperties: {
        "ref": docRef,
      },
    );
  }
}

DateTime _parseTimestamp(dynamic timestampData) {
  if (timestampData is Timestamp) {
    return timestampData.toDate();
  } else if (timestampData is Map<String, dynamic>) {
    return DateTime.fromMillisecondsSinceEpoch(
      (timestampData["seconds"] as int) * 1000,
      isUtc: true,
    );
  } else {
    return DateTime.now().toUtc();
  }
}
