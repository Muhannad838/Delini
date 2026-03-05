import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

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

  // Root / health check
  router.get('/', (Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok', 'service': 'delini-backend', 'timestamp': DateTime.now().toIso8601String()}),
      headers: {'Content-Type': 'application/json'},
    );
  });

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

  final handler = const Pipeline()
      .addMiddleware(corsMiddleware())
      .addMiddleware(logMiddleware())
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Delini backend running on port ${server.port}');
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
