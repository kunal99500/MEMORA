import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class MemoryNetworkIllustration extends StatefulWidget {
  final double height;
  const MemoryNetworkIllustration({super.key, required this.height});

  @override
  State<MemoryNetworkIllustration> createState() =>
      _MemoryNetworkIllustrationState();
}

class _MemoryNetworkIllustrationState extends State<MemoryNetworkIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = widget.height;
            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MemoryNetworkPainter(_controller.value),
                    ),
                  ),
                  Positioned(
                    left: width * .04,
                    top: height * .11,
                    child: _MemoryCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Memory indexed',
                      subtitle: '124 objects · 8 rooms',
                      color: MemoraColors.cyan,
                      scale: math.min(height / 390, 1),
                    ),
                  ),
                  Positioned(
                    right: width * .02,
                    bottom: height * .08,
                    child: _MemoryCard(
                      icon: Icons.location_on_rounded,
                      title: 'Keys last seen',
                      subtitle: 'Entryway shelf · 9:42 AM',
                      color: MemoraColors.gold,
                      scale: math.min(height / 390, 1),
                    ),
                  ),
                  Positioned(
                    left: width * .27,
                    bottom: height * .17,
                    child: _PulseLabel(progress: _controller.value),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

class _MemoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final double scale;

  const _MemoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: EdgeInsets.symmetric(
          horizontal: 12 * scale.clamp(.62, 1),
          vertical: 9 * scale.clamp(.62, 1),
        ),
        decoration: BoxDecoration(
          color: const Color(0xE810243B),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: .4)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .12), blurRadius: 22),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17 * scale.clamp(.72, 1), color: color),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 11 * scale.clamp(.78, 1),
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                    fontSize: 9 * scale.clamp(.78, 1),
                    color: MemoraColors.muted,
                  )),
            ],
          ),
        ]),
      );
}

class _PulseLabel extends StatelessWidget {
  final double progress;
  const _PulseLabel({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pulse = .65 + .35 * math.sin(progress * math.pi * 2);
    return Opacity(
      opacity: pulse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xCC10243B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MemoraColors.cyan.withValues(alpha: .28)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hub_rounded, size: 13, color: MemoraColors.cyan),
          SizedBox(width: 6),
          Text('Your home, connected',
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _MemoryNetworkPainter extends CustomPainter {
  final double progress;
  _MemoryNetworkPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .52, size.height * .49);
    final radius = math.min(size.width, size.height) * .28;
    final cyan = Paint()
      ..color = MemoraColors.cyan.withValues(alpha: .1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawCircle(center, radius * 1.15, cyan);

    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = MemoraColors.cyan.withValues(alpha: .22);
    canvas.drawCircle(center, radius, orbit);
    canvas.drawCircle(center, radius * .67,
        orbit..color = MemoraColors.blue.withValues(alpha: .13));

    final nodes = <Offset>[];
    for (var i = 0; i < 6; i++) {
      final angle = math.pi * 2 * i / 6 + progress * .38;
      nodes.add(center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * .72));
    }

    for (var i = 0; i < nodes.length; i++) {
      canvas.drawLine(
        center,
        nodes[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = (i.isEven ? MemoraColors.cyan : MemoraColors.gold)
              .withValues(alpha: .38),
      );
      final pulse = .7 + .3 * math.sin(progress * math.pi * 2 + i);
      canvas.drawCircle(
        nodes[i],
        (4 + pulse * 2),
        Paint()..color = i.isEven ? MemoraColors.cyan : MemoraColors.gold,
      );
      canvas.drawCircle(
        nodes[i],
        10 + pulse * 3,
        Paint()
          ..color = (i.isEven ? MemoraColors.cyan : MemoraColors.gold)
              .withValues(alpha: .1),
      );
    }

    final coreGlow = Paint()
      ..color = MemoraColors.gold.withValues(alpha: .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius * .3, coreGlow);
    canvas.drawCircle(
      center,
      radius * .21,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFBDEAFF), Color(0xFF398AF2)],
        ).createShader(Rect.fromCircle(center: center, radius: radius * .21)),
    );
    canvas.drawCircle(
      center,
      radius * .21,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: .65),
    );

    final sweep = progress * math.pi * 2;
    final scanner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = MemoraColors.cyan.withValues(alpha: .76)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweep,
      math.pi * .28,
      false,
      scanner,
    );
  }

  @override
  bool shouldRepaint(covariant _MemoryNetworkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
