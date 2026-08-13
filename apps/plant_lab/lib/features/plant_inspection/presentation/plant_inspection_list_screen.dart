import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plant_lab/features/plant_inspection/domain/plant_inspection.dart';

/// Riverpod providers for Inspection feature (simplified - no codegen needed for simple providers)
final inspectionListProvider = FutureProvider.family<List<PlantInspectionSummary>, String>(
  (ref, planId) async {
    // TODO: inject InspectionRepository via ref
    // For now returns empty list until codegen runs
    return [];
  },
);

class PlantInspectionListScreen extends ConsumerStatefulWidget {
  final String planId;
  const PlantInspectionListScreen({super.key, required this.planId});

  @override
  ConsumerState<PlantInspectionListScreen> createState() =>
      _PlantInspectionListScreenState();
}

class _PlantInspectionListScreenState
    extends ConsumerState<PlantInspectionListScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inspections = ref.watch(inspectionListProvider(widget.planId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 90,
              pinned: true,
              backgroundColor: const Color(0xFF0A0F0A),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF86EFAC), size: 18),
                onPressed: () => context.pop(),
              ),
              flexibleSpace: const FlexibleSpaceBar(
                titlePadding: EdgeInsets.fromLTRB(52, 0, 16, 16),
                title: Text(
                  'Inspeksi',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Color(0xFFF0FDF4),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildOfflineBanner()),
            inspections.when(
              data: (list) => list.isEmpty
                  ? SliverFillRemaining(child: _buildEmpty())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _InspectionCard(
                          inspection: list[i],
                          index: i,
                          onTap: () => context.push(
                              '/app/plant/${widget.planId}/inspection/${list[i].id}'),
                        ),
                        childCount: list.length,
                      ),
                    ),
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _InspectionSkeleton(),
                  childCount: 4,
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Text(
                    e.toString(),
                    style: const TextStyle(color: Color(0xFFEF4444), fontFamily: 'Inter'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openInspectionForm(context),
        backgroundColor: const Color(0xFF22C55E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.assignment_add),
        label: const Text(
          'Mulai Inspeksi',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    // TODO: check connectivity_plus
    return const SizedBox.shrink();
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
            child: const Icon(Icons.assignment_outlined,
                color: Color(0xFF4B7A5F), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada inspeksi',
            style: TextStyle(
                color: Color(0xFFF0FDF4),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap tombol "Mulai Inspeksi" untuk memulai\ninspeksi baru pada process plan ini',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF4B7A5F), fontFamily: 'Inter', fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _openInspectionForm(BuildContext context) {
    context.push('/app/plant/${widget.planId}/inspection/new');
  }
}

// ── Inspection Card ────────────────────────────────────────────────────────

class _InspectionCard extends StatefulWidget {
  final PlantInspectionSummary inspection;
  final int index;
  final VoidCallback onTap;

  const _InspectionCard({
    required this.inspection,
    required this.index,
    required this.onTap,
  });

  @override
  State<_InspectionCard> createState() => _InspectionCardState();
}

class _InspectionCardState extends State<_InspectionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: 280 + widget.index * 35));
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 40),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _statusColor {
    return switch (widget.inspection.status.toUpperCase()) {
      'APPROVED' => const Color(0xFF22C55E),
      'SUBMITTED' || 'UNDER_REVIEW' => const Color(0xFF0284C7),
      'NEED_REVISION' => const Color(0xFFF59E0B),
      'OOS' => const Color(0xFFEF4444),
      'REJECTED' => const Color(0xFFDC2626),
      _ => const Color(0xFF6B7280),
    };
  }

  String get _statusLabel {
    return switch (widget.inspection.status.toUpperCase()) {
      'DRAFT' => 'Draft',
      'SUBMITTED' => 'Terkirim',
      'UNDER_REVIEW' => 'Sedang Review',
      'APPROVED' => 'Disetujui',
      'NEED_REVISION' => 'Perlu Revisi',
      'OOS' => 'Out of Spec',
      'REJECTED' => 'Ditolak',
      _ => widget.inspection.status,
    };
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
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _hover ? const Color(0xFF1A2E1E) : const Color(0xFF162019),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hover
                      ? const Color(0xFF22C55E).withValues(alpha: 0.35)
                      : const Color(0xFF1F4A30),
                ),
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Status indicator line
                      Container(
                        width: 3,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.inspection.inspectionCode,
                              style: const TextStyle(
                                color: Color(0xFFF0FDF4),
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (widget.inspection.formTemplateName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.inspection.formTemplateName!,
                                style: const TextStyle(
                                  color: Color(0xFF4B7A5F),
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (widget.inspection.inspectorName != null) ...[
                                  const Icon(Icons.person_outline,
                                      size: 11, color: Color(0xFF4B7A5F)),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.inspection.inspectorName!,
                                    style: const TextStyle(
                                      color: Color(0xFF4B7A5F),
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                if (widget.inspection.hasOos == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                    ),
                                    child: const Text(
                                      '⚠ OOS',
                                      style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: _statusColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _statusLabel,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF4B7A5F), size: 16),
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

class _InspectionSkeleton extends StatefulWidget {
  const _InspectionSkeleton();
  @override
  State<_InspectionSkeleton> createState() => _InspectionSkeletonState();
}

class _InspectionSkeletonState extends State<_InspectionSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.4, end: 0.85).animate(_c);
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1F4A30)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Opacity(
              opacity: _a.value,
              child: Container(
                width: 3,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F4A30),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Opacity(opacity: _a.value,
                    child: Container(width: 140, height: 13,
                        decoration: BoxDecoration(color: const Color(0xFF1F4A30),
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 8),
                Opacity(opacity: _a.value,
                    child: Container(width: 100, height: 11,
                        decoration: BoxDecoration(color: const Color(0xFF1F4A30),
                            borderRadius: BorderRadius.circular(4)))),
              ]),
            ),
            Opacity(opacity: _a.value,
                child: Container(width: 64, height: 24,
                    decoration: BoxDecoration(color: const Color(0xFF1F4A30),
                        borderRadius: BorderRadius.circular(20)))),
          ],
        ),
      ),
    ),
  );
}
