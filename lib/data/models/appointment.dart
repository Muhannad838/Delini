import 'package:hive_ce/hive.dart';

part 'appointment.g.dart';

@HiveType(typeId: 0)
class Appointment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String hospitalId;

  @HiveField(2)
  final String? destinationId; // nullable — legacy field

  @HiveField(3)
  final String date; // yyyy-MM-dd

  @HiveField(4)
  final String time; // HH:mm

  @HiveField(5)
  final String patientName;

  @HiveField(6)
  final String clinicName; // free text

  Appointment({
    required this.id,
    required this.hospitalId,
    this.destinationId,
    required this.date,
    required this.time,
    required this.patientName,
    required this.clinicName,
  });
}
