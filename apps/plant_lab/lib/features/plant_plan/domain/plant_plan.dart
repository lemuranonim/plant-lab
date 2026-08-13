import 'package:freezed_annotation/freezed_annotation.dart';

part 'plant_plan.freezed.dart';
part 'plant_plan.g.dart';

@freezed
abstract class PlantPlan with _$PlantPlan {
  const factory PlantPlan({
    required String id,
    required String planCode,
    required String lotId,
    String? lotCode,
    String? productName,
    required BigInt siteId,
    String? siteName,
    required BigInt companyId,
    required String processTypeId,
    String? processTypeName,
    required String status,
    required int totalSteps,
    required int completedSteps,
    String? currentStepName,
    String? notes,
    required String createdBy,
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) = _PlantPlan;

  factory PlantPlan.fromJson(Map<String, dynamic> json) =>
      _$PlantPlanFromJson(json);
}

@freezed
abstract class PlantPlanSummary with _$PlantPlanSummary {
  const factory PlantPlanSummary({
    required String id,
    required String planCode,
    required String lotId,
    String? lotCode,
    String? productName,
    String? siteName,
    required String status,
    required int totalSteps,
    required int completedSteps,
    String? currentStepName,
    required DateTime createdAt,
  }) = _PlantPlanSummary;

  factory PlantPlanSummary.fromJson(Map<String, dynamic> json) =>
      _$PlantPlanSummaryFromJson(json);
}

@freezed
abstract class PlantProcessStep with _$PlantProcessStep {
  const factory PlantProcessStep({
    required String id,
    required String planId,
    required String stepCode,
    required String stepName,
    required int stepOrder,
    required String status,
    String? formTemplateId,
    required bool requiresEvidence,
    required int evidenceCount,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? dueAt,
  }) = _PlantProcessStep;

  factory PlantProcessStep.fromJson(Map<String, dynamic> json) =>
      _$PlantProcessStepFromJson(json);
}

/// Process stages in Plant module order
enum PlantProcessStage {
  receiving('RECEIVING', 'Receiving'),
  intake('INTAKE', 'Intake'),
  drier('DRIER', 'Drier'),
  shelling('SHELLING', 'Shelling'),
  cleaning('CLEANING', 'Cleaning'),
  treatment('TREATMENT', 'Treatment'),
  packing('PACKING', 'Packing');

  final String code;
  final String label;
  const PlantProcessStage(this.code, this.label);
}

enum PlantPlanStatus {
  draft('DRAFT', 'Draft'),
  active('ACTIVE', 'Aktif'),
  onHold('ON_HOLD', 'Ditahan'),
  completed('COMPLETED', 'Selesai'),
  cancelled('CANCELLED', 'Dibatalkan');

  final String code;
  final String label;
  const PlantPlanStatus(this.code, this.label);

  static PlantPlanStatus fromCode(String code) {
    return PlantPlanStatus.values.firstWhere(
      (s) => s.code == code.toUpperCase(),
      orElse: () => PlantPlanStatus.draft,
    );
  }
}
