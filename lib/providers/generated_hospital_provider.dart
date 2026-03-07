import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/generated_floor_plan.dart';
import '../data/repositories/generated_hospital_repository.dart';
import '../data/services/floor_plan_api_service.dart';
import '../shared/painters/floor_plans/floor_plan_painter.dart';
import 'hospital_provider.dart';

final generatedHospitalRepoProvider =
    Provider<GeneratedHospitalRepository>((ref) => GeneratedHospitalRepository());

final floorPlanApiServiceProvider =
    Provider<FloorPlanApiService>((ref) => FloorPlanApiService());

final generatedHospitalsProvider =
    AsyncNotifierProvider<GeneratedHospitalsNotifier, List<GeneratedHospital>>(
  GeneratedHospitalsNotifier.new,
);

class GeneratedHospitalsNotifier
    extends AsyncNotifier<List<GeneratedHospital>> {
  bool _initialLoadDone = false;

  @override
  Future<List<GeneratedHospital>> build() async {
    final repo = ref.read(generatedHospitalRepoProvider);
    // Only clear on first app startup, not on subsequent rebuilds (e.g. after adding a hospital)
    if (!_initialLoadDone) {
      await repo.clearAll();
      _initialLoadDone = true;
    }
    final hospitals = await repo.getAll();

    // Register floor plans with the painter factory
    clearGeneratedFloorPlans();
    for (final h in hospitals) {
      for (final f in h.floors) {
        registerGeneratedFloorPlan(h.id, f.id, f.floorPlan, imageBase64: f.imageBase64);
      }
    }

    // Inject into hospital repository
    final hospitalRepo = ref.read(hospitalRepositoryProvider);
    hospitalRepo.setGeneratedHospitals(
      hospitals.map((h) => h.toHospital()).toList(),
    );

    return hospitals;
  }

  Future<void> addHospital(GeneratedHospital hospital) async {
    final repo = ref.read(generatedHospitalRepoProvider);
    await repo.save(hospital);
    ref.invalidateSelf();
  }

  Future<void> deleteHospital(String id) async {
    final repo = ref.read(generatedHospitalRepoProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }
}
