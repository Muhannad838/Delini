import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/hospital.dart';
import '../../data/models/appointment.dart';
import '../../providers/settings_provider.dart';
import '../../providers/hospital_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../shared/widgets/back_button.dart';
import '../../shared/widgets/accessibility_banner.dart';
import '../../shared/widgets/navigation_map_widget.dart';
import '../../core/l10n/l10n_utils.dart';
import 'widgets/create_appointment_sheet.dart';
import 'widgets/appointment_card.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  Appointment? _navigatingTo;
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    super.dispose();
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => const CreateAppointmentSheet(),
    );
  }

  void _navigateToAppointment(Appointment appointment) {
    final repo = ref.read(hospitalRepositoryProvider);
    Destination? dest;

    // Try exact destinationId first (legacy records)
    if (appointment.destinationId != null) {
      dest = repo.findDestinationById(appointment.destinationId!);
    }

    // Fallback: fuzzy match clinicName against destination names
    if (dest == null && appointment.clinicName.isNotEmpty) {
      final hospital = repo.getById(appointment.hospitalId);
      if (hospital != null) {
        final clinicLower = appointment.clinicName.toLowerCase();
        for (final d in hospital.allDestinations) {
          if (d.name.en.toLowerCase().contains(clinicLower) ||
              d.name.ar.contains(appointment.clinicName)) {
            dest = d;
            break;
          }
        }
      }
    }

    if (dest != null) {
      final hospital = repo.getById(appointment.hospitalId);
      if (hospital != null) {
        ref.read(settingsProvider.notifier).setDefaultHospitalId(hospital.id);
        ref.read(selectedFloorProvider.notifier).state = dest.floor;
        ref.read(selectedDestinationProvider.notifier).state = dest;
      }
    }
    setState(() => _navigatingTo = appointment);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final appointmentsAsync = ref.watch(appointmentProvider);
    final l10n = AppLocalizations(settings.language);
    final isAccessible = settings.accessibilityMode;
    final selectedDest = ref.watch(selectedDestinationProvider);
    final isDark = settings.darkMode;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AccessibilityBanner(),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  AppBackButton(
                    onPressed: _navigatingTo != null
                        ? () => setState(() => _navigatingTo = null)
                        : () => context.go('/'),
                  ),
                  const Spacer(),
                  Text(
                    l10n.myAppointments,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isAccessible ? 20 : 17,
                    ),
                  ),
                  const Spacer(),
                  if (_navigatingTo == null)
                    IconButton(
                      onPressed: _showCreateSheet,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkBlue : AppColors.blue,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _navigatingTo != null
                  ? _buildNavigationView(settings, l10n, isAccessible, selectedDest)
                  : _buildListView(appointmentsAsync, settings, l10n, isAccessible),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationView(
    SettingsState settings,
    AppLocalizations l10n,
    bool isAccessible,
    Destination? selectedDest,
  ) {
    final routeInfo = ref.watch(routeInfoProvider);
    final isDark = settings.darkMode;
    final displayName = _navigatingTo!.clinicName.isNotEmpty
        ? _navigatingTo!.clinicName
        : (selectedDest?.name.get(settings.language) ?? '-');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.greenBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
                    ),
                    child: const Icon(Icons.local_hospital_outlined, color: AppColors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: isAccessible ? 15 : 14),
                        ),
                        if (_navigatingTo!.patientName.isNotEmpty)
                          Text(
                            _navigatingTo!.patientName,
                            style: TextStyle(
                              color: isDark ? AppColors.darkBlue : AppColors.blue,
                              fontWeight: FontWeight.w600,
                              fontSize: isAccessible ? 13 : 12,
                            ),
                          ),
                        Text(
                          '${localizeDate(DateTime.parse(_navigatingTo!.date), settings.language)} • ${localizeTime(_navigatingTo!.time, settings.language)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (routeInfo != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${localizeNumber(routeInfo.distanceMeters, settings.language)} ${l10n.meters}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isAccessible ? 15 : 14,
                            color: isDark ? AppColors.darkBlue : AppColors.blue,
                          ),
                        ),
                        Text(
                          '${localizeNumber(routeInfo.walkMinutes, settings.language)} ${l10n.minutes}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          NavigationMapWidget(
            destination: selectedDest,
            height: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    AsyncValue<List<Appointment>> appointmentsAsync,
    SettingsState settings,
    AppLocalizations l10n,
    bool isAccessible,
  ) {
    final isDark = settings.darkMode;

    return appointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (appointments) {
        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing icon — like emergency screen
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, _) {
                    return Container(
                      padding: EdgeInsets.all(16 + _pulseAnim.value * 4),
                      decoration: BoxDecoration(
                        color: AppColors.greenBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
                      ),
                      child: Icon(
                        Icons.event_note_outlined,
                        size: isAccessible ? 48 : 40,
                        color: AppColors.green,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noAppointments,
                  style: TextStyle(
                    fontSize: isAccessible ? 18 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.noAppointmentsDesc,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 220,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _showCreateSheet,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addAppointment),
                  ),
                ),
                const SizedBox(height: 24),
                // Tip banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.greenBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.appointmentTip,
                            style: TextStyle(
                              fontSize: isAccessible ? 13 : 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Tip banner at top
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.appointmentTip,
                        style: TextStyle(
                          fontSize: isAccessible ? 12 : 11,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: appointments.length,
                itemBuilder: (context, i) {
                  return AppointmentCard(
                    appointment: appointments[i],
                    onNavigate: () => _navigateToAppointment(appointments[i]),
                    onDelete: () => ref.read(appointmentProvider.notifier).remove(appointments[i].id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
