import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plant_lab/features/lot/data/lot_providers.dart';
import 'package:plant_lab/features/lot/domain/lot.dart';

class LotListScreen extends ConsumerStatefulWidget {
  const LotListScreen({super.key});

  @override
  ConsumerState<LotListScreen> createState() => _LotListScreenState();
}

class _LotListScreenState extends ConsumerState<LotListScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  String? _selectedStage;
  String? _selectedCategory;

  static const _stages = [
    (code: 'HARVEST', label: 'Panen', icon: '🌾'),
    (code: 'DSS', label: 'DSS', icon: '🔵'),
    (code: 'DCS', label: 'DCS', icon: '🟢'),
    (code: 'FG', label: 'Final Good', icon: '📦'),
  ];

  static const _categories = [
    (code: 'FC', label: 'Field Corn'),
    (code: 'SWC', label: 'Sweet Corn'),
    (code: 'PS', label: 'Parent Seed'),
    (code: 'VEGE', label: 'Vegetables'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lotState = ref.watch(lotListNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildStageFilter()),
            SliverToBoxAdapter(child: _buildCategoryFilter()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: lotState.when(
                  data: (lots) => Text(
                    '${lots.length} Lot ditemukan',
                    style: const TextStyle(
                      color: Color(0xFF4B7A5F),
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
            lotState.when(
              data: (lots) => lots.isEmpty
                  ? SliverFillRemaining(child: _buildEmpty())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (i == lots.length) {
                            return _buildLoadMore();
                          }
                          return _LotCard(
                            lot: lots[i],
                            index: i,
                            onTap: () => context.push('/app/lots/${lots[i].id}'),
                          );
                        },
                        childCount: lots.length + 1,
                      ),
                    ),
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _LotCardSkeleton(),
                  childCount: 6,
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _buildError(e.toString()),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: const Color(0xFF0A0F0A),
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Text(
          'Lot Registry',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Color(0xFFF0FDF4),
            letterSpacing: -0.5,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1F0F), Color(0xFF0A0F0A)],
            ),
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF22C55E).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF162019),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F4A30)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            color: Color(0xFFF0FDF4),
            fontFamily: 'Inter',
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Cari lot code, produk...',
            hintStyle: const TextStyle(color: Color(0xFF4B7A5F)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF4B7A5F), size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF4B7A5F), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(lotListNotifierProvider.notifier).search('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (v) {
            setState(() {});
            if (v.length >= 2 || v.isEmpty) {
              ref.read(lotListNotifierProvider.notifier).search(v);
            }
          },
        ),
      ),
    );
  }

  Widget _buildStageFilter() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          _FilterChip(
            label: 'Semua Stage',
            selected: _selectedStage == null,
            onTap: () {
              setState(() => _selectedStage = null);
              ref.read(lotListNotifierProvider.notifier).filterByStage(null);
            },
          ),
          const SizedBox(width: 8),
          ..._stages.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: '${s.icon} ${s.label}',
                  selected: _selectedStage == s.code,
                  onTap: () {
                    setState(() => _selectedStage = s.code);
                    ref
                        .read(lotListNotifierProvider.notifier)
                        .filterByStage(s.code);
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        children: [
          _FilterChip(
            label: 'Semua Kategori',
            selected: _selectedCategory == null,
            small: true,
            onTap: () {
              setState(() => _selectedCategory = null);
              ref
                  .read(lotListNotifierProvider.notifier)
                  .filterByCategory(null);
            },
          ),
          const SizedBox(width: 8),
          ..._categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: c.label,
                  selected: _selectedCategory == c.code,
                  small: true,
                  onTap: () {
                    setState(() => _selectedCategory = c.code);
                    ref
                        .read(lotListNotifierProvider.notifier)
                        .filterByCategory(c.code);
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF162019),
              border: Border.all(color: const Color(0xFF1F4A30)),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: Color(0xFF4B7A5F), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada lot',
            style: TextStyle(
              color: Color(0xFFF0FDF4),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lot akan muncul setelah data diimport\natau dibuat melalui sistem',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF4B7A5F),
              fontFamily: 'Inter',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat data',
              style: TextStyle(
                color: Color(0xFFF0FDF4),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4B7A5F),
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  ref.refresh(lotListNotifierProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Coba Lagi', style: TextStyle(fontFamily: 'Inter')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    final notifier = ref.read(lotListNotifierProvider.notifier);
    if (!notifier.hasMore) return const SizedBox(height: 80);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: OutlinedButton(
          onPressed: () => notifier.loadMore(),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF22C55E),
            side: const BorderSide(color: Color(0xFF22C55E)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Muat lebih banyak', style: TextStyle(fontFamily: 'Inter')),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () {/* navigate to lot creation or import */},
      backgroundColor: const Color(0xFF22C55E),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Tambah Lot', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      elevation: 8,
    );
  }
}

// ── Lot Card ───────────────────────────────────────────────────────────────

class _LotCard extends StatefulWidget {
  final LotSummary lot;
  final int index;
  final VoidCallback onTap;

  const _LotCard({
    required this.lot,
    required this.index,
    required this.onTap,
  });

  @override
  State<_LotCard> createState() => _LotCardState();
}

class _LotCardState extends State<_LotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + widget.index * 30),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _hovering
                    ? const Color(0xFF1A2E1E)
                    : const Color(0xFF162019),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hovering
                      ? const Color(0xFF22C55E).withValues(alpha: 0.4)
                      : const Color(0xFF1F4A30),
                ),
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.lot.lotCode,
                                  style: const TextStyle(
                                    color: Color(0xFFF0FDF4),
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (widget.lot.productName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.lot.productName!,
                                    style: const TextStyle(
                                      color: Color(0xFF86EFAC),
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _StatusBadge(status: widget.lot.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (widget.lot.stageCode != null)
                            _InfoPill(
                              label: widget.lot.stageCode!,
                              color: const Color(0xFF16A34A),
                            ),
                          if (widget.lot.cropCategoryCode != null) ...[
                            const SizedBox(width: 6),
                            _InfoPill(
                              label: widget.lot.cropCategoryCode!,
                              color: const Color(0xFF0284C7),
                            ),
                          ],
                          const Spacer(),
                          if (widget.lot.siteName != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xFF4B7A5F),
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.lot.siteName!,
                                  style: const TextStyle(
                                    color: Color(0xFF4B7A5F),
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────

class _LotCardSkeleton extends StatefulWidget {
  const _LotCardSkeleton();

  @override
  State<_LotCardSkeleton> createState() => _LotCardSkeletonState();
}

class _LotCardSkeletonState extends State<_LotCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF162019),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F4A30)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Shimmer(width: 140, height: 16, opacity: _anim.value),
                  const Spacer(),
                  _Shimmer(width: 60, height: 22, opacity: _anim.value),
                ],
              ),
              const SizedBox(height: 8),
              _Shimmer(width: 100, height: 12, opacity: _anim.value),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Shimmer(width: 50, height: 20, opacity: _anim.value),
                  const SizedBox(width: 6),
                  _Shimmer(width: 40, height: 20, opacity: _anim.value),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final double width, height, opacity;
  const _Shimmer(
      {required this.width, required this.height, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1F4A30),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ── Small Widgets ──────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 12,
          vertical: small ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF22C55E).withValues(alpha: 0.15)
              : const Color(0xFF162019),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF22C55E)
                : const Color(0xFF1F4A30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? const Color(0xFF22C55E)
                : const Color(0xFF4B7A5F),
            fontFamily: 'Inter',
            fontSize: small ? 11 : 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = switch (status.toUpperCase()) {
      'ACTIVE' || 'APPROVED' || 'COMPLETED' => (
          const Color(0xFF22C55E),
          const Color(0xFF22C55E).withValues(alpha: 0.12)
        ),
      'DRAFT' => (
          const Color(0xFF6B7280),
          const Color(0xFF6B7280).withValues(alpha: 0.12)
        ),
      'ON_HOLD' || 'PENDING' => (
          const Color(0xFFF59E0B),
          const Color(0xFFF59E0B).withValues(alpha: 0.12)
        ),
      'CANCELLED' || 'REJECTED' => (
          const Color(0xFFEF4444),
          const Color(0xFFEF4444).withValues(alpha: 0.12)
        ),
      _ => (
          const Color(0xFF86EFAC),
          const Color(0xFF86EFAC).withValues(alpha: 0.12)
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _formatStatus(status),
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String s) {
    return s
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
