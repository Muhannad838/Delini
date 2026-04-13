# Delni (دلني) — Hospital Indoor Navigation App
## Complete Application Prompt: A-Z

---

## 1. WHAT IS DELNI?

Delni (Arabic: دلني, meaning "Guide me") is a hospital indoor navigation app built for Saudi Arabian hospitals. It helps patients — especially elderly and first-time visitors — find their way inside large hospital buildings. The app runs on Flutter, targets iPhone (iOS) as the primary platform, and also runs on Chrome for development/testing.

**Core Problem**: Hospitals are confusing. Patients get lost, miss appointments, panic during emergencies. Delni solves this with:
- Interactive isometric floor plan maps with animated navigation paths
- Voice commands in English and Arabic ("Take me to cardiology")
- AI-powered floor plan generation from uploaded images
- Appointment management with countdown timers and navigate-to-clinic
- Emergency mode with one-tap navigation to the ER
- Visitor mode to find patient rooms

---

## 2. DESIGN SYSTEM: NOTION-INSPIRED

The UI follows a clean, Notion-inspired design language with warm grays and colored accent chips.

### Color Palette

| Role | Light Mode | Dark Mode |
|------|-----------|-----------|
| Background | #FFFFFF | #191919 |
| Surface | #FFFFFF | #202020 |
| Highlight | #F7F6F3 | #2F2F2F |
| Text Primary | #37352F | #E3E2E0 |
| Text Secondary | #787774 | #9B9A97 |
| Border/Divider | #E3E2DE | #363636 |

### Accent Colors (same in light & dark)

| Color | Hex | Usage |
|-------|-----|-------|
| Blue | #2EAADC | Primary actions, navigation paths, clinics |
| Red | #EB5757 | Emergency, errors, destructive actions |
| Green | #4DAB9A | Appointments, success states |
| Yellow | #CBBB2F | Accessibility mode, warnings |
| Purple | #9065B0 | Voice commands, visitor mode |
| Orange | #D9730D | Secondary highlights |
| Pink | #E255A1 | Accent |

### Chip Backgrounds (light tints)

| Color | Hex | Usage |
|-------|-----|-------|
| Blue Bg | #D3E5EF | Clinic rooms on map |
| Red Bg | #FFE2DD | Emergency rooms on map |
| Green Bg | #DBEDDB | Appointment chips |
| Yellow Bg | #FDECC8 | Accessibility highlights |
| Purple Bg | #E8DEEE | Visitor mode chips |

### Typography
- **Font**: Readex Pro (Google Fonts) — designed for Latin + Arabic in one family
- **Weights**: w400 (body), w500 (titles), w600 (headings), w700 (buttons/bold)
- **Sizes**: 12px (small) / 14px (body) / 15px (large body) / 17px (heading small) / 20px (heading medium) / 26px (heading large)

### Visual Style
- Cards: 10px border-radius, 1.75px borders, 0 elevation
- Buttons: 8px border-radius, 1.75px borders, w700 text
- Input fields: 8px border-radius, 1.75px borders (2.25px focused)
- Chips: 6px border-radius, 1.75px borders
- Material 3 enabled

---

## 3. TECH STACK

| Concern | Package | Version |
|---------|---------|---------|
| Framework | Flutter | Latest stable |
| State management | flutter_riverpod | ^2.4.9 |
| Navigation | go_router | ^13.1.0 |
| Local DB | hive_ce + hive_ce_flutter | ^2.6.0 / ^2.1.0 |
| Settings | shared_preferences | ^2.2.2 |
| Fonts | google_fonts | ^6.1.0 |
| UUID | uuid | ^4.3.3 |
| i18n | intl + flutter_localizations | ^0.20.2 |
| HTTP | http | ^1.2.0 |
| Image picker | image_picker | ^1.1.0 |
| Voice | speech_to_text | ^6.6.2 |
| Floor plans | CustomPaint (no external pkg) | — |
| Backend | shelf + shelf_router | Dart server |

---

## 4. PROJECT STRUCTURE

