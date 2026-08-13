import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:plant_lab/features/plant_plan/domain/plant_plan.dart';
import 'package:plant_lab/features/plant_plan/domain/plant_plan_repository.dart';
import 'package:plant_lab/features/plant_plan/data/supabase_plant_plan_repository.dart';

part 'plant_plan_providers.g.dart';

@riverpod
PlantPlanRepository plantPlanRepository(Ref ref) =>
    SupabasePlantPlanRepository();

@riverpod
class PlantPlanListNotifier extends _$PlantPlanListNotifier {
  String? _statusFilter;
  String? _lotId;
  int _page = 0;
  final List<PlantPlanSummary> _items = [];
  bool _hasMore = true;

  @override
  Future<List<PlantPlanSummary>> build() async {
    return _fetch(reset: true);
  }

  Future<List<PlantPlanSummary>> _fetch({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _items.clear();
      _hasMore = true;
    }
    final repo = ref.read(plantPlanRepositoryProvider);
    final items = await repo.getPlantPlans(
      lotId: _lotId,
      status: _statusFilter,
      page: _page,
    );
    _items.addAll(items);
    if (items.length < 25) _hasMore = false;
    _page++;
    return List.unmodifiable(_items);
  }

  Future<void> filterByStatus(String? status) async {
    _statusFilter = status;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(reset: true));
  }

  Future<void> filterByLot(String? lotId) async {
    _lotId = lotId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(reset: true));
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.valueOrNull ?? [];
    state = AsyncData(current);
    state = await AsyncValue.guard(() => _fetch());
  }

  bool get hasMore => _hasMore;
}

@riverpod
Future<PlantPlan> plantPlanDetail(Ref ref, String planId) {
  return ref.watch(plantPlanRepositoryProvider).getPlantPlanById(planId);
}

@riverpod
Future<List<PlantProcessStep>> plantProcessSteps(Ref ref, String planId) {
  return ref.watch(plantPlanRepositoryProvider).getProcessSteps(planId);
}
