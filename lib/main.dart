import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/models/appointment.dart';
import 'providers/settings_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(AppointmentAdapter());

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // One-time migration: clear old appointment data (v1 had no patientName/clinicName)
  final isV2 = prefs.getBool('hive_appointment_v2') ?? false;
  if (!isV2) {
    final box = await Hive.openBox<Appointment>('appointments');
    await box.clear();
    await box.close();
    await prefs.setBool('hive_appointment_v2', true);
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DelniApp(),
    ),
  );
}