```
lib/
  main.dart                              # Entry: Hive init, ProviderScope
  app.dart                               # MaterialApp.router, theme/locale binding

  core/
    theme/
      app_colors.dart                    # Notion-inspired color palette
      app_theme.dart                     # Light + dark ThemeData (Material 3)
      app_typography.dart                # Readex Pro text theme
    l10n/
      app_localizations.dart             # Custom inline l10n (~100+ strings EN/AR)
      l10n_utils.dart                    # Arabic numerals, date/time formatting, RTL
    router/
      app_router.dart                    # GoRouter: 2 routes (/, /add-hospital)
    constants/
      app_constants.dart                 # Walking speed (1.4 m/s), animation durations

  data/
    models/
      hospital.dart                      # Hospital, Floor, Destination, Position, LocaleString, DestinationType
      appointment.dart                   # Hive-serializable Appointment + hand-written TypeAdapter
      generated_floor_plan.dart          # GeneratedRoom, GeneratedFloorPlan, GeneratedFloorData, GeneratedHospital
    repositories/
      hospital_repository.dart           # Hospital lookup, room search, generated hospital injection
      appointment_repository.dart        # Hive CRUD for appointments
      settings_repository.dart           # SharedPreferences wrapper
      generated_hospital_repository.dart # Hive CRUD for AI-generated hospitals
    datasources/
      hospital_data.dart                 # Hardcoded: 2 hospitals, 3 floors each, ~20 destinations
    services/
      floor_plan_api_service.dart        # POST /analyze-floor-plan
      voice_command_service.dart          # POST /voice-command

  providers/
    settings_provider.dart               # Language, darkMode, accessibilityMode, notifications, defaultHospitalId
    hospital_provider.dart               # Selected hospital/floor/destination state
    navigation_provider.dart             # RouteInfo (distance, walk time)
    appointment_provider.dart            # AsyncNotifier with Hive persistence
    search_provider.dart                 # Search query + filtered destinations
    generated_hospital_provider.dart     # Generated hospitals + painter registration

  features/
    map/
      map_base_screen.dart               # MAIN HUB: full-screen map + bottom dock + popup overlays (~840 lines)
      map_screen.dart                    # (legacy, unused)
      painters/
        navigation_path_painter.dart     # Animated path with arrows + pulse
    home/
      home_screen.dart                   # Feature cards (legacy)
      widgets/feature_card.dart
    appointments/
      appointments_screen.dart           # Card grid + countdown timers
      appointments_panel.dart            # Popup version
      widgets/
        create_appointment_sheet.dart    # Bottom sheet: hospital/clinic/date/time
        time_slot_grid.dart              # Time slot picker
        appointment_card.dart            # Card with countdown Timer.periodic
    visitor/
      visitor_panel.dart                 # Room search + visiting hours/rules
      visitor_screen.dart                # (legacy)
    emergency/
      emergency_panel.dart               # Pulsing icon + call 997 + route info
      emergency_screen.dart              # (legacy)
    settings/
      settings_panel.dart                # Hospital selector, dark mode, language, accessibility
      settings_screen.dart               # (legacy)
    voice/
      voice_panel.dart                   # STT + intent parsing + action execution
    add_hospital/
      add_hospital_screen.dart           # Upload floor plan images + AI generation

  shared/
    widgets/
      navigation_map_widget.dart         # Reusable map: floor plan + multi-floor nav animation
      accessibility_banner.dart          # Gold banner when accessibility enabled
      back_button.dart                   # Custom back navigation
      popup_overlay.dart                 # Popup dialog wrapper
    painters/
      floor_plan_painter.dart            # Factory re-export
      isometric_helper.dart              # Coordinate system + drawing utilities
      floor_plans/
        floor_plan_painter.dart          # Factory: returns painter for hospital+floor
        generated_floor_plan_painter.dart # AI-generated floor rendering
        kf_ground.dart                   # King Faisal Ground Floor (hardcoded)
        kf_first.dart                    # King Faisal First Floor
        kf_second.dart                   # King Faisal Second Floor
        rc_ground.dart                   # Riyadh Care Ground Floor
        rc_first.dart                    # Riyadh Care First Floor
        rc_second.dart                   # Riyadh Care Second Floor

backend/
  bin/
    server.dart                          # Shelf HTTP server: /health, /analyze-floor-plan, /voice-command
```

---

## 5. SCREENS & FEATURES IN DETAIL

### 5.1 MapBaseScreen (Main Hub)

The primary screen of the app. A full-screen interactive isometric map with a bottom dock for feature access.

