class ChatMedia {
  ChatMedia({
    this.uploadedBy,
    this.photoUrl,
    this.label,
  });

  String? uploadedBy;
  String? photoUrl;
  String? label;

  factory ChatMedia.fromJson(Map<String, dynamic> json) => ChatMedia(
        uploadedBy: json["uploaded_by"]?.toString(),
        photoUrl: json["photo_url"]?.toString(),
        label: json["label"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "uploaded_by": uploadedBy,
        "photo_url": photoUrl,
        "label": label,
      };
}
