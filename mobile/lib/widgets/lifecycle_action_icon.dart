import 'package:flutter/material.dart';

/// 方案 A 复合矢量图标：箱子 + 出/入箭头（与 Lucide 2px 圆润线性风格一致）
/// - [isInUse] 为 false 时：开箱 + 右上出库箭头（取出使用）
/// - [isInUse] 为 true 时：箱子 + 左下归位箭头（归还收纳）
class LifecycleActionIcon extends StatelessWidget {
  final bool isInUse;
  final Color color;
  final double size;

  const LifecycleActionIcon({
    super.key,
    required this.isInUse,
    this.color = Colors.white,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LifecycleIconPainter(isInUse: isInUse, color: color),
    );
  }
}

class _LifecycleIconPainter extends CustomPainter {
  final bool isInUse;
  final Color color;

  _LifecycleIconPainter({required this.isInUse, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w / 24.0) * 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. 底部收纳箱主体 (占左下 75% 区域)
    final boxPath = Path()
      ..moveTo(w * 0.14, h * 0.42)
      ..lineTo(w * 0.14, h * 0.80)
      ..quadraticBezierTo(w * 0.14, h * 0.88, w * 0.22, h * 0.88)
      ..lineTo(w * 0.68, h * 0.88)
      ..quadraticBezierTo(w * 0.76, h * 0.88, w * 0.76, h * 0.80)
      ..lineTo(w * 0.76, h * 0.48);
    canvas.drawPath(boxPath, paint);

    // 箱盖左侧与横梁
    canvas.drawLine(Offset(w * 0.10, h * 0.42), Offset(w * 0.48, h * 0.42), paint);
    // 箱体中心提手短线
    canvas.drawLine(Offset(w * 0.36, h * 0.60), Offset(w * 0.54, h * 0.60), paint);

    // 2. 右上角方向箭头（取出：↗；归还：↙）
    if (!isInUse) {
      // 取出使用：向外斜上箭头 ↗
      canvas.drawLine(Offset(w * 0.56, h * 0.42), Offset(w * 0.86, h * 0.14), paint);
      final head = Path()
        ..moveTo(w * 0.66, h * 0.14)
        ..lineTo(w * 0.86, h * 0.14)
        ..lineTo(w * 0.86, h * 0.34);
      canvas.drawPath(head, paint);
    } else {
      // 归还收纳：向内斜下箭头 ↙
      canvas.drawLine(Offset(w * 0.86, h * 0.14), Offset(w * 0.56, h * 0.42), paint);
      final head = Path()
        ..moveTo(w * 0.56, h * 0.22)
        ..lineTo(w * 0.56, h * 0.42)
        ..lineTo(w * 0.76, h * 0.42);
      canvas.drawPath(head, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LifecycleIconPainter oldDelegate) =>
      oldDelegate.isInUse != isInUse || oldDelegate.color != color;
}