**Layout:**
- Full-screen NavigationMapWidget (floor plan + animated navigation paths)
- Top bar: Hospital picker (dropdown chip, left) + Settings gear (right)
- Bottom dock: Feature buttons, search bar, microphone button

**Bottom Dock Modes:**
1. **Default**: 3 feature buttons (Appointments, Visit Patient, Emergency) + Search bar + Mic
2. **Search**: Text input + destination result pills (scrollable, max 6)
3. **Collapsed**: When a popup overlay is active

**Popup Overlays** (managed centrally):
- Appointments panel
- Visitor panel (room number search)
- Emergency panel (navigate to ER)
- Settings panel
- Voice panel (speech recognition)

**Interactions:**
- Tap destination pill → floor picker modal → navigate on map
- Tap feature button → open corresponding panel
- Tap microphone → voice panel
- Select hospital from dropdown → switch all maps
- Pinch/drag map → zoom and pan (TransformationController)

### 5.2 Appointments

**View appointments:**
- Card grid with countdown timers (days, hours, minutes remaining)
- Each card shows: clinic name, date, time, patient name
- "Navigate" button → fuzzy-matches clinic name to hospital destination → floor picker → animated path

**Create appointment:**
- Bottom sheet with: hospital selector, clinic name (free text), date picker, time slot grid, patient name
- Saved to Hive local database

**Delete appointment:**
- Swipe or tap delete on card

### 5.3 Visitor Mode

**Purpose:** Find a patient's room by room number.

**Flow:**
1. Enter room number in text field
2. App searches across ALL hospitals (room numbers, names EN/AR, destination IDs)
3. If found: show destination info + "Which floor are you on?" picker
4. Map animates path from current floor to destination (multi-floor if needed)

**Extra Info Shown:**
- Visiting hours: 10:00 AM - 12:00 PM, 4:00 PM - 9:00 PM
- 6 visiting rules (no perfume, max 2 visitors, quiet, ID required, no food, children <12 accompanied)

### 5.4 Emergency Mode

**Purpose:** One-tap navigation to the Emergency Department.

**Components:**
- Pulsing red "EMERGENCY MODE" chip (alpha animates 0.6 to 1.0)
- Large pulsing emergency icon (34px to 38px)
- Route info card (distance in meters + walking time in minutes)
- 3 numbered instructions (follow path, look for signs, staff will assist)
- Warning banner: "Call 997 for emergencies"

**Auto-activation:** On panel open, automatically finds emergency destination and starts navigation with terracotta (red) path color.

### 5.5 Voice Commands

**Purpose:** Speak a command in English or Arabic to navigate, book appointments, or trigger features.

**Flow:**
1. Tap microphone in bottom dock
2. Voice panel opens → speech recognition starts
3. Listens for 30 seconds (5-second silence pause)
4. Transcription sent to backend → Claude Sonnet parses intent
5. Action executed: navigate, visit room, emergency, create/navigate appointment

**Supported Intents:**
| Intent | Trigger Examples | Action |
|--------|-----------------|--------|
| visit | "Visit room 201", "زيارة غرفة ٢٠١" | Open visitor panel with room |
| emergency | "Emergency", "طوارئ", "someone collapsed" | Open emergency panel |
| appointment | "Book cardiology tomorrow 2pm" | Create appointment |
| navigate_appointment | "Take me to my appointment", "وين موعدي" | Navigate to existing appointment |
| navigate | "Where is the pharmacy?", "وين الصيدلية" | Select destination on map |

### 5.6 Settings

**Options:**
- Hospital selector (radio list of all hospitals including generated ones)
- Dark mode toggle
- Language: English / Arabic buttons
- Accessibility mode (gold paths, font scaling +15%)
- Notifications toggle
- About section

### 5.7 Add Hospital (AI Floor Plan Generation)

**Purpose:** Upload real floor plan images and let AI generate navigable isometric maps.

**Flow:**
1. Enter hospital name
2. Add floors (Ground Floor, First Floor, etc.)
3. Upload floor plan image per floor (gallery picker, max 1024x1024, quality 85)
4. Tap "Generate Map"
5. For each floor: image sent to backend → Claude Sonnet vision analyzes → returns JSON
6. JSON contains: building outline, corridor, rooms (position, name EN/AR, type), entrance, stairs
7. Hospital saved to Hive, registered with painter factory, appears in hospital selector

---

