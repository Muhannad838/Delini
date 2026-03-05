import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/l10n_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/appointment.dart';
import '../../../data/models/hospital.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/hospital_provider.dart';
import '../../../providers/appointment_provider.dart';

class CreateAppointmentSheet extends ConsumerStatefulWidget {
  const CreateAppointmentSheet({super.key});

  @override
  ConsumerState<CreateAppointmentSheet> createState() => _CreateAppointmentSheetState();
}

class _CreateAppointmentSheetState extends ConsumerState<CreateAppointmentSheet> {
  final _patientNameCtrl = TextEditingController();
  String? _selectedHospitalId;
  Destination? _selectedDest;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedHospitalId = ref.read(settingsProvider).defaultHospitalId;
  }

  @override
  void dispose() {
    _patientNameCtrl.dispose();
    super.dispose();
  }

  List<Destination> _getDestinations() {
    if (_selectedHospitalId == null) return [];
    final hospital = ref.read(hospitalRepositoryProvider).getById(_selectedHospitalId!);
    if (hospital == null) return [];
    return hospital.allDestinations;
  }

  bool get _canSave =>
      _patientNameCtrl.text.trim().isNotEmpty &&
      _selectedHospitalId != null &&
      _selectedDest != null &&
      _selectedDate != null &&
      _selectedTime != null;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.green,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.green,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _save() {
    if (!_canSave) return;

    final timeStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    final appointment = Appointment(
      id: const Uuid().v4(),
      hospitalId: _selectedHospitalId!,
      destinationId: _selectedDest!.id,
      date:
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
      time: timeStr,
      patientName: _patientNameCtrl.text.trim(),
      clinicName: _selectedDest!.name.en,
    );

    ref.read(appointmentProvider.notifier).add(appointment);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final hospitals = ref.watch(hospitalsProvider);
    final l10n = AppLocalizations(settings.language);
    final isAccessible = settings.accessibilityMode;
    final isDark = settings.darkMode;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final destinations = _getDestinations();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.addAppointment,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: isAccessible ? 22 : 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Patient Name
              Text(l10n.patientName,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: isAccessible ? 15 : 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _patientNameCtrl,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.patientNameHint,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hospital selector
              Text(l10n.selectHospital,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: isAccessible ? 15 : 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedHospitalId,
                items: hospitals
                    .map((h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(h.name.get(settings.language),
                              style: TextStyle(fontSize: isAccessible ? 15 : 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedHospitalId = v;
                    _selectedDest = null;
                  });
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Clinic / Department dropdown
              Text(l10n.clinicName,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: isAccessible ? 15 : 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedDest?.id,
                items: destinations
                    .map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(
                            '${d.name.get(settings.language)}${d.roomNumber != null ? ' (${d.roomNumber})' : ''}',
                            style: TextStyle(fontSize: isAccessible ? 15 : 13),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedDest = destinations.firstWhere((d) => d.id == v);
                  });
                },
                decoration: InputDecoration(
                  hintText: l10n.selectClinic,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Date picker
              Text(l10n.selectDate,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: isAccessible ? 15 : 13)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate != null
                            ? localizeDate(_selectedDate!, settings.language)
                            : l10n.selectDate,
                        style: TextStyle(fontSize: isAccessible ? 15 : 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time picker
              Text(l10n.selectTime,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: isAccessible ? 15 : 13)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTime != null
                            ? localizeTime(
                                '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                                settings.language)
                            : l10n.selectTime,
                        style: TextStyle(fontSize: isAccessible ? 15 : 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                      ),
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
