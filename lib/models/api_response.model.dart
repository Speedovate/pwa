class ApiResponse {
  int get totalDataCount =>
      (body is Map<String, dynamic> && body["meta"] is Map<String, dynamic>)
          ? body["meta"]["total"] ?? 0
          : 0;

  int get totalPageCount => (body is Map<String, dynamic> &&
          body["pagination"] is Map<String, dynamic>)
      ? body["pagination"]["total_pages"] ?? 0
      : 0;

  List<dynamic> get data {
    if (body is Map<String, dynamic>) {
      final payload = body["data"];
      return payload is List<dynamic> ? payload : [];
    }
    return body is List<dynamic> ? body as List<dynamic> : [];
  }

  bool get allGood => errors.isEmpty;

  bool hasError() => errors.isNotEmpty;

  bool hasData() => data.isNotEmpty;

  final int code;
  final dynamic body;
  final String message;
  final List<String> errors;

  ApiResponse({
    required this.code,
    required this.message,
    this.body,
    this.errors = const [],
  });

  factory ApiResponse.fromResponse(dynamic response) {
    final int code = response.statusCode;
    final dynamic body = response.data;
    List<String> errors = [];
    String message = "";
    final bool isHtmlString =
        body is String && body.trimLeft().toLowerCase().startsWith("<!doctype");

    switch (code) {
      case 200:
        if (isHtmlString) {
          message = "Received an HTML page instead of API JSON.";
          errors.add(message);
        } else if (body is Map<String, dynamic>) {
          message = body["message"] ?? "Success";
        } else if (body is List<dynamic>) {
          message = "List data fetched successfully";
        } else if (body is String) {
          message = body.isNotEmpty ? body : "Unexpected text response.";
          errors.add(message);
        } else {
          message = "Unexpected response format.";
          errors.add(message);
        }
        break;
      default:
        if (body is Map<String, dynamic>) {
          message = body["message"] ??
              "Whoops! Something went wrong, please contact support.";
          errors.add(message);
        } else {
          message = "Unexpected error occurred.";
          errors.add(message);
        }
        break;
    }

    return ApiResponse(
      code: code,
      message: message,
      body: body,
      errors: errors,
    );
  }
}
