import 'dart:math';
import 'package:flutter/material.dart';

// ─── Particle data ───────────────────────────────────────────────
class _Particle {
  double x, y, size, speed, opacity, angle;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.angle,
  });
}

// ─── Splash Screen ──────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // 3‑D logo spin
  late final AnimationController _rotateCtrl;
  // Overall entrance sequence
  late final AnimationController _entryCtrl;
  // Particles
  late final AnimationController _particleCtrl;
  // Text & fade‑out
  late final AnimationController _exitCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textSlide;
  late final Animation<double> _textOpacity;
  late final Animation<double> _exitOpacity;

  final List<_Particle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();

    // ── Particles ──────────────────────────────────
    for (int i = 0; i < 50; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 1,
        speed: _random.nextDouble() * 0.4 + 0.1,
        opacity: _random.nextDouble() * 0.6 + 0.2,
        angle: _random.nextDouble() * 2 * pi,
      ));
    }

    // ── 3‑D Rotation (continuous 360°) ─────────────
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // ── Entry (scale + fade) ───────────────────────
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _textSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.45, 0.85, curve: Curves.easeIn),
      ),
    );

    // ── Particles tick ─────────────────────────────
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // ── Exit fade‑out ──────────────────────────────
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // 1) logo spins in one full turn while scaling up
    _rotateCtrl.forward();
    _entryCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 3200));
    // 2) fade‑out then navigate
    if (!mounted) return;
    await _exitCtrl.forward();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _entryCtrl.dispose();
    _particleCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_entryCtrl, _rotateCtrl, _particleCtrl, _exitCtrl]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exitOpacity,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F0F1A),
                    Color(0xFF1A1025),
                    Color(0xFF0F0F1A),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // ── Particles layer ───────────
                  ..._buildParticles(context),

                  // ── Radial glow behind logo ───
                  Center(
                    child: Opacity(
                      opacity: _logoOpacity.value * 0.5,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFF97316).withValues(alpha: 0.35),
                              const Color(0xFFF97316).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Main content ──────────────
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3‑D rotating logo
                        Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001) // perspective
                                ..rotateY(
                                    _rotateCtrl.value * 2 * pi), // full spin
                              child: _buildGearLogo(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // App name
                        Transform.translate(
                          offset: Offset(0, _textSlide.value),
                          child: Opacity(
                            opacity: _textOpacity.value,
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFF97316),
                                  Color(0xFFFFD700),
                                  Color(0xFFF97316),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'AutoMarket DZ',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Subtitle
                        Transform.translate(
                          offset: Offset(0, _textSlide.value),
                          child: Opacity(
                            opacity: _textOpacity.value * 0.85,
                            child: const Text(
                              'قطع غيار جميع المركبات',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFFCCCCCC),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Loading bar
                        Opacity(
                          opacity: _textOpacity.value,
                          child: SizedBox(
                            width: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFFF97316)),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Gear + wrench logo (drawn programmatically) ──────────────
  Widget _buildGearLogo() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFFFF6B00).withValues(alpha: 0.25),
            blurRadius: 80,
            spreadRadius: 15,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _GearWrenchPainter(),
      ),
    );
  }

  // ── Floating particles ──────────────────────────────────────
  List<Widget> _buildParticles(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final t = _particleCtrl.value;

    return _particles.map((p) {
      final dx = p.x * size.width + sin(t * 2 * pi * p.speed + p.angle) * 30;
      final dy = (p.y * size.height - t * p.speed * 200) % size.height;
      final opacity = p.opacity * _logoOpacity.value;

      return Positioned(
        left: dx,
        top: dy,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            width: p.size,
            height: p.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                const Color(0xFFF97316),
                const Color(0xFFFFD700),
                _random.nextDouble(),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ─── Custom Painter: Gear + Wrench ─────────────────────────────
class _GearWrenchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // ── Outer gear teeth ──
    const orange = Color(0xFFF97316);
    const darkOrange = Color(0xFFEA580C);

    final outerR = size.width * 0.46;
    final innerR = size.width * 0.34;
    const teeth = 10;

    final gearPath = Path();
    for (int i = 0; i < teeth; i++) {
      final a1 = (i / teeth) * 2 * pi - pi / 2;
      final a2 = ((i + 0.35) / teeth) * 2 * pi - pi / 2;
      final a3 = ((i + 0.5) / teeth) * 2 * pi - pi / 2;
      final a4 = ((i + 0.85) / teeth) * 2 * pi - pi / 2;

      if (i == 0) {
        gearPath.moveTo(cx + innerR * cos(a1), cy + innerR * sin(a1));
      }
      gearPath.lineTo(cx + outerR * cos(a2), cy + outerR * sin(a2));
      gearPath.lineTo(cx + outerR * cos(a3), cy + outerR * sin(a3));
      gearPath.lineTo(cx + innerR * cos(a4), cy + innerR * sin(a4));

      final aNext = ((i + 1) / teeth) * 2 * pi - pi / 2;
      gearPath.lineTo(cx + innerR * cos(aNext), cy + innerR * sin(aNext));
    }
    gearPath.close();

    paint.shader = RadialGradient(
      colors: [orange, darkOrange],
      center: const Alignment(-0.3, -0.3),
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: outerR));
    canvas.drawPath(gearPath, paint);

    // ── Inner circle (hole) ──
    final holeR = size.width * 0.2;
    paint
      ..shader = null
      ..color = const Color(0xFF1A1025);
    canvas.drawCircle(Offset(cx, cy), holeR, paint);

    // ── Inner ring ──
    paint
      ..color = orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(cx, cy), holeR - 3, paint);
    paint.style = PaintingStyle.fill;

    // ── Wrench ──
    _drawWrench(canvas, cx, cy, size.width * 0.15, orange);
  }

  void _drawWrench(
      Canvas canvas, double cx, double cy, double scale, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Handle (vertical bar)
    final handleW = scale * 0.35;
    final handleH = scale * 1.6;
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy + scale * 0.25),
          width: handleW,
          height: handleH),
      Radius.circular(handleW / 2),
    );
    canvas.drawRRect(rr, paint);

    // Top jaw (open‑end wrench)
    final jawW = scale * 0.7;
    final jawH = scale * 0.45;
    final jawY = cy - scale * 0.45;

    final jawPath = Path()
      ..moveTo(cx - jawW / 2, jawY + jawH)
      ..lineTo(cx - jawW / 2, jawY + jawH * 0.3)
      ..quadraticBezierTo(cx - jawW / 2, jawY, cx - jawW * 0.2, jawY)
      ..lineTo(cx - handleW * 0.3, jawY)
      ..lineTo(cx - handleW * 0.3, jawY + jawH * 0.5)
      ..moveTo(cx + handleW * 0.3, jawY + jawH * 0.5)
      ..lineTo(cx + handleW * 0.3, jawY)
      ..lineTo(cx + jawW * 0.2, jawY)
      ..quadraticBezierTo(cx + jawW / 2, jawY, cx + jawW / 2, jawY + jawH * 0.3)
      ..lineTo(cx + jawW / 2, jawY + jawH);

    canvas.drawPath(jawPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
