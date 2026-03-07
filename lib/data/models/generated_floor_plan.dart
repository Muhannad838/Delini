import 'hospital.dart';

class GeneratedRoom {
  final String id;
  final String nameEn;
  final String nameAr;
  final String type;
  final double left, top, right, bottom;
  final String doorWall;
  final double doorStart, doorEnd;
  final double positionX, positionY;
  final String? roomNumber;
  final String fillType;

  const GeneratedRoom({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.type,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.doorWall,
    required this.doorStart,
    required this.doorEnd,
    required this.positionX,
    required this.positionY,
    this.roomNumber,
    required this.fillType,
  });

  DestinationType get destinationType {
    switch (type) {
      case 'clinic':
        return DestinationType.clinic;
      case 'emergency':
        return DestinationType.emergency;
      case 'room':
        return DestinationType.room;
      default:
        return DestinationType.department;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_en': nameEn,
    'name_ar': nameAr,
    'type': type,
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
    'door_wall': doorWall,
    'door_start': doorStart,
    'door_end': doorEnd,
    'position_x': positionX,
    'position_y': positionY,
    'room_number': roomNumber,
    'fill_type': fillType,
  };

  factory GeneratedRoom.fromJson(Map<String, dynamic> json) => GeneratedRoom(
    id: json['id'] as String,
    nameEn: json['name_en'] as String,
    nameAr: json['name_ar'] as String,
    type: json['type'] as String,
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    right: (json['right'] as num).toDouble(),
    bottom: (json['bottom'] as num).toDouble(),
    doorWall: json['door_wall'] as String? ?? 'left',
    doorStart: (json['door_start'] as num?)?.toDouble() ?? 30,
    doorEnd: (json['door_end'] as num?)?.toDouble() ?? 70,
    positionX: (json['position_x'] as num).toDouble(),
    positionY: (json['position_y'] as num).toDouble(),
    roomNumber: json['room_number'] as String?,
    fillType: json['fill_type'] as String? ?? 'normal',
  );
}

class GeneratedFloorPlan {
  final double buildingLeft, buildingTop, buildingRight, buildingBottom;
  final double corridorLeft, corridorTop, corridorRight, corridorBottom;
  final double entranceX, entranceY;
  final double stairsX, stairsY;
  final List<GeneratedRoom> rooms;

  /// Polygon outline points [[x1,y1], [x2,y2], ...] for irregular building shapes.
  /// If empty, falls back to the rectangular building outline.
  final List<List<double>> outlinePoints;

  const GeneratedFloorPlan({
    required this.buildingLeft,
    required this.buildingTop,
    required this.buildingRight,
    required this.buildingBottom,
    required this.corridorLeft,
    required this.corridorTop,
    required this.corridorRight,
    required this.corridorBottom,
    required this.entranceX,
    required this.entranceY,
    required this.stairsX,
    required this.stairsY,
    required this.rooms,
    this.outlinePoints = const [],
  });

  Map<String, dynamic> toJson() => {
    'building_outline': {
      'left': buildingLeft, 'top': buildingTop,
      'right': buildingRight, 'bottom': buildingBottom,
    },
    if (outlinePoints.isNotEmpty) 'building_outline_points': outlinePoints,
    'corridor': {
      'left': corridorLeft, 'top': corridorTop,
      'right': corridorRight, 'bottom': corridorBottom,
    },
    'entrance': {'x': entranceX, 'y': entranceY},
    'stairs': {'x': stairsX, 'y': stairsY},
    'rooms': rooms.map((r) => r.toJson()).toList(),
  };

