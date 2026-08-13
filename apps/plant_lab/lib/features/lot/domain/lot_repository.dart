import 'package:plant_lab/features/lot/domain/lot.dart';

abstract class LotRepository {
  /// Fetch paginated list of lots with optional filters
  Future<List<LotSummary>> getLots({
    String? search,
    String? stageCode,
    String? cropCategory,
    String? status,
    String? siteId,
    int page = 0,
    int pageSize = 25,
  });

  /// Fetch single lot by id with full details
  Future<Lot> getLotById(String lotId);

  /// Fetch lots belonging to a specific plant plan
  Future<List<LotSummary>> getLotsByProcessPlan(String processPlanId);

  /// Count lots by stage (for dashboard)
  Future<Map<LotStage, int>> getLotCountByStage();
}
