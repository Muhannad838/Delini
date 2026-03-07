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
    print('WARNING: ANTHROPIC_API_KEY not set. /voice-command will fail.');
  }
  // Gemini key no longer needed — using Claude for vision analysis

  final router = Router();

  router.get('/health', (Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Analyze floor plan — uses Claude Sonnet vision
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

      print('Analyzing floor plan (Claude): $hospitalName - $floorName (floor $floorIndex of $totalFloors)');

      final mediaType = _guessMediaType(imageBase64);

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
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mediaType,
                    'data': imageBase64,
                  },
                },
                {
                  'type': 'text',
                  'text': 'Analyze the actual floor plan image carefully. Extract real room positions from what you SEE. Return ONLY valid JSON, no markdown fences, no explanation.\n\n${_buildPrompt(hospitalName, floorName, floorIndex, totalFloors)}',
                },
              ],
            },
          ],
        }),
      );

      if (anthropicResponse.statusCode != 200) {
        print('Claude API error: ${anthropicResponse.statusCode} ${anthropicResponse.body}');
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

      // Strip markdown fences just in case
      responseText = responseText.trim();
      if (responseText.startsWith('```')) {
        responseText = responseText.replaceFirst(RegExp(r'^```\w*\n?'), '');
        responseText = responseText.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final floorPlanJson = jsonDecode(responseText) as Map<String, dynamic>;

      // Log the keys so we can debug missing fields
      print('Claude response keys: ${floorPlanJson.keys.toList()}');
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

Our app renders maps in isometric perspective. Your job: look at the image, trace the building shape, and place SMALL rooms along the walls — exactly like copying the floor plan layout into our drawing style.

## COORDINATE SYSTEM
- X axis = depth: 0 = entrance (bottom of isometric view), 100 = far end (top)
- Y axis = lateral: 0 = left, 100 = right
- All values are percentages (0-100)

## STEP 1: TRACE THE BUILDING SHAPE
Look at the building outline in the image. Is it rectangular or irregular?

**Rectangular building:** Use building_outline { left:3, top:8, right:97, bottom:92 }

**Irregular building (L-shape, T-shape, U-shape, wings):** Provide "building_outline_points" — a clockwise polygon [[x1,y1], [x2,y2], ...] that traces the actual perimeter. Example for an L-shaped building:
  [[5,8], [5,55], [50,55], [50,92], [97,92], [97,8]]
Keep it to 6-10 vertices. This polygon IS the building — rooms go INSIDE it.

## STEP 2: CORRIDOR
The corridor is the main hallway running through the building spine.
- For rectangular buildings: typically { left:24, top:8, right:82, bottom:92 }
- For irregular buildings: the corridor follows the longest internal path

## STEP 3: PLACE ROOMS — SMALL BOXES ALONG THE WALLS
Rooms are SMALL rectangles placed along the outer walls of the building, with doors facing the corridor. Think of rooms as shelves lining the walls.

**CRITICAL SIZE RULES:**
- Each room must be EXACTLY 15 units wide and 25-28 units tall (or vice versa)
- Rooms line the OUTER WALLS, not floating in the middle
- Leave the corridor CENTER empty (that's where people walk)
- Rooms must NOT overlap — leave 2-4 unit gaps between them
- Maximum 6-8 rooms

**For rectangular buildings, rooms go in 2 rows:**
- LEFT wall rooms: X from 8 to 23 (15 wide), stacked vertically (Y: 8-35, 38-65, 68-92)
- RIGHT wall rooms: X from 82 to 97 (15 wide), stacked vertically (Y: 8-35, 38-65, 68-92)
- 1-2 rooms can sit INSIDE corridor (like reception desk or pharmacy)

**For irregular buildings (L/T/U shape), rooms line ALL wings:**
- Place rooms along each wing's outer walls
- Each wing gets 1-3 rooms depending on wing length
- Rooms face INWARD toward the corridor

## STEP 4: ENTRANCE & STAIRS
- entrance: at the main door (low X = near entrance side)
- stairs: where elevators/stairs are shown, or center of corridor

## ROOM PROPERTIES
- door_wall: wall facing corridor ("left"/"right"/"top"/"bottom")
- door_start/door_end: 30/70 (always centered)
- position_x/position_y: center of the room box
- name max 14 chars. Use "Cardiology" not "Cardiology Department"
- fill_type: "clinic" (blue), "emergency" (red), "normal" (white)
- type: "clinic", "department", "room", or "emergency"

## EXAMPLE — rectangular building (our handcrafted style):
{
  "building_outline": {"left":3,"top":8,"right":97,"bottom":92},
  "corridor": {"left":24,"top":8,"right":82,"bottom":92},
  "entrance": {"x":7,"y":50},
  "stairs": {"x":52,"y":50},
  "rooms": [
    {"id":"emergency-gf","name_en":"Emergency","name_ar":"الطوارئ","type":"emergency","left":82,"top":36,"right":97,"bottom":64,"door_wall":"left","door_start":30,"door_end":70,"position_x":90,"position_y":50,"room_number":null,"fill_type":"emergency"},
    {"id":"radiology-gf","name_en":"Radiology","name_ar":"الأشعة","type":"department","left":82,"top":8,"right":97,"bottom":36,"door_wall":"left","door_start":30,"door_end":70,"position_x":90,"position_y":22,"room_number":null,"fill_type":"clinic"},
    {"id":"pharmacy-gf","name_en":"Pharmacy","name_ar":"الصيدلية","type":"department","left":60,"top":64,"right":82,"bottom":85,"door_wall":"left","door_start":30,"door_end":70,"position_x":71,"position_y":75,"room_number":null,"fill_type":"normal"},
    {"id":"reception-gf","name_en":"Reception","name_ar":"الاستقبال","type":"department","left":24,"top":36,"right":40,"bottom":64,"door_wall":"right","door_start":30,"door_end":70,"position_x":32,"position_y":50,"room_number":null,"fill_type":"normal"},
    {"id":"clinic-gf","name_en":"Gen. Clinic","name_ar":"العيادة","type":"clinic","left":8,"top":8,"right":24,"bottom":36,"door_wall":"right","door_start":30,"door_end":70,"position_x":16,"position_y":22,"room_number":null,"fill_type":"clinic"},
    {"id":"room-101","name_en":"Room 101","name_ar":"غرفة ١٠١","type":"room","left":8,"top":40,"right":24,"bottom":68,"door_wall":"right","door_start":30,"door_end":70,"position_x":16,"position_y":54,"room_number":"101","fill_type":"normal"}
  ]
}

## EXAMPLE — L-shaped building:
{
  "building_outline": {"left":3,"top":8,"right":97,"bottom":92},
  "building_outline_points": [[5,8],[5,55],[50,55],[50,92],[97,92],[97,8]],
  "corridor": {"left":24,"top":8,"right":75,"bottom":55},
  "entrance": {"x":7,"y":30},
  "stairs": {"x":50,"y":75},
  "rooms": [
    {"id":"emergency-gf","name_en":"Emergency","name_ar":"الطوارئ","type":"emergency","left":82,"top":8,"right":97,"bottom":35,"door_wall":"left","door_start":30,"door_end":70,"position_x":90,"position_y":22,"room_number":null,"fill_type":"emergency"},
    {"id":"pharmacy-gf","name_en":"Pharmacy","name_ar":"الصيدلية","type":"department","left":82,"top":38,"right":97,"bottom":55,"door_wall":"left","door_start":30,"door_end":70,"position_x":90,"position_y":47,"room_number":null,"fill_type":"normal"},
    {"id":"clinic-gf","name_en":"Gen. Clinic","name_ar":"العيادة","type":"clinic","left":8,"top":8,"right":23,"bottom":35,"door_wall":"right","door_start":30,"door_end":70,"position_x":16,"position_y":22,"room_number":null,"fill_type":"clinic"},
    {"id":"radiology-gf","name_en":"Radiology","name_ar":"الأشعة","type":"department","left":8,"top":38,"right":23,"bottom":55,"door_wall":"right","door_start":30,"door_end":70,"position_x":16,"position_y":47,"room_number":null,"fill_type":"clinic"},
    {"id":"lab-gf","name_en":"Laboratory","name_ar":"المختبر","type":"department","left":50,"top":58,"right":65,"bottom":85,"door_wall":"right","door_start":30,"door_end":70,"position_x":58,"position_y":72,"room_number":null,"fill_type":"normal"},
    {"id":"reception-gf","name_en":"Reception","name_ar":"الاستقبال","type":"department","left":75,"top":58,"right":97,"bottom":85,"door_wall":"left","door_start":30,"door_end":70,"position_x":86,"position_y":72,"room_number":null,"fill_type":"normal"}
  ]
}

Return ONLY the JSON. No markdown fences, no explanation.
- Arabic: standard Saudi medical Arabic
- ID suffix: "-gf" ground, "-1f" first, "-2f" second
- Total floors: $totalFloors (this is floor ${floorIndex + 1})
''';
}
