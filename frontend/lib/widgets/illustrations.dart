import 'package:flutter/material.dart';

import 'memory_network_illustration.dart';

class FloatingHomeIllustration extends StatelessWidget {
  final double height;
  const FloatingHomeIllustration({super.key, this.height = 390});

  @override
  Widget build(BuildContext context) =>
      MemoryNetworkIllustration(height: height);
}

class FamilyIllustration extends StatelessWidget {
  const FamilyIllustration({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 105,
        child: CustomPaint(
          painter: _FamilyPainter(),
          child: const SizedBox.expand(),
        ),
      );
}

class _FamilyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x66E98E85), Color(0x00E98E85)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height),
        radius: size.width * .6,
      ));
    canvas.drawRect(Offset.zero & size, paint);

    const colors = [
      Color(0xFFCBA06A),
      Color(0xFFE58A83),
      Color(0xFF7FC7D4),
      Color(0xFFB7A6D4),
    ];
    const skin = [
      Color(0xFFE5B18B),
      Color(0xFFE9B58E),
      Color(0xFFDDA77F),
      Color(0xFFE8C29B),
    ];
    const heights = [55.0, 70.0, 48.0, 43.0];
    for (var i = 0; i < colors.length; i++) {
      final x = size.width * .25 + i * size.width * .15;
      final h = heights[i];
      paint
        ..shader = null
        ..color = colors[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 13, size.height - h, 26, h),
          const Radius.circular(10),
        ),
        paint,
      );
      paint.color = skin[i];
      canvas.drawCircle(Offset(x, size.height - h - 10), 11, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InventoryIllustration extends StatelessWidget {
  const InventoryIllustration({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 105,
        child: CustomPaint(
          painter: _InventoryPainter(),
          child: const SizedBox.expand(),
        ),
      );
}

class _InventoryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shelf = Paint()
      ..color = const Color(0xFF9B7957)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRect(
      Rect.fromLTWH(size.width * .12, 10, size.width * .76, size.height - 18),
      shelf,
    );

    const colors = [
      Color(0xFFD7A15E),
      Color(0xFF7FC7D4),
      Color(0xFF9A6E4A),
      Color(0xFFC9A063),
    ];
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 5; col++) {
        final x = size.width * .17 + col * size.width * .135;
        final y = 22 + row * 39.0;
        final rect = Rect.fromLTWH(x, y, size.width * .095, row == 0 ? 30 : 31);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = colors[(col + row) % colors.length],
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: .4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