## 6. DATA MODELS

### Hospital
```
Hospital:
  id: String
  name: LocaleString (en, ar)
  address: LocaleString (en, ar)
  floors: List<Floor>

Floor:
  id: int
  name: LocaleString (en, ar)
  entrance: Position (x, y)
  stairsPosition: Position (x, y)
  destinations: List<Destination>

Destination:
  id: String
  name: LocaleString (en, ar)
  type: DestinationType (clinic | department | room | emergency)
  floor: int
  position: Position (x, y)
  roomNumber: String? (e.g. "101", "201")

Position: { x: double, y: double }  // percentage 0-100
LocaleString: { en: String, ar: String }
```

### Appointment
```
Appointment (Hive TypeAdapter, typeId: 0):
  id: String (UUID)
  hospitalId: String
  destinationId: String? (legacy, nullable)
  date: String (yyyy-MM-dd)
  time: String (HH:mm)
  patientName: String
  clinicName: String
```

### Generated Floor Plan
```
GeneratedRoom:
  id, nameEn, nameAr, type (clinic|department|room|emergency)
  left, top, right, bottom (bounding box, 0-100)
  doorWall (left|right|top|bottom), doorStart, doorEnd
  positionX, positionY (center point)
  roomNumber?, fillType (clinic=blue, emergency=red, normal=white)

GeneratedFloorPlan:
  buildingLeft/Top/Right/Bottom (building outline rectangle)
  corridorLeft/Top/Right/Bottom (main hallway)
  entranceX/Y, stairsX/Y
  rooms: List<GeneratedRoom>
  outlinePoints: List<List<double>> (polygon for irregular shapes like L/T/U)

GeneratedHospital:
  id (gen-{uuid:8}), nameEn, nameAr, addressEn, addressAr
  floors: List<GeneratedFloorData>
    each: id, nameEn, nameAr, floorPlan, imageBase64?
```

---

## 7. HARDCODED HOSPITAL DATA

### King Faisal Specialist Hospital (id: king-faisal)
- **Ground Floor**: Emergency Department, Main Reception, Main Pharmacy, Radiology Department
- **First Floor**: Cardiology Clinic, Neurology Clinic, Orthopedics Clinic, Room 101, Room 102
- **Second Floor**: Pediatrics Clinic, Dermatology Clinic, ICU Department, Room 201, Room 202

### Riyadh Care Hospital (id: riyadh-care)
- **Ground Floor**: Emergency Department, Laboratory
- **First Floor**: ENT Clinic, Ophthalmology Clinic
- **Second Floor**: Surgery Department

---

## 8. STATE MANAGEMENT (Riverpod)

### settingsProvider
- **Type**: NotifierProvider
- **State**: language (en/ar), darkMode, accessibilityMode, notifications, defaultHospitalId
- **Persistence**: SharedPreferences

### hospitalsProvider
- **Type**: Provider<List<Hospital>>
- **Source**: Hardcoded hospitals + generated hospitals merged

### selectedHospitalProvider
- **Type**: Provider<Hospital>
- **Derived from**: settings.defaultHospitalId + hospitalsProvider

### selectedFloorProvider
- **Type**: StateProvider<int>
- **Default**: 0 (ground floor)

### selectedDestinationProvider
- **Type**: StateProvider<Destination?>
- **Used by**: NavigationMapWidget to draw path

### appointmentProvider
- **Type**: AsyncNotifierProvider
- **Methods**: add(), remove()
- **Persistence**: Hive (appointments box)

### routeInfoProvider
- **Type**: Provider<RouteInfo?>
- **Calculates**: Distance (meters) + walk time (minutes) from entrance to destination
- **Formula**: Euclidean distance scaled to meters + 30m per floor difference

### searchQueryProvider / filteredDestinationsProvider
- **Type**: StateProvider<String> / Provider<List<Destination>>
- **Filters**: Name (EN/AR) + room number match

### generatedHospitalsProvider
- **Type**: AsyncNotifierProvider
- **Methods**: addHospital(), deleteHospital()
- **On startup**: Clears old generated hospitals, loads from Hive, registers painters

---

## 9. ISOMETRIC MAP SYSTEM

### Coordinate System
- **X axis** = depth: 0 = entrance (bottom/near viewer), 100 = far end (top)
- **Y axis** = lateral: 0 = left, 100 = right
- All values are percentages (0-100), scaled to canvas size
- Google Maps-style subtle perspective tilt (farScale = 0.88)

