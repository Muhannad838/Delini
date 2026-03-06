import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/hospital.dart';
import '../../features/map/painters/navigation_path_painter.dart';
import '../../providers/hospital_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/settings_provider.dart';
import '../painters/floor_plans/floor_plan_painter.dart';

/// Phases of the cross-floor navigation animation.
enum _CrossFloorPhase {
  /// Animating path from entrance/stairs to stairs on current floor
  pathToStairs,

  /// Showing the "Elevator" label at the stairs position
  elevatorLabel,

  /// Sliding current floor out right, next floor in from left
  slideTransition,

  /// Animating path on the final destination floor (stairs to dest)
  pathToDest,

  /// Animation complete — show final state
  done,
}

class NavigationMapWidget extends ConsumerStatefulWidget {
  final Destination? initialDestination;
  final Destination? destination;
  final bool isEmergency;
  final bool showSearchBar;
  final double? height;

  /// The floor the user is physically on. If null, uses selectedFloorProvider.
  final int? userFloor;

  const NavigationMapWidget({
    super.key,
    this.initialDestination,
    this.destination,
    this.isEmergency = false,
    this.showSearchBar = false,
    this.height,
    this.userFloor,
  });

  @override
  ConsumerState<NavigationMapWidget> createState() =>
      _NavigationMapWidgetState();
}

