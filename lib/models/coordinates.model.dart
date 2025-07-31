class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates(this.latitude, this.longitude);

  factory Coordinates.fromMap(Map<String, dynamic> map) {
    return Coordinates(
      double.parse(
        (map.containsKey("latitude") ? map["latitude"] : map["lat"]).toString(),
      ),
      double.parse(
        (map.containsKey("longitude") ? map["longitude"] : map["lng"])
            .toString(),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    "latitude": latitude,
    "longitude": longitude,
  };

  @override
  String toString() => "$latitude,$longitude";
}
