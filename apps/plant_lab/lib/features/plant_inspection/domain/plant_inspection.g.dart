// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plant_inspection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlantInspection _$PlantInspectionFromJson(Map<String, dynamic> json) =>
    _PlantInspection(
      id: json['id'] as String,
      inspectionCode: json['inspectionCode'] as String,
      planId: json['planId'] as String,
      stepId: json['stepId'] as String,
      lotId: json['lotId'] as String?,
      lotCode: json['lotCode'] as String?,
      formTemplateId: json['formTemplateId'] as String,
      formTemplateName: json['formTemplateName'] as String?,
      formVersion: json['formVersion'] as String,
      inspectedBy: json['inspectedBy'] as String,
      inspectorName: json['inspectorName'] as String?,
      siteId: json['siteId'] as String,
      siteName: json['siteName'] as String?,
      status: json['status'] as String,
      reviewedBy: json['reviewedBy'] as String?,
      reviewerName: json['reviewerName'] as String?,
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
      reviewNotes: json['reviewNotes'] as String?,
      answers: json['answers'] as Map<String, dynamic>,
      evidences: (json['evidences'] as List<dynamic>)
          .map((e) => PlantEvidence.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasOos: json['hasOos'] as bool?,
      inspectedAt: DateTime.parse(json['inspectedAt'] as String),
      submittedAt: json['submittedAt'] == null
          ? null
          : DateTime.parse(json['submittedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$PlantInspectionToJson(_PlantInspection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'inspectionCode': instance.inspectionCode,
      'planId': instance.planId,
      'stepId': instance.stepId,
      'lotId': instance.lotId,
      'lotCode': instance.lotCode,
      'formTemplateId': instance.formTemplateId,
      'formTemplateName': instance.formTemplateName,
      'formVersion': instance.formVersion,
      'inspectedBy': instance.inspectedBy,
      'inspectorName': instance.inspectorName,
      'siteId': instance.siteId,
      'siteName': instance.siteName,
      'status': instance.status,
      'reviewedBy': instance.reviewedBy,
      'reviewerName': instance.reviewerName,
      'reviewedAt': instance.reviewedAt?.toIso8601String(),
      'reviewNotes': instance.reviewNotes,
      'answers': instance.answers,
      'evidences': instance.evidences,
      'hasOos': instance.hasOos,
      'inspectedAt': instance.inspectedAt.toIso8601String(),
      'submittedAt': instance.submittedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_PlantInspectionSummary _$PlantInspectionSummaryFromJson(
  Map<String, dynamic> json,
) => _PlantInspectionSummary(
  id: json['id'] as String,
  inspectionCode: json['inspectionCode'] as String,
  planId: json['planId'] as String,
  lotCode: json['lotCode'] as String?,
  formTemplateName: json['formTemplateName'] as String?,
  inspectorName: json['inspectorName'] as String?,
  status: json['status'] as String,
  hasOos: json['hasOos'] as bool?,
  inspectedAt: DateTime.parse(json['inspectedAt'] as String),
  submittedAt: json['submittedAt'] == null
      ? null
      : DateTime.parse(json['submittedAt'] as String),
);

Map<String, dynamic> _$PlantInspectionSummaryToJson(
  _PlantInspectionSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'inspectionCode': instance.inspectionCode,
  'planId': instance.planId,
  'lotCode': instance.lotCode,
  'formTemplateName': instance.formTemplateName,
  'inspectorName': instance.inspectorName,
  'status': instance.status,
  'hasOos': instance.hasOos,
  'inspectedAt': instance.inspectedAt.toIso8601String(),
  'submittedAt': instance.submittedAt?.toIso8601String(),
};

_PlantEvidence _$PlantEvidenceFromJson(Map<String, dynamic> json) =>
    _PlantEvidence(
      id: json['id'] as String,
      inspectionId: json['inspectionId'] as String,
      attachmentId: json['attachmentId'] as String,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      storagePath: json['storagePath'] as String?,
      signedUrl: json['signedUrl'] as String?,
      caption: json['caption'] as String?,
      uploadedBy: json['uploadedBy'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );

Map<String, dynamic> _$PlantEvidenceToJson(_PlantEvidence instance) =>
    <String, dynamic>{
      'id': instance.id,
      'inspectionId': instance.inspectionId,
      'attachmentId': instance.attachmentId,
      'fileName': instance.fileName,
      'mimeType': instance.mimeType,
      'fileSizeBytes': instance.fileSizeBytes,
      'storagePath': instance.storagePath,
      'signedUrl': instance.signedUrl,
      'caption': instance.caption,
      'uploadedBy': instance.uploadedBy,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
    };

_InspectionDraft _$InspectionDraftFromJson(Map<String, dynamic> json) =>
    _InspectionDraft(
      localId: json['localId'] as String,
      planId: json['planId'] as String,
      stepId: json['stepId'] as String,
      formTemplateId: json['formTemplateId'] as String,
      formVersion: json['formVersion'] as String,
      answers: json['answers'] as Map<String, dynamic>,
      pendingEvidencePaths: (json['pendingEvidencePaths'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      hasSyncError: json['hasSyncError'] as bool? ?? false,
      syncErrorMessage: json['syncErrorMessage'] as String?,
    );

Map<String, dynamic> _$InspectionDraftToJson(_InspectionDraft instance) =>
    <String, dynamic>{
      'localId': instance.localId,
      'planId': instance.planId,
      'stepId': instance.stepId,
      'formTemplateId': instance.formTemplateId,
      'formVersion': instance.formVersion,
      'answers': instance.answers,
      'pendingEvidencePaths': instance.pendingEvidencePaths,
      'createdAt': instance.createdAt.toIso8601String(),
      'hasSyncError': instance.hasSyncError,
      'syncErrorMessage': instance.syncErrorMessage,
    };
