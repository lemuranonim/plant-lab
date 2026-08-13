import 'package:plant_lab/features/plant_plan/domain/plant_plan.dart';

abstract class PlantPlanRepository {
  Future<List<PlantPlanSummary>> getPlantPlans({
    String? lotId,
    String? siteId,
    String? status,
    int page = 0,
    int pageSize = 25,
  });

  Future<PlantPlan> getPlantPlanById(String planId);

  Future<List<PlantProcessStep>> getProcessSteps(String planId);

  Future<PlantPlan> createPlantPlan({
    required String lotId,
    required String processTypeId,
    required String siteId,
    String? notes,
  });

  Future<void> advanceStep({
    required String stepId,
    required String action, // 'START' | 'COMPLETE'
    String? notes,
  });
}
