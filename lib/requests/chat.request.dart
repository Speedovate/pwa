import 'package:pwa/constants/api.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/peer_user.model.dart';
import 'package:pwa/models/api_response.model.dart';

class ChatRequest extends HttpService {
  Future<ApiResponse> sendNotification({
    required String title,
    required String body,
    required String topic,
    required String path,
    required PeerUser user,
    required PeerUser otherUser,
  }) async {
    dynamic userObject = {
      "id": user.id,
      "name": user.name,
      "photo": user.image,
    };
    dynamic otherUserObject = {
      "id": otherUser.id,
      "name": otherUser.name,
      "photo": otherUser.image,
    };
    final apiResult = await post(
      Api.bookingChat,
      {
        "title": title,
        "body": body,
        "topic": topic,
        "path": path,
        "user": userObject,
        "peer": otherUserObject,
      },
    ).timeout(
      const Duration(
        seconds: 30,
      ),
    );
    return ApiResponse.fromResponse(apiResult);
  }
}
