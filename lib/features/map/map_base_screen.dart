import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/hospital.dart';
import '../../data/datasources/hospital_data.dart';
import '../../providers/settings_provider.dart';
import '../../providers/hospital_provider.dart';
import '../../providers/search_provider.dart';
import '../../shared/widgets/navigation_map_widget.dart';
import '../visitor/visitor_panel.dart';
import '../appointments/appointments_panel.dart';
import '../emergency/emergency_panel.dart';
import '../settings/settings_panel.dart';
import '../voice/voice_panel.dart';
import 'widgets/popup_overlay.dart';

// ── Icon + color helpers ─────────────────────────────────────────────────────

IconData _iconForType(DestinationType type) {
  switch (type) {
    case DestinationType.clinic:
      return Icons.monitor_heart_outlined;
    case DestinationType.department:
      return Icons.grid_view_rounded;
    case DestinationType.room:
      return Icons.meeting_room_outlined;
    case DestinationType.emergency:
      return Icons.local_hospital_outlined;
  }
}

Color _colorForType(DestinationType type) {
  switch (type) {
    case DestinationType.clinic:
      return AppColors.blue;
    case DestinationType.department:
      return AppColors.green;
    case DestinationType.room:
      return AppColors.orange;
    case DestinationType.emergency:
      return AppColors.red;
  }
}

Color _chipBgForType(DestinationType type) {
  switch (type) {
    case DestinationType.clinic:
      return AppColors.blueBg;
    case DestinationType.department:
      return AppColors.greenBg;
    case DestinationType.room:
      return AppColors.orangeBg;
    case DestinationType.emergency:
      return AppColors.redBg;
  }
}

enum _PopupType { none, visitor, appointments, emergency, settings, voice }

class MapBaseScreen extends ConsumerStatefulWidget {
  const MapBaseScreen({super.key});

  @override
  ConsumerState<MapBaseScreen> createState() => _MapBaseScreenState();
}

