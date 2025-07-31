class ApiResponse {
  int get totalDataCount =>
      (body is Map<String, dynamic>) ? body["meta"]["total"] ?? 0 : 0;

  int get totalPageCount => (body is Map<String, dynamic>)
      ? body["pagination"]["total_pages"] ?? 0
      : 0;

  List<dynamic> get data => (body is Map<String, dynamic>)
      ? body["data"] ?? []
      : (body as List<dynamic>);

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

    switch (code) {
      case 200:
        if (body is Map<String, dynamic>) {
          message = body["message"] ?? "Success";
        } else if (body is List<dynamic>) {
          message = "List data fetched successfully";
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
