import 'package:pwa/models/peer_user.model.dart';

class ChatEntity {
  final PeerUser? mainUser;
  final Map<String, PeerUser> peers;
  final String path;
  final String? title;
  bool supportMedia = false;
  final Function(
    String message,
    ChatEntity chatEntity,
  ) onMessageSent;

  ChatEntity({
    required this.mainUser,
    required this.peers,
    required this.path,
    required this.title,
    required this.onMessageSent,
    this.supportMedia = false,
  });
}
