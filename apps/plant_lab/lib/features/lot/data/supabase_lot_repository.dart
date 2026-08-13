import 'package:plant_lab/core/database/supabase_client.dart';
import 'package:plant_lab/features/lot/domain/lot.dart';
import 'package:plant_lab/features/lot/domain/lot_repository.dart';

class SupabaseLotRepository implements LotRepository {
  @override
  Future<List<LotSummary>> getLots({
    String? search,
    String? stageCode,
    String? cropCategory,
    String? status,
    String? siteId,
    int page = 0,
    int pageSize = 25,
  }) async {
    dynamic query = supabase
        .from('core.lots')
        .select('''
          id,
          lot_code,
          canonical_lot_code,
          stage_code,
          crop_category_code,
          status,
          created_at,
          public.products!inner(name, sku),
          master.sites(site_name)
        ''');

    if (search != null && search.isNotEmpty) {
      query = query.ilike('lot_code', '%$search%');
    }
    if (stageCode != null) {
      query = query.eq('stage_code', stageCode);
    }
    if (cropCategory != null) {
      query = query.eq('crop_category_code', cropCategory);
    }
    if (status != null) {
      query = query.eq('status', status);
    }
    if (siteId != null) {
      query = query.eq('plant_site_id', siteId);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return data.map(_mapToLotSummary).toList();
  }

  @override
  Future<Lot> getLotById(String lotId) async {
    final data = await supabase
        .from('core.lots')
        .select('''
          *,
          public.products(name, sku),
          master.sites(site_name)
        ''')
        .eq('id', lotId)
        .single();

    return _mapToLot(data);
  }

  @override
  Future<List<LotSummary>> getLotsByProcessPlan(String processPlanId) async {
    final data = await supabase
        .from('plant.process_plans')
        .select('core.lots(*)')
        .eq('id', processPlanId);

    return (data as List).map((item) => _mapToLotSummary(item)).toList();
  }

  @override
  Future<Map<LotStage, int>> getLotCountByStage() async {
    final data = await supabase
        .from('core.lots')
        .select('stage_code')
        .not('stage_code', 'is', null);

    final counts = <LotStage, int>{};
    for (final row in data) {
      final stage = LotStage.fromCode(row['stage_code'] as String?);
      counts[stage] = (counts[stage] ?? 0) + 1;
    }
    return counts;
  }

  LotSummary _mapToLotSummary(Map<String, dynamic> data) {
    final product = data['products'] as Map<String, dynamic>?;
    final site = data['sites'] as Map<String, dynamic>?;
    return LotSummary(
      id: data['id'] as String,
      lotCode: data['lot_code'] as String,
      canonicalLotCode: data['canonical_lot_code'] as String? ??
          data['lot_code'] as String,
      productName: product?['name'] as String?,
      sku: product?['sku'] as String?,
      stageCode: data['stage_code'] as String?,
      cropCategoryCode: data['crop_category_code'] as String?,
      status: data['status'] as String? ?? 'UNKNOWN',
      siteName: site?['site_name'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  Lot _mapToLot(Map<String, dynamic> data) {
    final product = data['products'] as Map<String, dynamic>?;
    final site = data['sites'] as Map<String, dynamic>?;
    return Lot(
      id: data['id'] as String,
      lotCode: data['lot_code'] as String,
      canonicalLotCode: data['canonical_lot_code'] as String? ??
          data['lot_code'] as String,
      companyId: BigInt.from(data['company_id'] as int),
      productId: BigInt.from(data['product_id'] as int),
      productName: product?['name'] as String?,
      sku: product?['sku'] as String?,
      stageCode: data['stage_code'] as String?,
      cropCategoryCode: data['crop_category_code'] as String?,
      seedGenerationCode: data['seed_generation_code'] as String?,
      fieldStatusCode: data['field_status_code'] as String?,
      cropYear: data['crop_year'] as int?,
      seasonCode: data['season_code'] as String?,
      siteId: data['plant_site_id'] as String?,
      siteName: site?['site_name'] as String?,
      status: data['status'] as String? ?? 'UNKNOWN',
      notes: data['notes'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'] as String)
          : null,
    );
  }
}
