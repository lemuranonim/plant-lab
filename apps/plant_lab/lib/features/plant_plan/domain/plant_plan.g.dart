// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plant_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlantPlan _$PlantPlanFromJson(Map<String, dynamic> json) => _PlantPlan(
  id: json['id'] as String,
  planCode: json['planCode'] as String,
  lotId: json['lotId'] as String,
  lotCode: json['lotCode'] as String?,
  productName: json['productName'] as String?,
  siteId: BigInt.parse(json['siteId'] as String),
  siteName: json['siteName'] as String?,
  companyId: BigInt.parse(json['companyId'] as String),
  processTypeId: json['processTypeId'] as String,
  processTypeName: json['processTypeName'] as String?,
  status: json['status'] as String,
  totalSteps: (json['totalSteps'] as num).toInt(),
  completedSteps: (json['completedSteps'] as num).toInt(),
  currentStepName: json['currentStepName'] as String?,
  notes: json['notes'] as String?,
  createdBy: json['createdBy'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
);

Map<String, dynamic> _$PlantPlanToJson(_PlantPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planCode': instance.planCode,
      'lotId': instance.lotId,
      'lotCode': instance.lotCode,
      'productName': instance.productName,
      'siteId': instance.siteId.toString(),
      'siteName': instance.siteName,
      'companyId': instance.companyId.toString(),
      'processTypeId': instance.processTypeId,
      'processTypeName': instance.processTypeName,
      'status': instance.status,
      'totalSteps': instance.totalSteps,
      'completedSteps': instance.completedSteps,
      'currentStepName': instance.currentStepName,
      'notes': instance.notes,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
    };

_PlantPlanSummary _$PlantPlanSummaryFromJson(Map<String, dynamic> json) =>
    _PlantPlanSummary(
      id: json['id'] as String,
      planCode: json['planCode'] as String,
      lotId: json['lotId'] as String,
      lotCode: json['lotCode'] as String?,
      productName: json['productName'] as String?,
      siteName: json['siteName'] as String?,
      status: json['status'] as String,
      totalSteps: (json['totalSteps'] as num).toInt(),
      completedSteps: (json['completedSteps'] as num).toInt(),
      currentStepName: json['currentStepName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$PlantPlanSummaryToJson(_PlantPlanSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planCode': instance.planCode,
      'lotId': instance.lotId,
      'lotCode': instance.lotCode,
      'productName': instance.productName,
      'siteName': instance.siteName,
      'status': instance.status,
      'totalSteps': instance.totalSteps,
      'completedSteps': instance.completedSteps,
      'currentStepName': instance.currentStepName,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_PlantProcessStep _$PlantProcessStepFromJson(Map<String, dynamic> json) =>
    _PlantProcessStep(
      id: json['id'] as String,
      planId: json['planId'] as String,
      stepCode: json['stepCode'] as String,
      stepName: json['stepName'] as String,
      stepOrder: (json['stepOrder'] as num).toInt(),
      status: json['status'] as String,
      formTemplateId: json['formTemplateId'] as String?,
      requiresEvidence: json['requiresEvidence'] as bool,
      evidenceCount: (json['evidenceCount'] as num).toInt(),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      dueAt: json['dueAt'] == null
          ? null
          : DateTime.parse(json['dueAt'] as String),
    );

Map<String, dynamic> _$PlantProcessStepToJson(_PlantProcessStep instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planId': instance.planId,
      'stepCode': instance.stepCode,
      'stepName': instance.stepName,
      'stepOrder': instance.stepOrder,
      'status': instance.status,
      'formTemplateId': instance.formTemplateId,
      'requiresEvidence': instance.requiresEvidence,
      'evidenceCount': instance.evidenceCount,
      'startedAt': instance.startedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'dueAt': instance.dueAt?.toIso8601String(),
    };
