import 'package:flutter/material.dart';
import 'package:pwa/requests/chat.request.dart';
import 'package:pwa/models/chat_entity.model.dart';

class ChatService {
  static sendChatMessage(String message, ChatEntity chatEntity) async {
    final otherPeerKey = chatEntity.peers.keys.firstWhere(
      (peerKey) => chatEntity.mainUser?.id != peerKey,
    );
    final otherPeer = chatEntity.peers[otherPeerKey];
    final apiResponse = await ChatRequest().sendNotification(
      title:
          "${chatEntity.mainUser?.name} (Passenger)${message.contains("https") ? "" : " sent a message"}",
      body: message.contains("https") ? "Sent a photo" : message,
      topic: otherPeer!.id,
      path: chatEntity.path,
      user: chatEntity.mainUser!,
      otherUser: otherPeer,
    );
    debugPrint("Result ==> ${apiResponse.body}");
  }
}