### IsometricHelper Methods
- `toIso(pctX, pctY, size)` — convert percentage to screen offset
- `drawIsoRoom(canvas, size, left, top, right, bottom, fill, stroke)` — draw room polygon
- `drawIsoCorridor()` — corridor with wall lines
- `drawIsoLabel()` — centered text at position
- `paintIsoDotGrid()` — background grid
- `paintIsoStairs()` — stairs marker (box + step lines + arrow)

### Paint Sequence (GeneratedFloorPlanPainter)
1. Background fill + dot grid
2. Building outline (polygon if irregular, else rectangle)
3. Corridor fill (white/light corridorColor)
4. Rooms sorted by X (far first for z-ordering)
5. Stairs marker
6. Room boxes colored by fillType (clinic=blue, emergency=red, normal=white)
7. Entrance area + label ("Entrance" / "المدخل")

### Navigation Path Animation
- Progressive path reveal: `Path.computeMetrics().extractPath(0, length * animValue)`
- Pulsing destination circle (grows + shrinks, 2000ms)
- Direction arrows every 30% along path
- Path colors: Blue (normal), Red (emergency), Yellow (accessibility)
- Corridor-following waypoints (not straight lines through walls)

### Multi-Floor Navigation
When destination is on a different floor:
1. Phase 1: Animate path to stairs on current floor
2. Phase 2: Show "Elevator" label + pulsing effect
3. Phase 3: Slide current floor out, next floor in
4. Phase 4: Animate path from stairs to destination on new floor
5. Repeat if more floors to traverse

---

## 10. BACKEND API

**Server**: Dart Shelf HTTP server running on port 8080
**Middleware**: CORS (allow all origins) + Request logging

### GET /health
```json
Response: { "status": "ok", "timestamp": "2026-03-07T..." }
```

### POST /analyze-floor-plan
**Purpose**: AI vision analysis of uploaded floor plan image

**Request:**
```json
{
  "image_base64": "base64-encoded-image",
  "hospital_name": "My Hospital",
  "floor_name": "Ground Floor",
  "floor_index": 0,
  "total_floors": 3
}
```

**Process:**
1. Detect image media type (JPEG/PNG/GIF/WebP)
2. Send to Claude Sonnet 4 vision API with detailed prompt
3. Prompt instructs: trace building shape, place small rooms along walls, identify corridor
4. Claude returns structured JSON (building outline, corridor, rooms, entrance, stairs)
5. Strip markdown fences, parse, return

**Response:** GeneratedFloorPlan JSON

**Claude Prompt Rules:**
- Rooms EXACTLY 15 units wide, 25-28 tall
- Rooms line outer walls (like shelves), not floating
- Leave corridor center empty
- Max 6-8 rooms per floor
- Support polygon outlines for L/T/U shaped buildings
- door_wall faces corridor
- fillType: clinic (blue), emergency (red), normal (white)

### POST /voice-command
**Purpose**: Parse spoken text into navigation intent

**Request:**
```json
{
  "text": "Take me to cardiology",
  "language": "en",
  "hospital_id": "king-faisal"
}
```

**Response:**
```json
{
  "action": "navigate",
  "destination_id": "cardiology-1f",
  "room_number": null,
  "clinic_name": "Cardiology Clinic",
  "date": null,
  "time": null,
  "patient_name": null,
  "response_text": "I'll guide you to the Cardiology Clinic on the first floor.",
  "response_text_ar": "سأرشدك إلى عيادة القلب في الطابق الأول."
}
```

**Action Types:**
| Action | Meaning |
|--------|---------|
| visit | Visit patient in room |
| emergency | Go to ER |
| appointment | Create new appointment |
| navigate_appointment | Go to existing appointment |
| navigate | Go to specific department/clinic |
| unknown | Could not determine intent |

---

## 11. LOCALIZATION

### Approach
- Custom `AppLocalizations` class (no codegen, no ARB pipeline)
- Helper method `_t(en, ar)` returns correct string based on language
- ~100+ strings covering all features
- Languages: English (en), Arabic (ar) with full RTL support

