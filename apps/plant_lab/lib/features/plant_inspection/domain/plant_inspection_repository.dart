import 'package:plant_lab/features/plant_inspection/domain/plant_inspection.dart';

abstract class PlantInspectionRepository {
  /// List inspections for a given plan step
  Future<List<PlantInspectionSummary>> getInspections({
    required String planId,
    String? stepId,
    String? status,
  });

  /// Get full inspection with evidence
  Future<PlantInspection> getInspectionById(String inspectionId);

  /// Submit inspection via RPC (atomic: validates, locks, writes history+outbox)
  Future<PlantInspection> submitInspection({
    required String planId,
    required String stepId,
    required String formTemplateId,
    required String formVersion,
    required Map<String, dynamic> answers,
    required String idempotencyKey,
    List<String>? evidenceAttachmentIds,
  });

  /// Upload evidence file, returns attachment id
  Future<String> uploadEvidence({
    required String inspectionId,
    required String filePath,
    required String mimeType,
    String? caption,
  });

  // ── Offline draft operations ─────────────────────────────────────────────

  /// Save or update offline draft to local DB
  Future<void> saveDraft(InspectionDraft draft);

  /// Load all pending offline drafts
  Future<List<InspectionDraft>> getPendingDrafts();

  /// Delete offline draft after successful sync
  Future<void> deleteDraft(String localId);

  /// Sync all pending drafts to server (called when online)
  Future<List<String>> syncDrafts();
}
