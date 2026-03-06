import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;

class VoiceCommandResponse {
  final String action;
  final String? destinationId;
  final String? roomNumber;
  final String? clinicName;
  final String? date;
  final String? time;
  final String? patientName;
  final String responseTextEn;
  final String responseTextAr;

  const VoiceCommandResponse({
    required this.action,
    this.destinationId,
    this.roomNumber,
    this.clinicName,
    this.date,
    this.time,
    this.patientName,
    required this.responseTextEn,
    required this.responseTextAr,
  });

  factory VoiceCommandResponse.fromJson(Map<String, dynamic> json) {
    return VoiceCommandResponse(
      action: json['action'] as String? ?? 'unknown',
      destinationId: json['destination_id'] as String?,
      roomNumber: json['room_number'] as String?,
      clinicName: json['clinic_name'] as String?,
      date: json['date'] as String?,
      time: json['time'] as String?,
      patientName: json['patient_name'] as String?,
      responseTextEn: json['response_text'] as String? ?? '',
      responseTextAr: json['response_text_ar'] as String? ?? '',
    );
  }

  String responseText(String language) =>
      language == 'ar' ? responseTextAr : responseTextEn;
}

class VoiceCommandService {
  static String get _baseUrl =>
      kIsWeb && !kDebugMode ? '' : 'http://localhost:8080';

  Future<VoiceCommandResponse> parseVoiceCommand({
    required String text,
    required String language,
    required String hospitalId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/voice-command'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'language': language,
        'hospital_id': hospitalId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Voice command failed: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return VoiceCommandResponse.fromJson(json);
  }
}
