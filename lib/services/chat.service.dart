import 'package:pwa/requests/chat.request.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  static sendChatMessage(String message, ChatEntity chatEntity) async {
    debugPrint(
      '[PPC_NOTIF_DEBUG] ${DateTime.now().toIso8601String()} '
      'chat service send start mainUser=${chatEntity.mainUser?.id} '
      'peerCount=${chatEntity.peers.length} bodyLength=${message.length}',
    );
    final otherPeerKey = chatEntity.peers.keys.firstWhere(
      (peerKey) => chatEntity.mainUser?.id != peerKey,
    );
    final otherPeer = chatEntity.peers[otherPeerKey];
    debugPrint(
      '[PPC_NOTIF_DEBUG] ${DateTime.now().toIso8601String()} '
      'chat service target peer=$otherPeerKey path=${chatEntity.path}',
    );
    await ChatRequest().sendNotification(
      title: "${chatEntity.mainUser?.name}",
      body: message.contains("https") ? "Sent a photo" : message,
      topic: otherPeer!.id,
      path: chatEntity.path,
      user: chatEntity.mainUser!,
      otherUser: otherPeer,
    );
    debugPrint(
      '[PPC_NOTIF_DEBUG] ${DateTime.now().toIso8601String()} '
      'chat service send complete peer=$otherPeerKey',
    );
  }
}