### Key String Categories
- Navigation: search, floor labels, directions
- Appointments: create, delete, countdown, clinic names
- Visitor: room number, visiting hours, 6 visiting rules
- Emergency: emergency mode, call 997, route info
- Settings: language, dark mode, accessibility, about
- Voice: voice assistant labels
- Add Hospital: hospital name, upload, analyzing progress, success
- Dynamic: `goToFloor(name)`, `destinationOnFloor(floor)`, `remaining(count)`, `analyzingFloor(name, current, total)`

### Utilities (l10n_utils.dart)
- Arabic numeral conversion (0-9 to ٠-٩)
- Localized date formatting
- Localized time formatting
- RTL text direction detection

---

## 12. ACCESSIBILITY

- **Font Scaling**: +15% (1.15x multiplier) when accessibility mode enabled
- **Gold Paths**: Navigation paths turn gold (#CBBB2F) in accessibility mode
- **Accessibility Banner**: Gold bar at top of screen when enabled
- **Icon Sizes**: Increase (16px to 18px, 22px to 24px)
- **Dark Mode**: Full light/dark theme support across all screens
- **RTL**: Complete Arabic RTL layout support
- **Elderly-Friendly**: Voice commands, large touch targets, simple language

---

## 13. ANIMATION PATTERNS

### Pulse Animation (used across panels)
```
Duration: 1500ms, repeat with reverse
Effect: Container padding grows 16 to 20px (breathing circle)
Used in: Emergency, Visitor, Appointments (empty state), Home
```

### Path Animation
```
Duration: 1500ms forward
Effect: Progressive path reveal via Path.computeMetrics().extractPath()
Destination: Pulsing circle (2000ms repeat)
Arrows: Every 30% along path
```

### Dock/Popup Transitions
```
Dock: Slide up/down (Transform.translate, 250ms)
Popups: Scale in/out with fade
Cross-fade: Between dock modes (search/default)
```

### Floor Transition
```
Current floor slides out (left/right based on direction)
New floor slides in from opposite side
Duration: ~500ms per floor
```

---

## 14. PERSISTENCE

| Data | Storage | Box/Key |
|------|---------|---------|
| Appointments | Hive | Box: "appointments" |
| Generated Hospitals | Hive | Box: "generated_hospitals" |
| Language | SharedPreferences | "language" |
| Dark Mode | SharedPreferences | "darkMode" |
| Accessibility | SharedPreferences | "accessibilityMode" |
| Notifications | SharedPreferences | "notifications" |
| Default Hospital | SharedPreferences | "defaultHospitalId" |

---

## 15. ENVIRONMENT & COMMANDS

```bash
# Run Flutter on Chrome (development)
flutter run -d chrome --web-port=8888

# Run backend server
cd backend && ANTHROPIC_API_KEY=your-key dart run bin/server.dart
# Backend runs on port 8080

# Analyze code
flutter analyze

# Build web
flutter build web

# Build iOS (requires full Xcode)
flutter build ipa
```

**API Keys Required:**
- `ANTHROPIC_API_KEY` — Used for both /analyze-floor-plan (vision) and /voice-command (intent parsing)

---

## 16. BUILD STATUS

- 0 compile errors
- ~45 info-level warnings (withOpacity deprecation, prefer_const_constructors)
- Runs on Chrome at port 8888
- iOS build requires full Xcode installation
- Backend serves both API endpoints and Flutter web app (from /public)

---

## 17. KEY ARCHITECTURE DECISIONS

1. **No codegen l10n** — Custom AppLocalizations avoids build_runner complexity
2. **Percentage coordinates (0-100)** — All floor plans use normalized space, scaled to any canvas
3. **Isometric perspective** — Google Maps-style subtle tilt (0.88 farScale) for visual appeal
4. **Hive for offline storage** — Appointments + generated hospitals persist locally, no server needed
5. **Claude Vision for floor plans** — AI extracts room positions from real floor plan images
6. **Modular painters** — Each floor plan is a separate CustomPainter; generated ones share one painter class
7. **Shared NavigationMapWidget** — Reused across Map, Visitor, Emergency to avoid duplication
8. **Popup overlay system** — All panels (visitor/appointments/emergency/settings/voice) managed in MapBaseScreen
9. **Multi-floor state machine** — Navigation broken into phases (path -> stairs -> slide -> path)
10. **Hand-written Hive TypeAdapter** — No code generation needed for appointment serialization
