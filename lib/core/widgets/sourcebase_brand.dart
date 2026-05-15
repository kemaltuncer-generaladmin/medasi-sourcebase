import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SourceBaseBrand extends StatelessWidget {
  const SourceBaseBrand({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 38.0 : 54.0;
    final textSize = compact ? 22.0 : 34.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SourceBaseMark(size: markSize),
          SizedBox(width: compact ? 8 : 12),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: textSize,
                height: 1,
                letterSpacing: 0,
                fontWeight: FontWeight.w500,
              ),
              children: const [
                TextSpan(
                  text: 'Source',
                  style: TextStyle(color: Color(0xFF0C18B8)),
                ),
                TextSpan(
                  text: 'Base',
                  style: TextStyle(color: AppColors.cyan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SourceBaseMark extends StatelessWidget {
  const SourceBaseMark({this.size = 54, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: LogoMarkPainter()),
    );
  }
}

class LogoMarkPainter extends CustomPainter {
  const LogoMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 70, size.height / 62);
    canvas
      ..save()
      ..scale(scale)
      ..translate(
        (size.width / scale - 70) / 2,
        (size.height / scale - 62) / 2,
      );

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final lower = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF11D2D4), Color(0xFF1481F5)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(const Rect.fromLTWH(0, 0, 70, 62));
    final upper = Paint()
      ..shader = AppColors.brandGradient.createShader(
        const Rect.fromLTWH(0, 0, 70, 62),
      );

    RRect slab(double x, double y, double w, double h) {
      return RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(9),
      );
    }

    canvas.drawRRect(slab(6, 28, 46, 20), lower);
    canvas.drawRRect(slab(12, 18, 46, 22), lower);
    canvas.drawRRect(slab(18, 8, 46, 24).shift(const Offset(0, 4)), shadow);
    canvas.drawRRect(slab(18, 8, 46, 24), upper);

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(41, 19), 7, white);
    canvas.drawLine(const Offset(41, 4), const Offset(41, 19), white);
    canvas.drawLine(const Offset(35, 25), const Offset(41, 31), white);
    canvas.drawLine(const Offset(47, 25), const Offset(41, 31), white);
    final spark = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(41, 2), 2.2, spark);
    canvas.drawCircle(const Offset(41, 37), 2.2, spark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
