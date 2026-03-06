import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

/// CORS middleware — allow all origins (hackathon MVP).
Middleware corsMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      final corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '86400',
      };

      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }

      final response = await handler(request);
      return response.change(headers: corsHeaders);
    };
  };
}

/// Logging middleware.
Middleware logMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      final sw = Stopwatch()..start();
      final response = await handler(request);
      sw.stop();
      print('${request.method} ${request.requestedUri.path} → ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
      return response;
    };
  };
}

void main() async {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('WARNING: ANTHROPIC_API_KEY not set. /analyze-floor-plan will fail.');
  }

  final router = Router();

  router.get('/health', (Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Analyze floor plan
  router.post('/analyze-floor-plan', (Request request) async {
    try {
      if (apiKey == null || apiKey.isEmpty) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'ANTHROPIC_API_KEY not configured'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final imageBase64 = data['image_base64'] as String;
      final hospitalName = data['hospital_name'] as String;
      final floorName = data['floor_name'] as String;
      final floorIndex = data['floor_index'] as int;
      final totalFloors = data['total_floors'] as int;

      print('Analyzing floor plan: $hospitalName - $floorName (floor $floorIndex of $totalFloors)');

      // Call Anthropic API
      final anthropicResponse = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 4096,
          'system': 'You are a hospital floor plan analyzer. Analyze the image and return ONLY valid JSON, no markdown fences, no explanation — just the JSON object.',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': _guessMediaType(imageBase64),
                    'data': imageBase64,
                  },
                },
                {
                  'type': 'text',
                  'text': _buildPrompt(hospitalName, floorName, floorIndex, totalFloors),
                },
              ],
            },
          ],
        }),
      );

      if (anthropicResponse.statusCode != 200) {
        print('Anthropic API error: ${anthropicResponse.statusCode} ${anthropicResponse.body}');
        return Response.internalServerError(
          body: jsonEncode({
            'error': 'Claude API error',
            'status': anthropicResponse.statusCode,
            'details': anthropicResponse.body,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final anthropicData = jsonDecode(anthropicResponse.body) as Map<String, dynamic>;
      final content = anthropicData['content'] as List;
      final textBlock = content.firstWhere((b) => b['type'] == 'text');
      var responseText = textBlock['text'] as String;

      // Strip markdown code fences if present
      responseText = responseText.trim();
      if (responseText.startsWith('```')) {
        responseText = responseText.replaceFirst(RegExp(r'^```\w*\n?'), '');
        responseText = responseText.replaceFirst(RegExp(r'\n?```$'), '');
      }

      // Parse and validate JSON
      final floorPlanJson = jsonDecode(responseText);

      print('Successfully analyzed: $hospitalName - $floorName (${(floorPlanJson['rooms'] as List).length} rooms)');

      return Response.ok(
        jsonEncode(floorPlanJson),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      print('Error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Voice command — AI intent parsing
  router.post('/voice-command', (Request request) async {
    try {
      if (apiKey == null || apiKey.isEmpty) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'ANTHROPIC_API_KEY not configured'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final text = data['text'] as String;
      final language = data['language'] as String? ?? 'en';
      final hospitalId = data['hospital_id'] as String? ?? 'king-faisal';

      print('Voice command ($language): "$text"');

      final anthropicResponse = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 512,
          'system': _voiceSystemPrompt(hospitalId),
          'messages': [
            {
              'role': 'user',
              'content': text,
            },
          ],
        }),
      );

      if (anthropicResponse.statusCode != 200) {
        print('Anthropic API error: ${anthropicResponse.statusCode} ${anthropicResponse.body}');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Claude API error', 'status': anthropicResponse.statusCode}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final anthropicData = jsonDecode(anthropicResponse.body) as Map<String, dynamic>;
      final content = anthropicData['content'] as List;
      final textBlock = content.firstWhere((b) => b['type'] == 'text');
      var responseText = textBlock['text'] as String;

      responseText = responseText.trim();
      if (responseText.startsWith('```')) {
        responseText = responseText.replaceFirst(RegExp(r'^```\w*\n?'), '');
        responseText = responseText.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final resultJson = jsonDecode(responseText);
      print('Voice result: action=${resultJson['action']}, dest=${resultJson['destination_id']}');

      return Response.ok(
        jsonEncode(resultJson),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      print('Voice command error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Determine public directory path (works both locally and in Docker)
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  var publicDir = '$scriptDir/../public';
  if (!Directory(publicDir).existsSync()) {
    publicDir = '/app/public';
  }

  // Static file handler for Flutter web app
  final staticHandler = Directory(publicDir).existsSync()
      ? createStaticHandler(publicDir, defaultDocument: 'index.html')
      : null;

  // Cascade: try API routes first, then static files
  Handler appHandler;
  if (staticHandler != null) {
    final apiHandler = const Pipeline()
        .addMiddleware(corsMiddleware())
        .addMiddleware(logMiddleware())
        .addHandler(router.call);

    appHandler = (Request request) async {
      // API routes
      if (request.url.path == 'health' ||
          request.url.path == 'analyze-floor-plan' ||
          request.url.path == 'voice-command') {
        return apiHandler(request);
      }
      // Serve static files, fallback to index.html for SPA routing
      try {
        final response = await staticHandler(request);
        if (response.statusCode != 404) return response;
      } catch (_) {}
      // SPA fallback — serve index.html for any unmatched route
      return staticHandler(Request('GET', Uri.parse('/')));
    };
  } else {
    print('WARNING: public/ directory not found. Serving API only.');
    appHandler = const Pipeline()
        .addMiddleware(corsMiddleware())
        .addMiddleware(logMiddleware())
        .addHandler(router.call);
  }

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await io.serve(appHandler, InternetAddress.anyIPv4, port);
  print('Delini backend running on port ${server.port}');
  if (staticHandler != null) print('Serving Flutter web app from $publicDir');
}

String _voiceSystemPrompt(String hospitalId) {
  final hospitals = {
    'king-faisal': '''
King Faisal Specialist Hospital destinations:
- Ground Floor: Emergency Department (id: emergency-gf), Main Reception (id: reception-gf), Main Pharmacy (id: pharmacy-gf), Radiology Department (id: radiology-gf), Room 101 (id: room-101), Room 102 (id: room-102)
- First Floor: Cardiology Clinic (id: cardiology-1f), Neurology Clinic (id: neurology-1f), Orthopedics Clinic (id: orthopedics-1f)
- Second Floor: Pediatrics Clinic (id: pediatrics-2f), Dermatology Clinic (id: dermatology-2f), ICU Department (id: icu-2f), Room 201 (id: room-201), Room 202 (id: room-202)''',
    'riyadh-care': '''
Riyadh Care Hospital destinations:
- Ground Floor: Emergency Department (id: emergency-rc-gf), Laboratory (id: lab-rc-gf)
- First Floor: ENT Clinic (id: ent-rc-1f), Ophthalmology Clinic (id: ophthalmology-rc-1f)
- Second Floor: Surgery Department (id: surgery-rc-2f)''',
  };

  final hospitalContext = hospitals[hospitalId] ?? hospitals['king-faisal']!;

  return '''
You are a hospital navigation assistant for Delni (دلني), a hospital indoor navigation app in Saudi Arabia.
The user is likely elderly and may speak informally or unclearly. Interpret their intent charitably.

$hospitalContext

Today's date is ${DateTime.now().toIso8601String().substring(0, 10)}.

Return ONLY valid JSON, no markdown, no explanation:
{
  "action": "visit" | "emergency" | "appointment" | "navigate_appointment" | "navigate" | "unknown",
  "destination_id": "<id from list above, or null>",
  "room_number": "<room number if mentioned, or null>",
  "clinic_name": "<clinic name if mentioned, or null>",
  "date": "<yyyy-MM-dd format, or null>",
  "time": "<HH:mm 24h format, or null>",
  "patient_name": "<patient name if mentioned, or null>",
  "response_text": "<friendly English response, max 2 sentences, simple words for elderly>",
  "response_text_ar": "<same message in Arabic>"
}

Rules:
- "visit" = user wants to visit a patient in a room (mentions room number, visiting someone)
- "emergency" = user mentions emergency, accident, someone collapsed, urgent help, طوارئ
- "appointment" = user wants to CREATE/BOOK a new appointment. Extract ALL details: clinic name, date, time, patient name. Parse relative dates: "tomorrow" = next day, "next Sunday" = correct date, "بكرة" = tomorrow. For clinic_name, try to match the closest clinic from the hospital list above (e.g. "heart doctor" → "Cardiology Clinic", "eye" → "Eye Clinic", "bones" → "Orthopedics Clinic"). Also set destination_id to match.
- "navigate_appointment" = user wants to GO TO / be directed to an existing appointment they already have. Keywords: "take me to my appointment", "direct me to my appointment", "where is my appointment", "navigate to my appointment", "خذني لموعدي", "وين موعدي"
- "navigate" = user wants to go to a specific department/clinic/pharmacy (not a patient room, not an appointment)
- "unknown" = cannot determine intent
- Be forgiving with room numbers: "room two oh one" → room_number "201"
- Be forgiving with times: "2 PM" → "14:00", "الساعة ثلاثة" → "15:00"
- Match destination_id EXACTLY from the list above (e.g. "cardiology-1f", not "cardiology"). Use the exact id in parentheses.
- Keep response_text warm and simple — this is for elderly users
- Always provide both English and Arabic responses regardless of input language
''';
}

String _guessMediaType(String base64Data) {
  // Check first bytes for image format
  if (base64Data.startsWith('/9j/')) return 'image/jpeg';
  if (base64Data.startsWith('iVBOR')) return 'image/png';
  if (base64Data.startsWith('R0lGO')) return 'image/gif';
  if (base64Data.startsWith('UklGR')) return 'image/webp';
  return 'image/png'; // default
}

String _buildPrompt(String hospitalName, String floorName, int floorIndex, int totalFloors) {
  return '''
Analyze this hospital floor plan image for "$hospitalName" - "$floorName".

Extract all visible rooms, corridors, entrances, stairs/elevators. Map everything to a percentage-based coordinate system (0-100 for both X and Y), where:
- X axis represents depth (0 = near entrance/viewer, 100 = far end)
- Y axis represents lateral position (0 = left, 100 = right)

IMPORTANT LAYOUT RULES for our rendering system:
- Rooms should be NARROW in X (14-17 units wide) so they appear square on portrait screens
- Corridor should be WIDE in X (typically from X=24 to X=82)
- Back rooms (far from entrance) at high X values (X=80-97)
- Front rooms (near entrance) at low X values (X=8-24)
- Building outline typically: left:3, top:8, right:97, bottom:92
- Entrance position near low X (around x:7, y:50)
- Stairs/elevator near center of corridor (around x:52, y:50)

Return this exact JSON structure:
{
  "building_outline": { "left": 3, "top": 8, "right": 97, "bottom": 92 },
  "corridor": { "left": 24, "top": 8, "right": 82, "bottom": 92 },
  "entrance": { "x": 7, "y": 50 },
  "stairs": { "x": 52, "y": 50 },
  "rooms": [
    {
      "id": "unique-slug",
      "name_en": "Room Name in English",
      "name_ar": "اسم الغرفة بالعربية",
      "type": "clinic",
      "left": 82, "top": 8, "right": 97, "bottom": 36,
      "door_wall": "left",
      "door_start": 30, "door_end": 70,
      "position_x": 90, "position_y": 22,
      "room_number": "105",
      "fill_type": "clinic"
    }
  ]
}

Rules:
- type: one of "clinic", "department", "room", "emergency"
- fill_type: "clinic" (blue tint), "emergency" (red tint), "normal" (white/default)
- position_x/position_y = center of room, used for navigation destination marker
- door_wall: which wall has the door ("left", "right", "top", "bottom")
- door_start/door_end: percentage along that wall for door opening (e.g., 30 to 70 = middle 40%)
- Provide Arabic translations for all room names using standard medical Arabic
- If total_floors is 1, set stairs to same position as entrance
- Generate unique slug IDs like "emergency-gf", "cardiology-1f", "room-201"
- room_number: include if visible in the image, otherwise null
- Arrange rooms so they don't overlap
- Total floors for this hospital: $totalFloors (this is floor ${floorIndex + 1} of $totalFloors)
''';
}
