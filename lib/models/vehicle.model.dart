import "package:pwa/utils/functions.dart";
import "package:pwa/models/vehicle_type.model.dart";

class Vehicle {
  late final int? id;
  late final String? plateNumber;
  late final String? color;
  late final String? carMake;
  late final String? carModel;
  late final VehicleType? vehicleType;

  Vehicle({
    required this.id,
    required this.plateNumber,
    required this.color,
    required this.carMake,
    required this.carModel,
    required this.vehicleType,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: parseInt(json["id"], "id"),
      plateNumber:
          parseString(json['reg_no'] ?? json['plate_number'], "plate_number"),
      color: parseString(json['color'], "color"),
      carMake: parseString(
          json['car_model']?["car_make"]?["name"] ??
              json['name']["car_make"]["name"],
          "car_make"),
      carModel: parseString(
          json['car_model']?["name"] ?? json['name']["name"], "car_model"),
      vehicleType: json["vehicle_type"] != null
          ? VehicleType.fromJson(json["vehicle_type"])
          : null,
    );
  }

  String get vehicleInfo {
    return "${capitalizeWords(carModel)} (${capitalizeWords(color)})";
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "reg_no": plateNumber,
        "plate_number": plateNumber,
        "color": color,
        "name": {
          "name": carModel,
          "car_make": {
            "name": carMake,
          }
        },
        "car_model": {
          "name": carModel,
          "car_make": {
            "name": carMake,
          },
        },
        "vehicle_type": vehicleType?.toJson(),
      };
}