class _NavigationMapWidgetState extends ConsumerState<NavigationMapWidget>
    with TickerProviderStateMixin {
  // Zoom
  final TransformationController _zoomController = TransformationController();

  // Path animation (used for both same-floor and cross-floor path segments)
  late AnimationController _pathController;
  late AnimationController _pulseController;

  // Cross-floor slide animation
  late AnimationController _slideController;

  // Elevator label fade
  late AnimationController _elevatorLabelController;

  // Track the last destination we animated for
  Destination? _lastAnimatedDest;
  int? _lastUserFloor;

  // Cross-floor state
  bool _isCrossFloor = false;
  _CrossFloorPhase _phase = _CrossFloorPhase.done;

  /// The sequence of floor IDs to traverse (e.g., [0, 1, 2] going from ground to second).
  List<int> _floorSequence = [];

  /// Index into _floorSequence for the current transition step.
  int _currentStep = 0;

  /// The floor currently being displayed (for the outgoing layer during slide).
  int _displayFloorId = 0;

  /// The next floor sliding in during the slide transition.
  int _nextFloorId = 0;

  @override
  void initState() {
    super.initState();
    _pathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _elevatorLabelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  Destination? _resolveDestination() {
    return widget.destination ??
        widget.initialDestination ??
        ref.watch(selectedDestinationProvider);
  }

  int _resolveUserFloor() {
    return widget.userFloor ?? ref.watch(selectedFloorProvider);
  }

  @override
  void didUpdateWidget(covariant NavigationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDest = oldWidget.destination ?? oldWidget.initialDestination;
    final newDest = widget.destination ?? widget.initialDestination;
    if (oldDest != newDest && newDest != null) {
      _startNavigationTo(newDest);
    }
  }

  void _startNavigationTo(Destination dest) {
    final hospital = ref.read(selectedHospitalProvider);
    final userFloor = _resolveUserFloor();

    _lastAnimatedDest = dest;
    _lastUserFloor = userFloor;

    if (dest.floor == userFloor) {
      // Same floor — simple path animation
      _isCrossFloor = false;
      _phase = _CrossFloorPhase.done;
      _displayFloorId = userFloor;
      _pathController.forward(from: 0);
    } else {
      // Cross-floor — build floor sequence and start state machine
      _isCrossFloor = true;
      _floorSequence = _buildFloorSequence(userFloor, dest.floor, hospital);
      _currentStep = 0;
      _displayFloorId = _floorSequence.first;
      _nextFloorId = _floorSequence.length > 1 ? _floorSequence[1] : _floorSequence.first;

      // Start phase 1: path to stairs on the user's floor
      _phase = _CrossFloorPhase.pathToStairs;
      _pathController.forward(from: 0).then((_) {
        if (!mounted) return;
        _onPathToStairsComplete();
      });
    }
    if (mounted) setState(() {});
  }

  /// Build the ordered list of floor IDs to traverse.
  /// e.g., userFloor=0, destFloor=2 => [0, 1, 2]
  /// e.g., userFloor=2, destFloor=0 => [2, 1, 0]
  List<int> _buildFloorSequence(int from, int to, Hospital hospital) {
    final floors = <int>[];
    if (from <= to) {
      for (int i = from; i <= to; i++) {
        if (hospital.floorById(i) != null) floors.add(i);
      }
    } else {
      for (int i = from; i >= to; i--) {
        if (hospital.floorById(i) != null) floors.add(i);
      }
    }
    return floors;
  }

  /// Called when path-to-stairs animation completes on a floor.
  void _onPathToStairsComplete() {
    // Show elevator label
    _phase = _CrossFloorPhase.elevatorLabel;
    setState(() {});
    _elevatorLabelController.forward(from: 0).then((_) {
      if (!mounted) return;
      // Hold the label for ~1 second, then start slide
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        _elevatorLabelController.reverse().then((_) {
          if (!mounted) return;
          _startSlideTransition();
        });
      });
    });
  }

  /// Slide current floor out right, next floor in from left.
  void _startSlideTransition() {
    _currentStep++;
    if (_currentStep >= _floorSequence.length) {
      // Should not happen, but safety
      _phase = _CrossFloorPhase.done;
      setState(() {});
      return;
    }

    _nextFloorId = _floorSequence[_currentStep];
    _phase = _CrossFloorPhase.slideTransition;
    setState(() {});

    _slideController.forward(from: 0).then((_) {
      if (!mounted) return;
      // Slide complete — next floor is now current
      _displayFloorId = _nextFloorId;

      // Update the selected floor provider so the bottom panel reflects the floor
      ref.read(selectedFloorProvider.notifier).state = _displayFloorId;

      if (_currentStep == _floorSequence.length - 1) {
        // We're on the destination floor — animate path from stairs to dest
        _phase = _CrossFloorPhase.pathToDest;
        setState(() {});
        _pathController.forward(from: 0).then((_) {
          if (!mounted) return;
          _phase = _CrossFloorPhase.done;
          setState(() {});
        });
      } else {
        // Intermediate floor — skip path animation, go straight to elevator label
        // (stairs to stairs on the same floor has zero distance)
        _onPathToStairsComplete();
      }
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _pathController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _elevatorLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(selectedHospitalProvider);
    final settings = ref.watch(settingsProvider);
    final dest = _resolveDestination();
    final userFloor = _resolveUserFloor();

    // Detect destination change from provider (not widget props)
    if (dest != null && (dest != _lastAnimatedDest || userFloor != _lastUserFloor)) {
      _lastAnimatedDest = dest;
      _lastUserFloor = userFloor;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startNavigationTo(dest);
      });
    }

    // Reset when destination is cleared
    if (dest == null && _lastAnimatedDest != null) {
      _lastAnimatedDest = null;
      _lastUserFloor = null;
      _isCrossFloor = false;
      _phase = _CrossFloorPhase.done;
      _pathController.reset();
      _slideController.reset();
      _elevatorLabelController.reset();
    }

    Widget mapContent;

    if (_isCrossFloor && dest != null) {
      mapContent = _buildCrossFloorMap(hospital, settings, dest, userFloor);
    } else {
      mapContent = _buildSameFloorMap(hospital, settings, dest, userFloor);
    }

    // Wrap in InteractiveViewer for pinch-to-zoom
    final zoomableMap = InteractiveViewer(
      transformationController: _zoomController,
      minScale: 0.5,
      maxScale: 4.0,
      boundaryMargin: const EdgeInsets.all(200),
      child: mapContent,
    );

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: zoomableMap);
    }
    return zoomableMap;
  }

  /// Build the standard same-floor map (path from entrance to destination).
  Widget _buildSameFloorMap(
    Hospital hospital,
    SettingsState settings,
    Destination? dest,
    int currentFloorId,
  ) {
    final floor = hospital.floorById(currentFloorId);
    if (floor == null) {
      return const Center(child: Text('Floor not found'));
    }

    final showPath = dest != null && dest.floor == currentFloorId;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: getFloorPlanPainter(
              hospitalId: hospital.id,
              floorId: currentFloorId,
              darkMode: settings.darkMode,
              locale: settings.language,
            ),
          ),
        ),
        if (showPath)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pathController, _pulseController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: NavigationPathPainter(
                    entrance: floor.entrance,
                    destination: dest.position,
                    progress: _pathController.value,
                    pulseValue: _pulseController.value,
                    isEmergency: widget.isEmergency,
                    isAccessibility: settings.accessibilityMode,
                    darkMode: settings.darkMode,
                  ),
                );
              },
            ),
          ),
        if (showPath && _pathController.value >= 1.0)
          _buildRouteInfo(floor, dest, settings),
      ],
    );
  }

  /// Build the cross-floor animated map.
  Widget _buildCrossFloorMap(
    Hospital hospital,
    SettingsState settings,
    Destination dest,
    int userFloor,
  ) {
    return ClipRect(
      child: Stack(
        children: [
          // During slide transition, show two layers
          if (_phase == _CrossFloorPhase.slideTransition)
            ..._buildSlideTransitionLayers(hospital, settings, dest)
          else
            // Single floor layer (current display floor)
            Positioned.fill(
              child: _buildFloorLayer(
                hospital, settings, _displayFloorId, dest,
              ),
            ),

          // Elevator label overlay
          if (_phase == _CrossFloorPhase.elevatorLabel)
            _buildElevatorLabel(hospital, settings),

          // Route info when done
          if (_phase == _CrossFloorPhase.done) ...[
            () {
              final destFloor = hospital.floorById(dest.floor);
              if (destFloor != null && _pathController.value >= 1.0) {
                return _buildRouteInfo(destFloor, dest, settings,
                    floorDifference: (_floorSequence.length - 1).abs());
              }
              return const SizedBox.shrink();
            }(),
          ],
        ],
      ),
    );
  }

  /// Build a single floor layer with optional path overlay.
  Widget _buildFloorLayer(
    Hospital hospital,
    SettingsState settings,
    int floorId,
    Destination dest,
  ) {
    final floor = hospital.floorById(floorId);
    if (floor == null) return const SizedBox.shrink();

    // Determine what path to draw based on current phase and floor
    final bool drawPath;
    Position pathFrom;
    Position pathTo;

    if (_phase == _CrossFloorPhase.pathToStairs) {
      // Path from entrance (or stairs if intermediate) to stairs
      drawPath = floorId == _displayFloorId;
      if (_currentStep == 0) {
        // First floor — from entrance to stairs
        pathFrom = floor.entrance;
      } else {
        // Intermediate floor — from stairs to stairs (effectively a short segment)
        pathFrom = floor.stairsPosition;
      }
      pathTo = floor.stairsPosition;
    } else if (_phase == _CrossFloorPhase.pathToDest) {
      // On destination floor — from stairs to destination
      drawPath = floorId == dest.floor;
      pathFrom = floor.stairsPosition;
      pathTo = dest.position;
    } else if (_phase == _CrossFloorPhase.done) {
      // Show complete path on destination floor
      drawPath = floorId == dest.floor;
      pathFrom = floor.stairsPosition;
      pathTo = dest.position;
    } else {
      drawPath = false;
      pathFrom = floor.entrance;
      pathTo = floor.stairsPosition;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: getFloorPlanPainter(
              hospitalId: hospital.id,
              floorId: floorId,
              darkMode: settings.darkMode,
              locale: settings.language,
            ),
          ),
        ),
        if (drawPath)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pathController, _pulseController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: NavigationPathPainter(
                    entrance: pathFrom,
                    destination: pathTo,
                    progress: _pathController.value,
                    pulseValue: _pulseController.value,
                    isEmergency: widget.isEmergency,
                    isAccessibility: settings.accessibilityMode,
                    darkMode: settings.darkMode,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Build the two sliding layers for the floor transition.
  List<Widget> _buildSlideTransitionLayers(
    Hospital hospital,
    SettingsState settings,
    Destination dest,
  ) {
    return [
      // Outgoing floor — slides out to the right
      AnimatedBuilder(
        animation: _slideController,
        builder: (context, child) {
          return FractionalTranslation(
            translation: Offset(_slideController.value, 0),
            child: child,
          );
        },
        child: SizedBox.expand(
          child: _buildFloorPlanOnly(hospital, settings, _displayFloorId),
        ),
      ),
      // Incoming floor — slides in from the left
      AnimatedBuilder(
        animation: _slideController,
        builder: (context, child) {
          return FractionalTranslation(
            translation: Offset(_slideController.value - 1.0, 0),
            child: child,
          );
        },
        child: SizedBox.expand(
          child: _buildFloorPlanOnly(hospital, settings, _nextFloorId),
        ),
      ),
    ];
  }

  /// Build just a floor plan (no path) for the slide transition.
  Widget _buildFloorPlanOnly(
    Hospital hospital,
    SettingsState settings,
    int floorId,
  ) {
    return CustomPaint(
      painter: getFloorPlanPainter(
        hospitalId: hospital.id,
        floorId: floorId,
        darkMode: settings.darkMode,
        locale: settings.language,
      ),
    );
  }

  /// Build the "Elevator" label overlay at the stairs position.
  Widget _buildElevatorLabel(Hospital hospital, SettingsState settings) {
    final floor = hospital.floorById(_displayFloorId);
    if (floor == null) return const SizedBox.shrink();

    final isDark = settings.darkMode;
    final lang = settings.language;
    final l10n = AppLocalizations(lang);

    return AnimatedBuilder(
      animation: _elevatorLabelController,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Convert stairs position (percentage-based) to screen coords
            // Using same logic as IsometricHelper.toIso
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final stairsPos = floor.stairsPosition;

            final lateral = stairsPos.y / 100.0;
            final depth = stairsPos.x / 100.0;
            const margin = 0.02;
            final availW = size.width * (1 - 2 * margin);
            final availH = size.height * (1 - 2 * margin);
            final vOffset = size.height * margin;
            const nearScale = 1.0;
            const farScale = 0.88;
            final rowScale = nearScale + (farScale - nearScale) * depth;
            final rowWidth = availW * rowScale;
            final rowLeft = size.width * margin + (availW - rowWidth) / 2;
            final screenX = rowLeft + lateral * rowWidth;
            final screenY = vOffset + availH - depth * availH;

            final opacity = _elevatorLabelController.value;

            return Stack(
              children: [
                Positioned(
                  left: screenX - 40,
                  top: screenY - 32,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface.withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.elevator_outlined,
                            size: 14,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.elevator,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRouteInfo(
    Floor floor,
    Destination dest,
    SettingsState settings, {
    int floorDifference = 0,
  }) {
    final route = calculateRouteInfo(
      floor.entrance,
      dest.position,
      floorDifference: floorDifference,
    );
    final isDark = settings.darkMode;
    final accentColor = widget.isEmergency
        ? AppColors.red
        : (isDark ? AppColors.darkBlue : AppColors.blue);

    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: AnimatedOpacity(
        opacity: _pathController.value >= 1.0 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _metric(Icons.straighten, '${route.distanceMeters}m', accentColor, isDark),
              Container(
                width: 1,
                height: 20,
                color: isDark ? AppColors.darkDivider : AppColors.divider,
              ),
              _metric(Icons.directions_walk, '${route.walkMinutes} min', accentColor, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String text, Color accentColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
