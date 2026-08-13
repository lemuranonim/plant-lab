import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:plant_lab/features/lot/domain/lot.dart';
import 'package:plant_lab/features/lot/domain/lot_repository.dart';
import 'package:plant_lab/features/lot/data/supabase_lot_repository.dart';

part 'lot_providers.g.dart';

@riverpod
LotRepository lotRepository(Ref ref) => SupabaseLotRepository();

@riverpod
class LotListNotifier extends _$LotListNotifier {
  String _search = '';
  String? _stageCode;
  String? _cropCategory;
  String? _status;
  int _page = 0;
  final List<LotSummary> _items = [];
  bool _hasMore = true;

  @override
  Future<List<LotSummary>> build() async {
    return _fetchPage(reset: true);
  }

  Future<List<LotSummary>> _fetchPage({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _items.clear();
      _hasMore = true;
    }

    final repo = ref.read(lotRepositoryProvider);
    final newItems = await repo.getLots(
      search: _search.isEmpty ? null : _search,
      stageCode: _stageCode,
      cropCategory: _cropCategory,
      status: _status,
      page: _page,
    );

    _items.addAll(newItems);
    if (newItems.length < 25) _hasMore = false;
    _page++;
    return List.unmodifiable(_items);
  }

  Future<void> search(String query) async {
    _search = query;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(reset: true));
  }

  Future<void> filterByStage(String? stage) async {
    _stageCode = stage;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(reset: true));
  }

  Future<void> filterByCategory(String? category) async {
    _cropCategory = category;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(reset: true));
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.valueOrNull ?? [];
    state = AsyncData(current); // keep current while loading more
    final more = await _fetchPage();
    state = AsyncData(more);
  }

  bool get hasMore => _hasMore;
}

@riverpod
Future<Lot> lotDetail(Ref ref, String lotId) {
  return ref.watch(lotRepositoryProvider).getLotById(lotId);
}