class _MapBaseScreenState extends ConsumerState<MapBaseScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showSearchResults = false;
  bool _searchMode = false; // false = features dock, true = floor dots + search
  int? _userFloor;

  _PopupType _activePopup = _PopupType.none;
  String? _pendingVisitorRoom;
  late AnimationController _dockSlideController;
  late AnimationController _popupScaleController;

  @override
  void initState() {
    super.initState();
    _dockSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _popupScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _dockSlideController.dispose();
    _popupScaleController.dispose();
    super.dispose();
  }

  void _openPopup(_PopupType type) {
    setState(() => _activePopup = type);
    _dockSlideController.forward();
    _popupScaleController.forward();
  }

  void _closePopup() {
    _popupScaleController.reverse().then((_) {
      if (mounted) setState(() => _activePopup = _PopupType.none);
    });
    _dockSlideController.reverse();
  }

  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
    setState(() => _showSearchResults = query.isNotEmpty);
  }

  void _enterSearchMode() {
    setState(() => _searchMode = true);
    // Focus the search field after the animation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _exitSearchMode() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() {
      _searchMode = false;
      _showSearchResults = false;
    });
  }

  void _selectDestination(Destination dest) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() {
      _showSearchResults = false;
      _searchMode = false;
    });
    _showFloorPicker(dest);
  }

  void _showFloorPicker(Destination dest) {
    final settings = ref.read(settingsProvider);
    final hospital = ref.read(selectedHospitalProvider);
    final lang = settings.language;
    final l10n = AppLocalizations(lang);
    final isDark = settings.darkMode;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;

    final destFloor = hospital.floorById(dest.floor);
    final destFloorName = destFloor?.name.get(lang) ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: subtitleColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _chipBgForType(dest.type),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
                    ),
                    child: Icon(_iconForType(dest.type), color: _colorForType(dest.type), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dest.name.get(lang),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
                        Text(l10n.destinationOnFloor(destFloorName),
                          style: TextStyle(fontSize: 12, color: subtitleColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l10n.whichFloorAreYouOn,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor)),
              const SizedBox(height: 12),
              ...hospital.floors.map((f) {
                final isDestFloor = f.id == dest.floor;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: isDestFloor
                        ? (isDark ? AppColors.darkHighlight : AppColors.highlight)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _userFloor = f.id;
                          _searchMode = false;
                        });
                        ref.read(selectedFloorProvider.notifier).state = f.id;
                        ref.read(selectedDestinationProvider.notifier).state = dest;
                      },
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
                                  color: _chipBgForType(dest.type),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.5),
                                ),
                                child: Text(l10n.navigateTo,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _colorForType(dest.type))),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showHospitalPicker() {
    final settings = ref.read(settingsProvider);
    final allHospitals = ref.read(hospitalsProvider);
    final isDark = settings.darkMode;
    final currentId = settings.defaultHospitalId;
    final l10n = AppLocalizations(settings.language);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ...allHospitals.map((h) {
                final isSelected = h.id == currentId;
                return ListTile(
                  leading: Icon(Icons.local_hospital_outlined,
                    color: isSelected
                        ? (isDark ? AppColors.darkBlue : AppColors.blue)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  title: Text(h.name.get(settings.language),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                  trailing: isSelected
                      ? Icon(Icons.check, color: isDark ? AppColors.darkBlue : AppColors.blue)
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setDefaultHospitalId(h.id);
                    ref.read(selectedFloorProvider.notifier).state = 0;
                    ref.read(selectedDestinationProvider.notifier).state = null;
                    Navigator.pop(ctx);
                  },
                );
              }),
              Divider(color: isDark ? AppColors.darkDivider : AppColors.divider),
              ListTile(
                leading: Icon(Icons.add_circle_outline,
                  color: isDark ? AppColors.darkBlue : AppColors.blue),
                title: Text(l10n.addHospital,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkBlue : AppColors.blue)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/add-hospital');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final hospital = ref.watch(selectedHospitalProvider);
    // selectedDestinationProvider is watched by NavigationMapWidget directly
    final filteredDests = ref.watch(filteredDestinationsProvider);

    final isDark = settings.darkMode;
    final lang = settings.language;
    final l10n = AppLocalizations(lang);
    final isRtl = l10n.isArabic;

    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Stack(
            children: [
              // ── Map — fills entire screen ──
              Positioned.fill(
                child: NavigationMapWidget(
                  showSearchBar: false,
                  userFloor: _userFloor,
                ),
              ),

              // ── Top bar: hospital name + settings ──
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    // Hospital chip
                    GestureDetector(
                      onTap: _showHospitalPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkSurface : Colors.white).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_hospital_outlined, size: 16,
                              color: isDark ? AppColors.darkBlue : AppColors.blue),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                hospital.name.get(lang),
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down, size: 16, color: subtitleColor),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Settings gear
                    GestureDetector(
                      onTap: () => _openPopup(_PopupType.settings),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkSurface : Colors.white).withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.tune, color: textColor, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search results dropdown (above bottom dock) ──
              if (_showSearchResults && filteredDests.isNotEmpty)
                Positioned(
                  bottom: 110,
                  left: 12,
                  right: 12,
                  child: _buildSearchResults(
                    filteredDests, lang, isDark, textColor,
                    subtitleColor, cardColor, dividerColor,
                  ),
                ),

              // ── Bottom dock ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _dockSlideController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _dockSlideController.value * 300),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkSurface : Colors.white).withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _searchMode
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      // ── Default: feature buttons + search button ──
                      firstChild: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _DockButton(
                                icon: Icons.event_note_outlined,
                                label: l10n.myAppointments,
                                color: AppColors.green,
                                chipBg: AppColors.greenBg,
                                isDark: isDark,
                                onTap: () => _openPopup(_PopupType.appointments),
                              ),
                              const SizedBox(width: 8),
                              _DockButton(
                                icon: Icons.person_pin_circle_outlined,
                                label: l10n.visitPatient,
                                color: AppColors.purple,
                                chipBg: AppColors.purpleBg,
                                isDark: isDark,
                                onTap: () => _openPopup(_PopupType.visitor),
                              ),
                              const SizedBox(width: 8),
                              _DockButton(
                                icon: Icons.local_hospital_outlined,
                                label: l10n.emergency,
                                color: AppColors.red,
                                chipBg: AppColors.redBg,
                                isDark: isDark,
                                onTap: () => _openPopup(_PopupType.emergency),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Search button + mic button
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _enterSearchMode,
                                  child: Container(
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkHighlight : AppColors.highlight,
                                      borderRadius: BorderRadius.circular(21),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 14),
                                        Icon(Icons.search, size: 20, color: subtitleColor),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            l10n.searchDestination,
                                            style: TextStyle(
                                              fontSize: 14, color: subtitleColor, fontWeight: FontWeight.w400,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _openPopup(_PopupType.voice),
                                child: Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.purpleBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? Colors.white : const Color(0xFF000000), width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(Icons.mic, size: 22, color: AppColors.purple),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // ── Search mode: clinic pills + search input ──
                      secondChild: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Clinic/destination pills (like Google Maps)
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: hospital.allDestinations.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final dest = hospital.allDestinations[i];
                                final chipColor = _colorForType(dest.type);
                                return GestureDetector(
                                  onTap: () => _selectDestination(dest),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_iconForType(dest.type), size: 16, color: chipColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          dest.name.get(lang),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Search text field
                          Row(
                            children: [
                              // Back button to exit search mode
                              GestureDetector(
                                onTap: _exitSearchMode,
                                child: Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? AppColors.darkHighlight : AppColors.highlight,
                                    border: Border.all(
                                      color: isDark ? AppColors.darkBorder : AppColors.border,
                                    ),
                                  ),
                                  child: Icon(
                                    isRtl ? Icons.arrow_forward : Icons.arrow_back,
                                    size: 18, color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkHighlight : AppColors.highlight,
                                    borderRadius: BorderRadius.circular(21),
                                    border: Border.all(
                                      color: isDark ? AppColors.darkBorder : AppColors.border,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    onChanged: _onSearchChanged,
                                    style: TextStyle(color: textColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: l10n.searchDestination,
                                      hintStyle: TextStyle(color: subtitleColor, fontSize: 14),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(Icons.search, size: 18, color: subtitleColor),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 40),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? GestureDetector(
                                              onTap: () {
                                                _searchController.clear();
                                                _onSearchChanged('');
                                              },
                                              child: Icon(Icons.close, color: subtitleColor, size: 18),
                                            )
                                          : null,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Popup overlay ──
              if (_activePopup != _PopupType.none)
                PopupOverlay(
                  animation: _popupScaleController,
                  isDark: isDark,
                  title: _popupTitle(l10n),
                  onClose: _closePopup,
                  child: _buildPopupContent(l10n, isDark, lang),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _popupTitle(AppLocalizations l10n) {
    switch (_activePopup) {
      case _PopupType.visitor:
        return l10n.visitPatient;
      case _PopupType.appointments:
        return l10n.myAppointments;
      case _PopupType.emergency:
        return l10n.emergency;
      case _PopupType.settings:
        return l10n.settings;
      case _PopupType.voice:
        return l10n.voiceAssistant;
      case _PopupType.none:
        return '';
    }
  }

  Widget _buildPopupContent(AppLocalizations l10n, bool isDark, String lang) {
    switch (_activePopup) {
      case _PopupType.visitor:
        final room = _pendingVisitorRoom;
        _pendingVisitorRoom = null;
        return VisitorPanel(onClose: _closePopup, initialRoomNumber: room);
      case _PopupType.appointments:
        return AppointmentsPanel(onClose: _closePopup);
      case _PopupType.emergency:
        return EmergencyPanel(onClose: _closePopup);
      case _PopupType.settings:
        return SettingsPanel(onClose: _closePopup);
      case _PopupType.voice:
        return VoicePanel(
          onClose: _closePopup,
          onOpenPopup: (type, {String? roomNumber}) {
            _closePopup();
            Future.delayed(const Duration(milliseconds: 400), () {
              if (!mounted) return;
              switch (type) {
                case 'visitor':
                  setState(() => _pendingVisitorRoom = roomNumber);
                  _openPopup(_PopupType.visitor);
                  break;
                case 'emergency':
                  _openPopup(_PopupType.emergency);
                  break;
                case 'appointments':
                  _openPopup(_PopupType.appointments);
                  break;
              }
            });
          },
          onNavigate: (dest) {
            _closePopup();
            Future.delayed(const Duration(milliseconds: 400), () {
              if (!mounted) return;
              _selectDestination(dest);
            });
          },
        );
      case _PopupType.none:
        return const SizedBox.shrink();
    }
  }


  // ── Search results dropdown ──

  Widget _buildSearchResults(
    List<Destination> results, String lang, bool isDark,
    Color textColor, Color subtitleColor, Color cardColor, Color dividerColor,
  ) {
    final display = results.take(6).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: display.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: dividerColor, indent: 56),
        itemBuilder: (context, index) {
          final dest = display[index];
          final chipBg = _chipBgForType(dest.type);
          final chipColor = _colorForType(dest.type);
          final floorName = _floorNameForDest(dest, lang);

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(_iconForType(dest.type), color: chipColor, size: 16),
            ),
            title: Text(dest.name.get(lang),
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(floorName,
              style: TextStyle(color: subtitleColor, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, size: 18, color: subtitleColor),
            onTap: () => _selectDestination(dest),
          );
        },
      ),
    );
  }

  String _floorNameForDest(Destination dest, String lang) {
    for (final h in hospitals) {
      for (final f in h.floors) {
        if (f.id == dest.floor) return f.name.get(lang);
      }
    }
    return '';
  }
}

// ── Dock button ──

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color chipBg;
  final bool isDark;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.chipBg,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? Colors.white : const Color(0xFF000000);
    final cardColor = (isDark ? AppColors.darkSurface : Colors.white).withValues(alpha: 0.95);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.75),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
