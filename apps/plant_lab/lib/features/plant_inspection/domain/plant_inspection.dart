import 'package:freezed_annotation/freezed_annotation.dart';

part 'plant_inspection.freezed.dart';
part 'plant_inspection.g.dart';

@freezed
abstract class PlantInspection with _$PlantInspection {
  const factory PlantInspection({
    required String id,
    required String inspectionCode,
    required String planId,
    required String stepId,
    String? lotId,
    String? lotCode,
    required String formTemplateId,
    String? formTemplateName,
    required String formVersion,
    required String inspectedBy,
    String? inspectorName,
    required String siteId,
    String? siteName,
    required String status, // DRAFT | SUBMITTED | UNDER_REVIEW | APPROVED | NEED_REVISION | OOS | REJECTED
    String? reviewedBy,
    String? reviewerName,
    DateTime? reviewedAt,
    String? reviewNotes,
    required Map<String, dynamic> answers, // JSONB answers
    required List<PlantEvidence> evidences,
    bool? hasOos,
    required DateTime inspectedAt,
    DateTime? submittedAt,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _PlantInspection;

  factory PlantInspection.fromJson(Map<String, dynamic> json) =>
      _$PlantInspectionFromJson(json);
}

@freezed
abstract class PlantInspectionSummary with _$PlantInspectionSummary {
  const factory PlantInspectionSummary({
    required String id,
    required String inspectionCode,
    required String planId,
    String? lotCode,
    String? formTemplateName,
    String? inspectorName,
    required String status,
    bool? hasOos,
    required DateTime inspectedAt,
    DateTime? submittedAt,
  }) = _PlantInspectionSummary;

  factory PlantInspectionSummary.fromJson(Map<String, dynamic> json) =>
      _$PlantInspectionSummaryFromJson(json);
}

@freezed
abstract class PlantEvidence with _$PlantEvidence {
  const factory PlantEvidence({
    required String id,
    required String inspectionId,
    required String attachmentId,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? storagePath,
    String? signedUrl,
    String? caption,
    required String uploadedBy,
    required DateTime uploadedAt,
  }) = _PlantEvidence;

  factory PlantEvidence.fromJson(Map<String, dynamic> json) =>
      _$PlantEvidenceFromJson(json);
}

/// Offline draft for an inspection being filled in
@freezed
abstract class InspectionDraft with _$InspectionDraft {
  const factory InspectionDraft({
    required String localId, // UUID generated offline
    required String planId,
    required String stepId,
    required String formTemplateId,
    required String formVersion,
    required Map<String, dynamic> answers,
    required List<String> pendingEvidencePaths, // local file paths pending upload
    required DateTime createdAt,
    @Default(false) bool hasSyncError,
    String? syncErrorMessage,
  }) = _InspectionDraft;

  factory InspectionDraft.fromJson(Map<String, dynamic> json) =>
      _$InspectionDraftFromJson(json);
}

enum InspectionStatus {
  draft('DRAFT', 'Draft'),
  submitted('SUBMITTED', 'Terkirim'),
  underReview('UNDER_REVIEW', 'Sedang Direview'),
  approved('APPROVED', 'Disetujui'),
  needRevision('NEED_REVISION', 'Perlu Revisi'),
  oos('OOS', 'Out of Spec'),
  rejected('REJECTED', 'Ditolak');

  final String code;
  final String label;
  const InspectionStatus(this.code, this.label);

  static InspectionStatus fromCode(String code) {
    return InspectionStatus.values.firstWhere(
      (s) => s.code == code.toUpperCase(),
      orElse: () => InspectionStatus.draft,
    );
  }

  bool get canEdit =>
      this == InspectionStatus.draft || this == InspectionStatus.needRevision;
  bool get canSubmit => this == InspectionStatus.draft;
  bool get isTerminal =>
      this == InspectionStatus.approved || this == InspectionStatus.rejected;
}
