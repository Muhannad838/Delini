import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/appointment.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/hospital_provider.dart';
import '../../../core/l10n/l10n_utils.dart';

class AppointmentCard extends ConsumerStatefulWidget {
  final Appointment appointment;
  final VoidCallback onNavigate;
  final VoidCallback onDelete;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onNavigate,
    required this.onDelete,
  });

  @override
  ConsumerState<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends ConsumerState<AppointmentCard> {
  Timer? _timer;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final settings = ref.read(settingsProvider);
    final target = DateTime.parse('${widget.appointment.date} ${widget.appointment.time}');
    final now = DateTime.now();
    final diff = target.difference(now);

    if (!mounted) return;

    setState(() {
      if (diff.isNegative) {
        final lang = ref.read(settingsProvider).language;
        _countdown = AppLocalizations(lang).appointmentPassed;
      } else {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        final mins = diff.inMinutes % 60;
        if (days > 0) {
          _countdown = '${localizeNumber(days, settings.language)}d ${localizeNumber(hours, settings.language)}h';
        } else if (hours > 0) {
          _countdown = '${localizeNumber(hours, settings.language)}h ${localizeNumber(mins, settings.language)}m';
        } else {
          _countdown = '${localizeNumber(mins, settings.language)}m';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final repo = ref.watch(hospitalRepositoryProvider);
    final l10n = AppLocalizations(settings.language);
    final isAccessible = settings.accessibilityMode;

    final hospital = repo.getById(widget.appointment.hospitalId);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onNavigate,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row — countdown chip + delete
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.greenBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF000000), width: 1.75),
                    ),
                    child: Text(
                      _countdown,
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: isAccessible ? 11 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline, size: 16, color: AppColors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Clinic name
              Text(
                widget.appointment.clinicName.isNotEmpty
                    ? widget.appointment.clinicName
                    : '-',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isAccessible ? 14 : 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Patient name
              if (widget.appointment.patientName.isNotEmpty)
                Text(
                  widget.appointment.patientName,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkBlue : AppColors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: isAccessible ? 12 : 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 2),
              // Hospital name
              if (hospital != null)
                Text(
                  hospital.name.get(settings.language),
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),
              // Date & time
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      localizeDate(DateTime.parse(widget.appointment.date), settings.language),
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    localizeTime(widget.appointment.time, settings.language),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Navigate button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: widget.onNavigate,
                  icon: const Icon(Icons.navigation_outlined, size: 14),
                  label: Text(
                    l10n.navigateToClinic,
                    style: TextStyle(fontSize: isAccessible ? 12 : 10),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkBlue : AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