  factory GeneratedFloorPlan.fromJson(Map<String, dynamic> json) {
    // Defensive: Claude may use slightly different key names
    final outlineRaw = json['building_outline'] ?? json['buildingOutline'];
    final corridorRaw = json['corridor'];
    final entranceRaw = json['entrance'];

    if (outlineRaw == null || corridorRaw == null || entranceRaw == null) {
      throw FormatException(
        'Missing required fields in floor plan JSON. '
        'Got keys: ${json.keys.toList()}. '
        'building_outline=${outlineRaw != null}, corridor=${corridorRaw != null}, entrance=${entranceRaw != null}',
      );
    }

    final outline = Map<String, dynamic>.from(outlineRaw as Map);
    final corridor = Map<String, dynamic>.from(corridorRaw as Map);
    final entrance = Map<String, dynamic>.from(entranceRaw as Map);
    final stairsRaw = json['stairs'];
    final stairs = stairsRaw != null ? Map<String, dynamic>.from(stairsRaw as Map) : entrance;
    final roomsList = (json['rooms'] as List)
        .map((r) => GeneratedRoom.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    final rawPoints = json['building_outline_points'] as List?;
    final outlinePoints = rawPoints != null
        ? rawPoints.map((p) => (p as List).map((v) => (v as num).toDouble()).toList()).toList()
        : <List<double>>[];

    return GeneratedFloorPlan(
      buildingLeft: (outline['left'] as num).toDouble(),
      buildingTop: (outline['top'] as num).toDouble(),
      buildingRight: (outline['right'] as num).toDouble(),
      buildingBottom: (outline['bottom'] as num).toDouble(),
      corridorLeft: (corridor['left'] as num).toDouble(),
      corridorTop: (corridor['top'] as num).toDouble(),
      corridorRight: (corridor['right'] as num).toDouble(),
      corridorBottom: (corridor['bottom'] as num).toDouble(),
      entranceX: (entrance['x'] as num).toDouble(),
      entranceY: (entrance['y'] as num).toDouble(),
      stairsX: (stairs['x'] as num).toDouble(),
      stairsY: (stairs['y'] as num).toDouble(),
      rooms: roomsList,
      outlinePoints: outlinePoints,
    );
  }

  Floor toFloor(int floorId, String nameEn, String nameAr) {
    return Floor(
      id: floorId,
      name: LocaleString(en: nameEn, ar: nameAr),
      entrance: Position(x: entranceX, y: entranceY),
      stairsPosition: Position(x: stairsX, y: stairsY),
      destinations: rooms.map((r) => Destination(
        id: r.id,
        name: LocaleString(en: r.nameEn, ar: r.nameAr),
        type: r.destinationType,
        floor: floorId,
        position: Position(x: r.positionX, y: r.positionY),
        roomNumber: r.roomNumber,
      )).toList(),
    );
  }
}

class GeneratedFloorData {
  final int id;
  final String nameEn;
  final String nameAr;
  final GeneratedFloorPlan floorPlan;
  final String? imageBase64; // Original uploaded floor plan image

  const GeneratedFloorData({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.floorPlan,
    this.imageBase64,
  });

  Floor toFloor() => floorPlan.toFloor(id, nameEn, nameAr);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_en': nameEn,
    'name_ar': nameAr,
    'floor_plan': floorPlan.toJson(),
    if (imageBase64 != null) 'image_base64': imageBase64,
  };

  factory GeneratedFloorData.fromJson(Map<String, dynamic> json) => GeneratedFloorData(
    id: json['id'] as int,
    nameEn: json['name_en'] as String,
    nameAr: json['name_ar'] as String,
    floorPlan: GeneratedFloorPlan.fromJson(Map<String, dynamic>.from(json['floor_plan'] as Map)),
    imageBase64: json['image_base64'] as String?,
  );
}

class GeneratedHospital {
  final String id;
  final String nameEn;
  final String nameAr;
  final String addressEn;
  final String addressAr;
  final List<GeneratedFloorData> floors;

  const GeneratedHospital({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.addressEn,
    required this.addressAr,
    required this.floors,
  });

  Hospital toHospital() => Hospital(
    id: id,
    name: LocaleString(en: nameEn, ar: nameAr),
    address: LocaleString(en: addressEn, ar: addressAr),
    floors: floors.map((f) => f.toFloor()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_en': nameEn,
    'name_ar': nameAr,
    'address_en': addressEn,
    'address_ar': addressAr,
    'floors': floors.map((f) => f.toJson()).toList(),
  };

  factory GeneratedHospital.fromJson(Map<String, dynamic> json) => GeneratedHospital(
    id: json['id'] as String,
    nameEn: json['name_en'] as String,
    nameAr: json['name_ar'] as String,
    addressEn: json['address_en'] as String? ?? '',
    addressAr: json['address_ar'] as String? ?? '',
    floors: (json['floors'] as List)
        .map((f) => GeneratedFloorData.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList(),
  );
}
