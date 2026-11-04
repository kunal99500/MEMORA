import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tint;
  final VoidCallback? onTap;
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tint ?? MemoraColors.blue).withValues(alpha: .13),
                Colors.white.withValues(alpha: .055),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: MemoraColors.line),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF020A14).withValues(alpha: .32),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: .08),
                blurRadius: 1,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: content,
    );
  }
}

class GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool primary;
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: MemoraColors.goldDeep.withValues(alpha: .30),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 17),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          foregroundColor: primary ? MemoraColors.bg : Colors.white,
          backgroundColor: primary ? MemoraColors.gold : Colors.white10,
          side: primary ? BorderSide.none : const BorderSide(color: MemoraColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  const SectionTitle({super.key, required this.eyebrow, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(),
            style: const TextStyle(
                color: MemoraColors.gold,
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Text(title,
            style: const TextStyle(
                fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -.7)),
        if (subtitle != null) ...[
          const SizedBox(height: 7),
          Text(subtitle!, style: const TextStyle(color: MemoraColors.muted, fontSize: 12)),
        ],
      ],
    );
  }
}

class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.7, -.8),
              radius: 1.25,
              colors: [Color(0x443887F6), MemoraColors.bg],
            ),
          ),
        )),
        Positioned(
          top: -100, right: -90,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MemoraColors.violet.withValues(alpha: .08),
              boxShadow: [
                BoxShadow(
                  color: MemoraColors.blue.withValues(alpha: .12),
                  blurRadius: 90,
                  spreadRadius: 40,
                )
              ],
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}


class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 30});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .3),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MemoraColors.gold, MemoraColors.goldDeep]),
          boxShadow: [
            BoxShadow(
                color: MemoraColors.goldDeep.withValues(alpha: .35),
                blurRadius: size * .5,
                offset: const Offset(0, 4))
          ],
        ),
        child: Center(
            child: SizedBox(
                width: size * .57,
                height: size * .57,
                child: const CustomPaint(painter: _LensPainter()))),
      );
}

class _LensPainter extends CustomPainter {
  const _LensPainter();
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    const ink = Color(0xFF1C1403);
    c.drawCircle(
        Offset(cx, cy),
        s.width * .42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * .11
          ..color = ink);
    c.drawCircle(Offset(cx, cy), s.width * .15, Paint()..color = ink);
    c.drawCircle(Offset(cx - s.width * .12, cy - s.height * .12),
    s.width * .07, Paint()..color = Colors.white.withValues(alpha: .85));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
