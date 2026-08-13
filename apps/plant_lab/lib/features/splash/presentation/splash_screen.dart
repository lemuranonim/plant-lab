import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_colors.dart';

class PlantLabSplashScreen extends StatefulWidget {
  const PlantLabSplashScreen({super.key});

  @override
  State<PlantLabSplashScreen> createState() => _PlantLabSplashScreenState();
}

class _PlantLabSplashScreenState extends State<PlantLabSplashScreen> {
  static const _minimumSplashDuration = Duration(milliseconds: 2600);

  final DateTime _startedAt = DateTime.now();
  String _version = 'Loading...';
  double _progress = 0.2;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    unawaited(_continue());
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = packageInfo.version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = '1.0.0');
    }
  }

  Future<void> _continue() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _setLoadingProgress(0.65);

    final supabaseUser = Supabase.instance.client.auth.currentUser;

    _setLoadingProgress(1.0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await _waitForMinimumSplash();
    if (!mounted) return;

    if (supabaseUser == null) {
      context.go('/login');
    } else {
      context.go('/app/dashboard');
    }
  }

  Future<void> _waitForMinimumSplash() async {
    final elapsed = DateTime.now().difference(_startedAt);
    final remaining = _minimumSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  void _setLoadingProgress(double progress) {
    if (!mounted) return;
    setState(() {
      _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient (Advanta Navy Theme)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF002855), // Plant+Lab Navy
                  Color(0xFF011A3A),
                  Color(0xFF001127),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Circular Glowing Logo (GOT FET Layout Style)
                  Container(
                    width: 154,
                    height: 154,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 48,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo_plant_lab.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Plant + Lab',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quality & Operations Analytics\nAdvanta Seeds Indonesia',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(flex: 3),
                  _SplashLoadingMark(progress: _progress),
                  const SizedBox(height: 14),
                  Text(
                    'v$_version',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashLoadingMark extends StatelessWidget {
  final double progress;

  const _SplashLoadingMark({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PremiumOrbitRing(progress: progress),
        const SizedBox(height: 12),
        Text(
          'Memuat...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumOrbitRing extends StatefulWidget {
  final double progress;

  const _PremiumOrbitRing({required this.progress});

  @override
  State<_PremiumOrbitRing> createState() => _PremiumOrbitRingState();
}

class _PremiumOrbitRingState extends State<_PremiumOrbitRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.progress),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: const Size.square(64),
              painter: _PremiumOrbitRingPainter(
                orbit: _controller.value,
                progress: progress,
              ),
            );
          },
        );
      },
    );
  }
}

class _PremiumOrbitRingPainter extends CustomPainter {
  final double orbit;
  final double progress;

  const _PremiumOrbitRingPainter({
    required this.orbit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 11) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = (orbit * math.pi * 2) - math.pi / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawArc(
      rect.deflate(7),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..color = AppColors.accent.withValues(alpha: 0.5);
    canvas.drawArc(rect, start, math.pi * 0.86, false, glowPaint);

    final greenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent;
    canvas.drawArc(rect, start, math.pi * 0.86, false, greenPaint);
  }

  @override
  bool shouldRepaint(covariant _PremiumOrbitRingPainter oldDelegate) {
    return oldDelegate.orbit != orbit || oldDelegate.progress != progress;
  }
}
