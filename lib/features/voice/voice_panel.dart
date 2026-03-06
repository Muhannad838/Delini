import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/hospital.dart';
import '../../data/models/appointment.dart';
import '../../data/services/voice_command_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/hospital_provider.dart';
import '../../providers/appointment_provider.dart';

enum _VoiceState { idle, listening, processing, error }

class VoicePanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final Function(String popupType, {String? roomNumber}) onOpenPopup;
  final Function(Destination dest) onNavigate;

  const VoicePanel({
    super.key,
    required this.onClose,
    required this.onOpenPopup,
    required this.onNavigate,
  });

  @override
  ConsumerState<VoicePanel> createState() => _VoicePanelState();
}

class _VoicePanelState extends ConsumerState<VoicePanel>
    with SingleTickerProviderStateMixin {
  final _service = VoiceCommandService();
  SpeechToText? _stt;

  late AnimationController _pulseAnim;
  _VoiceState _state = _VoiceState.idle;
  String _transcription = '';
  String _errorMessage = '';

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
    _stt?.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    // Create fresh STT instance each time to avoid stale state
    _stt?.stop();
    _stt = SpeechToText();

    final lang = ref.read(settingsProvider).language;

    final available = await _stt!.initialize(
      onError: (error) {
        if (mounted) {
          setState(() {
            _state = _VoiceState.error;
            _errorMessage = error.errorMsg;
          });
        }
      },
    );

    if (!available) {
      if (mounted) {
        setState(() {
          _state = _VoiceState.error;
          _errorMessage = 'mic_denied';
        });
      }
      return;
    }

    setState(() {
      _state = _VoiceState.listening;
      _transcription = '';
    });

    // Use ar-SA for Arabic (Chrome Web Speech API uses hyphens)
    final localeId = lang == 'ar' ? 'ar-SA' : 'en-US';

    await _stt!.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _transcription = result.recognizedWords);
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _processCommand(result.recognizedWords);
          }
        }
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
    );
  }

  Future<void> _processCommand(String text) async {
    _stt?.stop();
    if (!mounted) return;

    setState(() => _state = _VoiceState.processing);

    final settings = ref.read(settingsProvider);
    final hospitalId = settings.defaultHospitalId;

    try {
      final response = await _service.parseVoiceCommand(
        text: text,
        language: settings.language,
        hospitalId: hospitalId,
      );

      if (!mounted) return;

      print('[Voice] AI response: action=${response.action}, clinic=${response.clinicName}, date=${response.date}, time=${response.time}');
      // Directly open the right window — no result screen
      await _executeAction(response);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _VoiceState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _executeAction(VoiceCommandResponse result) async {
    final repo = ref.read(hospitalRepositoryProvider);

    switch (result.action) {
      case 'visit':
        widget.onOpenPopup('visitor', roomNumber: result.roomNumber);
        break;
      case 'emergency':
        widget.onOpenPopup('emergency');
        break;
      case 'appointment':
        // If AI extracted enough details, create the appointment directly
        print('[Voice] appointment fields: clinic=${result.clinicName}, date=${result.date}, time=${result.time}, patient=${result.patientName}');
        // Only need date and time — clinic name defaults to "General" if not extracted
        if (result.date != null && result.time != null) {
          final settings = ref.read(settingsProvider);
          final appointment = Appointment(
            id: const Uuid().v4(),
            hospitalId: settings.defaultHospitalId,
            destinationId: result.destinationId,
            date: result.date!,
            time: result.time!,
            patientName: result.patientName ?? '',
            clinicName: result.clinicName ?? 'General',
          );
          // Await the add so appointment is saved before opening the panel
          await ref.read(appointmentProvider.notifier).add(appointment);
          print('[Voice] appointment created successfully');
          if (!mounted) return;
          widget.onOpenPopup('appointments');
        } else {
          // Not enough details — open the form
          widget.onOpenPopup('appointments');
        }
        break;
      case 'navigate_appointment':
        // Look up user's nearest appointment and navigate to its clinic
        final appointments = ref.read(appointmentProvider).valueOrNull ?? [];
        if (appointments.isNotEmpty) {
          // Sort by date+time, find the nearest upcoming one
          final now = DateTime.now();
          final sorted = [...appointments]..sort((a, b) {
            final dtA = DateTime.tryParse('${a.date}T${a.time}') ?? now;
            final dtB = DateTime.tryParse('${b.date}T${b.time}') ?? now;
            return dtA.compareTo(dtB);
          });
          // Find first upcoming appointment
          final upcoming = sorted.where((a) {
            final dt = DateTime.tryParse('${a.date}T${a.time}');
            return dt != null && dt.isAfter(now.subtract(const Duration(hours: 1)));
          }).firstOrNull ?? sorted.last;

          print('[Voice] navigating to appointment: clinic=${upcoming.clinicName}, destId=${upcoming.destinationId}');

          // Try to find destination by destinationId first, then by clinic name
          Destination? dest;
          if (upcoming.destinationId != null) {
            dest = repo.findDestinationById(upcoming.destinationId!);
          }
          if (dest == null) {
            // Search by clinic name match — try partial matching
            final hospital = ref.read(selectedHospitalProvider);
            final clinicLower = upcoming.clinicName.toLowerCase();
            for (final d in hospital.allDestinations) {
              final nameLower = d.name.en.toLowerCase();
              if (nameLower.contains(clinicLower) ||
                  clinicLower.contains(nameLower) ||
                  d.name.ar.contains(upcoming.clinicName)) {
                dest = d;
                break;
              }
            }
            // If still no match, try word-by-word matching
            if (dest == null) {
              final words = clinicLower.split(' ').where((w) => w.length > 3).toList();
              for (final d in hospital.allDestinations) {
                final nameLower = d.name.en.toLowerCase();
                for (final word in words) {
                  if (nameLower.contains(word)) {
                    dest = d;
                    break;
                  }
                }
                if (dest != null) break;
              }
            }
          }
          if (dest != null) {
            print('[Voice] found destination: ${dest.name.en}');
            widget.onNavigate(dest);
            return;
          }
          print('[Voice] no matching destination found for clinic: ${upcoming.clinicName}');
        }
        // No appointments found — open appointments panel
        widget.onOpenPopup('appointments');
        break;
      case 'navigate':
        if (result.destinationId != null) {
          final dest = repo.findDestinationById(result.destinationId!);
          if (dest != null) {
            widget.onNavigate(dest);
            return;
          }
        }
        widget.onClose();
        break;
      default:
        // unknown — show error so they can try again
        if (mounted) {
          setState(() {
            _state = _VoiceState.error;
            _errorMessage = 'unknown';
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations(settings.language);
    final isDark = settings.darkMode;
    final isAccessible = settings.accessibilityMode;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Tip text
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.purpleBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, size: 18, color: AppColors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.voiceTip,
                  style: TextStyle(fontSize: isAccessible ? 13 : 12, color: textColor)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Main content based on state
        if (_state == _VoiceState.idle) _buildIdleState(l10n, textColor, subtitleColor, isDark),
        if (_state == _VoiceState.listening) _buildListeningState(l10n, textColor, subtitleColor, isDark),
        if (_state == _VoiceState.processing) _buildProcessingState(l10n, subtitleColor),
        if (_state == _VoiceState.error) _buildErrorState(l10n, textColor, isDark),
      ],
    );
  }

  Widget _buildIdleState(AppLocalizations l10n, Color textColor, Color subtitleColor, bool isDark) {
    return Column(
      children: [
        GestureDetector(
          onTap: _startListening,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              return Container(
                padding: EdgeInsets.all(28 + _pulseAnim.value * 8),
                decoration: BoxDecoration(
                  color: AppColors.purpleBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
                ),
                child: const Icon(Icons.mic, size: 48, color: AppColors.purple),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.tapToSpeak,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
        const SizedBox(height: 4),
        Text(l10n.voiceAssistant,
          style: TextStyle(fontSize: 12, color: subtitleColor)),
      ],
    );
  }

  Widget _buildListeningState(AppLocalizations l10n, Color textColor, Color subtitleColor, bool isDark) {
    return Column(
      children: [
        // Pulsing red mic
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            return Container(
              padding: EdgeInsets.all(24 + _pulseAnim.value * 10),
              decoration: BoxDecoration(
                color: AppColors.redBg,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
              ),
              child: const Icon(Icons.mic, size: 40, color: AppColors.red),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(l10n.listening,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red)),
        const SizedBox(height: 8),

        // Live transcription
        if (_transcription.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkHighlight : AppColors.highlight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('"$_transcription"',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: textColor),
              textAlign: TextAlign.center),
          ),

        const SizedBox(height: 16),

        // Stop button
        SizedBox(
          width: 140,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_transcription.isNotEmpty) {
                _processCommand(_transcription);
              } else {
                _stt?.stop();
                setState(() => _state = _VoiceState.idle);
              }
            },
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingState(AppLocalizations l10n, Color subtitleColor) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const SizedBox(
          width: 48, height: 48,
          child: CircularProgressIndicator(
            color: AppColors.purple,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.understanding,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: subtitleColor)),
        const SizedBox(height: 8),
        if (_transcription.isNotEmpty)
          Text('"$_transcription"',
            style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: subtitleColor)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, Color textColor, bool isDark) {
    final isMicDenied = _errorMessage == 'mic_denied';

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.redBg,
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? Colors.white : const Color(0xFF000000), width: 1.75),
          ),
          child: Icon(
            isMicDenied ? Icons.mic_off : Icons.error_outline,
            size: 36, color: AppColors.red,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isMicDenied ? l10n.micPermissionDenied : l10n.voiceError,
          style: TextStyle(fontSize: 14, color: textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _startListening,
          icon: const Icon(Icons.mic, size: 18),
          label: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}
