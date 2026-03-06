import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/hospital.dart';
import '../../providers/hospital_provider.dart';
import '../../providers/settings_provider.dart';

class VisitorPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final String? initialRoomNumber;

  const VisitorPanel({super.key, required this.onClose, this.initialRoomNumber});

  @override
  ConsumerState<VisitorPanel> createState() => _VisitorPanelState();
}

class _VisitorPanelState extends ConsumerState<VisitorPanel>
    with SingleTickerProviderStateMixin {
  final _roomController = TextEditingController();
  final _roomFocusNode = FocusNode();
  late AnimationController _pulseAnim;

  // Steps: input → found (show info + floor picker) → done (close popup)
  String? _errorMessage;
  Destination? _foundDestination;
  Hospital? _foundHospital;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.initialRoomNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findRoom(widget.initialRoomNumber!);
      });
    }
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    _roomController.dispose();
    _roomFocusNode.dispose();
    super.dispose();
  }

  void _findRoom(String roomInput) {
    final trimmed = roomInput.trim();
    if (trimmed.isEmpty) return;
    final query = trimmed.toLowerCase();
    final lang = ref.read(settingsProvider).language;

    final repo = ref.read(hospitalRepositoryProvider);
    for (final hospital in repo.getAll()) {
      for (final dest in hospital.allDestinations) {
        final roomMatch = dest.roomNumber?.toLowerCase() == query;
        final nameEnMatch = dest.name.en.toLowerCase().contains(query);
        final nameArMatch = dest.name.ar.contains(trimmed);
        final idMatch = dest.id.toLowerCase().contains(query);

        if (roomMatch || nameEnMatch || nameArMatch || idMatch) {
          ref.read(settingsProvider.notifier).setDefaultHospitalId(hospital.id);
          setState(() {
            _errorMessage = null;
            _foundDestination = dest;
            _foundHospital = hospital;
          });
          return;
        }
      }
    }

    setState(() {
      _errorMessage = AppLocalizations(lang).roomNotFound;
    });
  }

  void _selectFloorAndClose(int floorId, Destination dest) {
    ref.read(selectedFloorProvider.notifier).state = floorId;
    ref.read(selectedDestinationProvider.notifier).state = dest;
    widget.onClose();
  }

  void _resetToInput() {
    setState(() {
      _errorMessage = null;
      _foundDestination = null;
      _foundHospital = null;
      _roomController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.darkMode;
    final lang = settings.language;
    final loc = AppLocalizations(lang);
    final isAccessibility = settings.accessibilityMode;
    final baseFontSize = isAccessibility ? 1.15 : 1.0;

    if (_foundDestination != null && _foundHospital != null) {
      return _buildFoundMode(
        loc: loc, isDark: isDark, lang: lang, baseFontSize: baseFontSize);
    }
    return _buildInputMode(
      loc: loc, isDark: isDark, lang: lang, baseFontSize: baseFontSize);
  }

  Widget _buildInputMode({
    required AppLocalizations loc,
    required bool isDark,
    required String lang,
    required double baseFontSize,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Pulsing icon
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            return Container(
              padding: EdgeInsets.all(14 + _pulseAnim.value * 4),
              decoration: BoxDecoration(
                color: AppColors.purpleBg,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
              ),
              child: Icon(
                Icons.person_pin_circle_outlined,
                color: AppColors.purple,
                size: baseFontSize > 1.0 ? 36 : 30,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(loc.visitorModeDesc,
            style: TextStyle(
              fontSize: 13 * baseFontSize,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center),
        ),
        const SizedBox(height: 20),

        // Room number input card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.enterRoomNumber,
                  style: TextStyle(
                    fontSize: 12 * baseFontSize, fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                const SizedBox(height: 10),
                TextField(
                  controller: _roomController,
                  focusNode: _roomFocusNode,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _findRoom,
                  style: TextStyle(fontSize: 20 * baseFontSize, fontWeight: FontWeight.w600, letterSpacing: 2),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '101',
                    hintStyle: TextStyle(
                      fontSize: 20 * baseFontSize, fontWeight: FontWeight.w400,
                      color: (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary).withValues(alpha: 0.4),
                      letterSpacing: 2),
                    prefixIcon: Icon(Icons.meeting_room_outlined,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.redBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!,
                              style: TextStyle(fontSize: 12 * baseFontSize, color: AppColors.red, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity, height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _findRoom(_roomController.text),
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(loc.findRoom,
                      style: TextStyle(fontSize: 13 * baseFontSize, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Quick access chips
        Text(loc.quickAccess,
          style: TextStyle(fontSize: 11 * baseFontSize, fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: ['101', '201', '202'].map((label) {
            return ActionChip(
              label: Text(label,
                style: TextStyle(fontSize: 12 * baseFontSize, fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkBlue : AppColors.blue)),
              avatar: Icon(Icons.meeting_room_outlined, size: 14,
                color: isDark ? AppColors.darkBlue : AppColors.blue),
              backgroundColor: isDark ? AppColors.darkHighlight : AppColors.blueBg,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onPressed: () {
                _roomController.text = label;
                _findRoom(label);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Instructions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.howItWorks,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13 * baseFontSize)),
                const SizedBox(height: 10),
                _VisitorStep(number: '1', text: loc.visitorStep1, baseFontSize: baseFontSize),
                const SizedBox(height: 6),
                _VisitorStep(number: '2', text: loc.visitorStep2, baseFontSize: baseFontSize),
                const SizedBox(height: 6),
                _VisitorStep(number: '3', text: loc.visitorStep3, baseFontSize: baseFontSize),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// After room is found: show room info, visiting hours, rules, and floor picker.
  /// Picking a floor closes the popup and the map shows the direction.
  Widget _buildFoundMode({
    required AppLocalizations loc,
    required bool isDark,
    required String lang,
    required double baseFontSize,
  }) {
    final dest = _foundDestination!;
    final hospital = _foundHospital!;
    final roomLabel = dest.roomNumber ?? '';
    final floorName = hospital.floors
        .where((f) => f.id == dest.floor)
        .map((f) => f.name.get(lang))
        .firstOrNull ?? '';
    final borderColor = isDark ? Colors.white : const Color(0xFF000000);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      children: [
        // Back to search
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _resetToInput,
            icon: const Icon(Icons.search, size: 16),
            label: Text(loc.searchAgain,
              style: TextStyle(fontSize: 12 * baseFontSize, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 6),

        // Patient Room Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.purpleBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: borderColor, width: 1.75),
                  ),
                  child: const Icon(Icons.meeting_room_outlined, color: AppColors.purple, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomLabel.isNotEmpty
                            ? '${loc.roomNumber}$roomLabel'
                            : dest.name.get(lang),
                        style: TextStyle(fontSize: 15 * baseFontSize, fontWeight: FontWeight.w700),
                      ),
                      if (roomLabel.isNotEmpty)
                        Text(dest.name.get(lang),
                          style: TextStyle(fontSize: 12 * baseFontSize,
                            color: isDark ? AppColors.darkBlue : AppColors.blue, fontWeight: FontWeight.w600)),
                      Text('$floorName • ${hospital.name.get(lang)}',
                        style: TextStyle(fontSize: 11 * baseFontSize, color: subtitleColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Visiting Hours Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppColors.green),
                    const SizedBox(width: 6),
                    Text(loc.visitingHours,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13 * baseFontSize)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.greenBg, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(Icons.wb_sunny_outlined, size: 16, color: AppColors.green),
                      const SizedBox(width: 8),
                      Text(loc.morningVisit,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12 * baseFontSize)),
                      const Spacer(),
                      Text(loc.morningHours,
                        style: TextStyle(fontSize: 12 * baseFontSize, fontWeight: FontWeight.w500, color: AppColors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blueBg, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(Icons.nightlight_outlined, size: 16,
                        color: isDark ? AppColors.darkBlue : AppColors.blue),
                      const SizedBox(width: 8),
                      Text(loc.eveningVisit,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12 * baseFontSize)),
                      const Spacer(),
                      Text(loc.eveningHours,
                        style: TextStyle(fontSize: 12 * baseFontSize, fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkBlue : AppColors.blue)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Visiting Rules Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.rule_outlined, size: 16, color: AppColors.red),
                    const SizedBox(width: 6),
                    Text(loc.visitingRules,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13 * baseFontSize)),
                  ],
                ),
                const SizedBox(height: 10),
                _VisitorStep(number: '1', text: loc.visitRule1, baseFontSize: baseFontSize),
                const SizedBox(height: 6),
                _VisitorStep(number: '2', text: loc.visitRule2, baseFontSize: baseFontSize),
                const SizedBox(height: 6),
                _VisitorStep(number: '3', text: loc.visitRule3, baseFontSize: baseFontSize),
                const SizedBox(height: 6),
                _VisitorStep(number: '4', text: loc.visitRule4, baseFontSize: baseFontSize),
                const SizedBox(height: 6),
                _VisitorStep(number: '5', text: loc.visitRule5, baseFontSize: baseFontSize),
                const SizedBox(height: 6),
                _VisitorStep(number: '6', text: loc.visitRule6, baseFontSize: baseFontSize),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Which floor are you on? (inline in popup)
        Text(loc.whichFloorAreYouOn,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * baseFontSize, color: textColor)),
        const SizedBox(height: 8),
        ...hospital.floors.map((f) {
          final isDestFloor = f.id == dest.floor;
          final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: isDestFloor
                  ? (isDark ? AppColors.darkHighlight : AppColors.highlight)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selectFloorAndClose(f.id, dest),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.layers_outlined, size: 20,
                        color: isDestFloor ? (isDark ? AppColors.darkBlue : AppColors.blue) : subtitleColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(f.name.get(lang),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                      ),
                      if (isDestFloor)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.purpleBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: Text(loc.destination,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.purple)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _VisitorStep extends StatelessWidget {
  final String number;
  final String text;
  final double baseFontSize;

  const _VisitorStep({
    required this.number,
    required this.text,
    this.baseFontSize = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20, height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.purpleBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF000000), width: 1.5),
          ),
          child: Text(number,
            style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w600,
              fontSize: 10 * baseFontSize)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12 * baseFontSize)),
        ),
      ],
    );
  }
}
