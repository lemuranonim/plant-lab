import 'package:plant_lab/core/database/supabase_client.dart';
import 'package:plant_lab/features/plant_plan/domain/plant_plan.dart';
import 'package:plant_lab/features/plant_plan/domain/plant_plan_repository.dart';

class SupabasePlantPlanRepository implements PlantPlanRepository {
  @override
  Future<List<PlantPlanSummary>> getPlantPlans({
    String? lotId,
    String? siteId,
    String? status,
    int page = 0,
    int pageSize = 25,
  }) async {
    dynamic query = supabase
        .from('plant.process_plans')
        .select('''
          id,
          plan_code,
          lot_id,
          site_id,
          company_id,
          status,
          total_steps,
          completed_steps,
          created_at,
          core.lots!inner(lot_code, public.products(name)),
          master.sites(site_name),
          plant.process_steps(step_name, status, step_order)
        ''');

    if (lotId != null) query = query.eq('lot_id', lotId);
    if (siteId != null) query = query.eq('site_id', siteId);
    if (status != null) query = query.eq('status', status);

    final data = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return data.map(_mapToSummary).toList();
  }

  @override
  Future<PlantPlan> getPlantPlanById(String planId) async {
    final data = await supabase
        .from('plant.process_plans')
        .select('''
          *,
          core.lots(lot_code, public.products(name)),
          master.sites(site_name),
          plant.process_types(type_name)
        ''')
        .eq('id', planId)
        .single();
    return _mapToPlan(data);
  }

  @override
  Future<List<PlantProcessStep>> getProcessSteps(String planId) async {
    final data = await supabase
        .from('plant.process_steps')
        .select('*, plant.form_templates(template_name)')
        .eq('plan_id', planId)
        .order('step_order');
    return data.map(_mapToStep).toList();
  }

  @override
  Future<PlantPlan> createPlantPlan({
    required String lotId,
    required String processTypeId,
    required String siteId,
    String? notes,
  }) async {
    final result = await supabase.rpc('plant.create_process_plan', params: {
      'p_lot_id': lotId,
      'p_process_type_id': processTypeId,
      'p_site_id': siteId,
      'p_notes': notes,
    });
    return getPlantPlanById(result['plan_id'] as String);
  }

  @override
  Future<void> advanceStep({
    required String stepId,
    required String action,
    String? notes,
  }) async {
    await supabase.rpc('plant.advance_process_step', params: {
      'p_step_id': stepId,
      'p_action': action,
      'p_notes': notes,
    });
  }

  PlantPlanSummary _mapToSummary(Map<String, dynamic> d) {
    final lot = d['lots'] as Map<String, dynamic>?;
    final product = lot?['products'] as Map<String, dynamic>?;
    final site = d['sites'] as Map<String, dynamic>?;
    final steps = (d['process_steps'] as List?)?.cast<Map<String, dynamic>>();
    final currentStep = steps?.where((s) => s['status'] == 'IN_PROGRESS').firstOrNull;
    return PlantPlanSummary(
      id: d['id'] as String,
      planCode: d['plan_code'] as String,
      lotId: d['lot_id'] as String,
      lotCode: lot?['lot_code'] as String?,
      productName: product?['name'] as String?,
      siteName: site?['site_name'] as String?,
      status: d['status'] as String,
      totalSteps: (d['total_steps'] as int?) ?? 0,
      completedSteps: (d['completed_steps'] as int?) ?? 0,
      currentStepName: currentStep?['step_name'] as String?,
      createdAt: DateTime.parse(d['created_at'] as String),
    );
  }

  PlantPlan _mapToPlan(Map<String, dynamic> d) {
    final lot = d['lots'] as Map<String, dynamic>?;
    final product = lot?['products'] as Map<String, dynamic>?;
    final site = d['sites'] as Map<String, dynamic>?;
    final processType = d['process_types'] as Map<String, dynamic>?;
    return PlantPlan(
      id: d['id'] as String,
      planCode: d['plan_code'] as String,
      lotId: d['lot_id'] as String,
      lotCode: lot?['lot_code'] as String?,
      productName: product?['name'] as String?,
      siteId: BigInt.from(d['site_id'] as int),
      siteName: site?['site_name'] as String?,
      companyId: BigInt.from(d['company_id'] as int),
      processTypeId: d['process_type_id'] as String,
      processTypeName: processType?['type_name'] as String?,
      status: d['status'] as String,
      totalSteps: (d['total_steps'] as int?) ?? 0,
      completedSteps: (d['completed_steps'] as int?) ?? 0,
      notes: d['notes'] as String?,
      createdBy: d['created_by'] as String,
      createdAt: DateTime.parse(d['created_at'] as String),
      updatedAt: d['updated_at'] != null
          ? DateTime.parse(d['updated_at'] as String)
          : null,
      completedAt: d['completed_at'] != null
          ? DateTime.parse(d['completed_at'] as String)
          : null,
    );
  }

  PlantProcessStep _mapToStep(Map<String, dynamic> d) {
    return PlantProcessStep(
      id: d['id'] as String,
      planId: d['plan_id'] as String,
      stepCode: d['step_code'] as String,
      stepName: d['step_name'] as String,
      stepOrder: d['step_order'] as int,
      status: d['status'] as String,
      formTemplateId: d['form_template_id'] as String?,
      requiresEvidence: (d['requires_evidence'] as bool?) ?? false,
      evidenceCount: (d['evidence_count'] as int?) ?? 0,
      startedAt: d['started_at'] != null
          ? DateTime.parse(d['started_at'] as String)
          : null,
      completedAt: d['completed_at'] != null
          ? DateTime.parse(d['completed_at'] as String)
          : null,
      dueAt: d['due_at'] != null
          ? DateTime.parse(d['due_at'] as String)
          : null,
    );
  }
}
