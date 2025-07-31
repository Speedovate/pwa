import 'package:pwa/utils/functions.dart';

class Banner {
  Banner({
    this.id,
    this.link,
    this.photo,
  });

  int? id;
  String? link;
  String? photo;

  factory Banner.fromJson(Map<String, dynamic> json) => Banner(
        id: parseInt(json["id"], "id"),
        link: parseString(json["link"], "link"),
        photo: parseString(json["photo"], "photo"),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "link": link,
        "photo": photo,
      };
}
