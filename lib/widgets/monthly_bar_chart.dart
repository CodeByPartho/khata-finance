import 'package:flutter/material.dart';

import '../utils/format.dart';

/// A bar chart of monthly expenses for the last 6 months, drawn by
/// hand with CustomPainter so the app needs no chart library.
class MonthlyBarChart extends StatelessWidget {
  final List<({DateTime month, double total})> data;

  const MonthlyBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarChartPainter(
          data: data,
          barColor: scheme.primary,
          gridColor: Colors.white.withValues(alpha: 0.07),
          labelColor: Colors.white.withValues(alpha: 0.65),
          valueColor: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<({DateTime month, double total})> data;
  final Color barColor;
  final Color gridColor;
  final Color labelColor;
  final Color valueColor;

  _BarChartPainter({
    required this.data,
    required this.barColor,
    required this.gridColor,
    required this.labelColor,
    required this.valueColor,
  });

  static const double _topPadding = 22;
  static const double _bottomPadding = 24;
  static const double _sidePadding = 8;

  String _valueLabel(double value) {
    if (value <= 0) {
      return '0';
    }
    if (value >= 1000) {
      final double k = value / 1000;
      final String text =
          k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
      return '${text}k';
    }
    return value.round().toString();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(anchor.dx - painter.width / 2, anchor.dy),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      _drawText(
        canvas,
        'No data yet',
        Offset(size.width / 2, size.height / 2 - 8),
        labelColor,
        12,
      );
      return;
    }

    double maxValue = 0;
    for (final ({DateTime month, double total}) entry in data) {
      if (entry.total > maxValue) {
        maxValue = entry.total;
      }
    }

    const double chartTop = _topPadding;
    final double chartBottom = size.height - _bottomPadding;
    final double chartHeight = chartBottom - chartTop;
    final double chartWidth = size.width - (_sidePadding * 2);

    // Gridlines and baseline.
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final double y = chartBottom - (chartHeight * i / 4);
      canvas.drawLine(
        Offset(_sidePadding, y),
        Offset(size.width - _sidePadding, y),
        gridPaint,
      );
    }

    final double slotWidth = chartWidth / data.length;
    final double barWidth = slotWidth * 0.52;
    final Paint barPaint = Paint()..color = barColor;

    for (int i = 0; i < data.length; i++) {
      final ({DateTime month, double total}) entry = data[i];
      final double ratio = maxValue <= 0 ? 0 : entry.total / maxValue;
      final double barHeight = chartHeight * ratio;
      final double centerX = _sidePadding + (slotWidth * i) + (slotWidth / 2);
      final double left = centerX - (barWidth / 2);
      final double top = chartBottom - barHeight;

      if (barHeight > 0) {
        final RRect bar = RRect.fromRectAndCorners(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        );
        canvas.drawRRect(bar, barPaint);
      } else {
        // Zero month: draw a small baseline tick so the slot is visible.
        canvas.drawLine(
          Offset(left, chartBottom - 1),
          Offset(left + barWidth, chartBottom - 1),
          Paint()
            ..color = barColor.withValues(alpha: 0.4)
            ..strokeWidth = 2,
        );
      }

      _drawText(
        canvas,
        _valueLabel(entry.total),
        Offset(centerX, top - 18 < 0 ? 0 : top - 18),
        valueColor,
        10,
      );
      _drawText(
        canvas,
        fmtMonthShort(entry.month),
        Offset(centerX, chartBottom + 6),
        labelColor,
        11,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.barColor != barColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.valueColor != valueColor;
  }
}
