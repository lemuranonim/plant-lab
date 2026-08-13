import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plant_lab/features/plant_plan/data/plant_plan_providers.dart';
import 'package:plant_lab/features/plant_plan/domain/plant_plan.dart';

class PlantPlanListScreen extends ConsumerStatefulWidget {
  const PlantPlanListScreen({super.key});

  @override
  ConsumerState<PlantPlanListScreen> createState() =>
      _PlantPlanListScreenState();
}

class _PlantPlanListScreenState extends ConsumerState<PlantPlanListScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  String? _selectedStatus;

  static const _statusFilters = [
    (code: null, label: 'Semua'),
    (code: 'ACTIVE', label: 'Aktif'),
    (code: 'DRAFT', label: 'Draft'),
    (code: 'ON_HOLD', label: 'Ditahan'),
    (code: 'COMPLETED', label: 'Selesai'),
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
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansState = ref.watch(plantPlanListNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(child: _buildStatusFilter()),
            SliverToBoxAdapter(child: _buildSummaryStats(plansState)),
            plansState.when(
              data: (plans) => plans.isEmpty
                  ? SliverFillRemaining(child: _buildEmpty())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (i == plans.length) return _buildLoadMore();
                          return _PlantPlanCard(
                            plan: plans[i],
                            index: i,
                            onTap: () =>
                                context.push('/app/plant/${plans[i].id}'),
                          );
                        },
                        childCount: plans.length + 1,
                      ),
                    ),
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _PlantPlanSkeleton(),
                  childCount: 5,
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _buildError(e.toString()),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 110,
      backgroundColor: const Color(0xFF0A0F0A),
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plant Process',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Color(0xFFF0FDF4),
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1F0F), Color(0xFF0A0F0A)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: _statusFilters.map((f) {
          final selected = _selectedStatus == f.code;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedStatus = f.code);
                ref
                    .read(plantPlanListNotifierProvider.notifier)
                    .filterByStatus(f.code);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  f.label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF4B7A5F),
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryStats(AsyncValue<List<PlantPlanSummary>> state) {
    return state.maybeWhen(
      data: (plans) {
        final active = plans.where((p) => p.status == 'ACTIVE').length;
        final draft = plans.where((p) => p.status == 'DRAFT').length;
        final completed = plans.where((p) => p.status == 'COMPLETED').length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _StatChip(label: 'Aktif', value: active, color: const Color(0xFF22C55E)),
              const SizedBox(width: 8),
              _StatChip(label: 'Draft', value: draft, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              _StatChip(label: 'Selesai', value: completed, color: const Color(0xFF0284C7)),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
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
            child: const Icon(Icons.eco_outlined,
                color: Color(0xFF4B7A5F), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada process plan',
            style: TextStyle(
              color: Color(0xFFF0FDF4),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Buat process plan baru dengan\nmenekan tombol + di bawah',
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 16),
          const Text('Gagal memuat data',
              style: TextStyle(
                  color: Color(0xFFF0FDF4),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.refresh(plantPlanListNotifierProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMore() {
    final notifier = ref.read(plantPlanListNotifierProvider.notifier);
    if (!notifier.hasMore) return const SizedBox(height: 80);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: OutlinedButton(
          onPressed: notifier.loadMore,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF22C55E),
            side: const BorderSide(color: Color(0xFF22C55E)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Muat lebih banyak'),
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        // Navigate to create plant plan flow
        // context.push('/app/plant/new');
      },
      backgroundColor: const Color(0xFF22C55E),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text(
        'Buat Plan',
        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Plant Plan Card ────────────────────────────────────────────────────────

class _PlantPlanCard extends StatefulWidget {
  final PlantPlanSummary plan;
  final int index;
  final VoidCallback onTap;

  const _PlantPlanCard({
    required this.plan,
    required this.index,
    required this.onTap,
  });

  @override
  State<_PlantPlanCard> createState() => _PlantPlanCardState();
}

class _PlantPlanCardState extends State<_PlantPlanCard>
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
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
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

  double get _progress =>
      widget.plan.totalSteps > 0
          ? widget.plan.completedSteps / widget.plan.totalSteps
          : 0;

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
                color: _hovering ? const Color(0xFF1A2E1E) : const Color(0xFF162019),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hovering
                      ? const Color(0xFF22C55E).withValues(alpha: 0.4)
                      : const Color(0xFF1F4A30),
                ),
                boxShadow: _hovering
                    ? [BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )]
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
                      // Header row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.plan.planCode,
                                  style: const TextStyle(
                                    color: Color(0xFFF0FDF4),
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (widget.plan.lotCode != null) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined,
                                          size: 11,
                                          color: Color(0xFF4B7A5F)),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.plan.lotCode!,
                                        style: const TextStyle(
                                          color: Color(0xFF4B7A5F),
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _PlanStatusBadge(status: widget.plan.status),
                        ],
                      ),
                      if (widget.plan.productName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.plan.productName!,
                          style: const TextStyle(
                            color: Color(0xFF86EFAC),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Progress
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.plan.currentStepName ?? 'Menunggu mulai',
                                style: const TextStyle(
                                  color: Color(0xFF86EFAC),
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${widget.plan.completedSteps}/${widget.plan.totalSteps} step',
                                style: const TextStyle(
                                  color: Color(0xFF4B7A5F),
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: const Color(0xFF1F4A30),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _progress >= 1.0
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFF16A34A),
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                      if (widget.plan.siteName != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.factory_outlined,
                                color: Color(0xFF4B7A5F), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              widget.plan.siteName!,
                              style: const TextStyle(
                                color: Color(0xFF4B7A5F),
                                fontFamily: 'Inter',
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _PlantPlanSkeleton extends StatefulWidget {
  const _PlantPlanSkeleton();
  @override
  State<_PlantPlanSkeleton> createState() => _PlantPlanSkeletonState();
}

class _PlantPlanSkeletonState extends State<_PlantPlanSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.4, end: 0.9).animate(_c);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
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
            Row(children: [
              _S(w: 130, h: 14, o: _a.value),
              const Spacer(),
              _S(w: 60, h: 22, o: _a.value),
            ]),
            const SizedBox(height: 10),
            _S(w: 90, h: 12, o: _a.value),
            const SizedBox(height: 14),
            _S(w: double.infinity, h: 4, o: _a.value),
          ],
        ),
      ),
    ),
  );
}

class _S extends StatelessWidget {
  final double w, h, o;
  const _S({required this.w, required this.h, required this.o});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: o,
    child: Container(
      width: w == double.infinity ? null : w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1F4A30),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _PlanStatusBadge extends StatelessWidget {
  final String status;
  const _PlanStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status.toUpperCase()) {
      'ACTIVE' => (const Color(0xFF22C55E), const Color(0xFF22C55E), 'Aktif'),
      'DRAFT' => (const Color(0xFF6B7280), const Color(0xFF6B7280), 'Draft'),
      'ON_HOLD' => (const Color(0xFFF59E0B), const Color(0xFFF59E0B), 'Ditahan'),
      'COMPLETED' => (const Color(0xFF0284C7), const Color(0xFF0284C7), 'Selesai'),
      'CANCELLED' => (const Color(0xFFEF4444), const Color(0xFFEF4444), 'Dibatalkan'),
      _ => (const Color(0xFF86EFAC), const Color(0xFF86EFAC), status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
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
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontFamily: 'Inter',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
