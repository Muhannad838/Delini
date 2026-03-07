import 'dart:convert';
import 'package:hive_ce/hive_ce.dart';
import '../models/generated_floor_plan.dart';

class GeneratedHospitalRepository {
  static const _boxName = 'generated_hospitals';

  Future<Box<String>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<String>(_boxName);
    return await Hive.openBox<String>(_boxName);
  }

  Future<List<GeneratedHospital>> getAll() async {
    final box = await _getBox();
    return box.values
        .map((json) => GeneratedHospital.fromJson(
            Map<String, dynamic>.from(jsonDecode(json) as Map)))
        .toList();
  }

  Future<void> save(GeneratedHospital hospital) async {
    final box = await _getBox();
    await box.put(hospital.id, jsonEncode(hospital.toJson()));
  }

  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
