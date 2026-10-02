import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'lamp_controller.dart';
import 'lamp_physics.dart';

const _warmLight = Color(0xFFFFD58A);

class LampPainter extends CustomPainter {
  LampPainter(this.controller) : super(repaint: controller);

  final LampController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final lamp = controller.physics;
    final light = controller.brightness;
    final screen = Offset.zero & size;

    canvas.drawRect(screen, Paint()..color = const Color(0xFF1A1714));
    if (light > 0.01) {
      canvas.drawRect(
        screen,
        Paint()
          ..shader = ui.Gradient.radial(
            lamp.bulb,
            size.longestSide * 0.9,
            [
              const Color(0xFF6B4F2C).withValues(alpha: light),
              const Color(0xFF3A2B1C).withValues(alpha: light * 0.8),
              const Color(0xFF1A1714).withValues(alpha: 0),
            ],
            [0, 0.35, 1],
          ),
      );
    }

    _drawCable(canvas, lamp);

    canvas.save();
    canvas.translate(lamp.shadeTop.pos.dx, lamp.shadeTop.pos.dy);
    canvas.rotate(lamp.shadeAngle);
    _drawLightBeam(canvas, size, light);
    _drawShade(canvas, light);
    canvas.restore();

    _drawCord(canvas, lamp);

    canvas.drawRect(screen, Paint()..color = Colors.black.withValues(alpha: 0.55 * (1 - light)));

    _drawHint(canvas, lamp);
  }

  void _drawCable(Canvas canvas, LampPhysics lamp) {
    final mount = Rect.fromCenter(center: lamp.ceiling.pos + const Offset(0, 5), width: 60, height: 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(mount, const Radius.circular(6)),
      Paint()..color = const Color(0xFF2C2A27),
    );

    final points = [lamp.ceiling.pos, ...lamp.cable.map((p) => p.pos), lamp.shadeTop.pos];
    canvas.drawPath(
      _curveThrough(points),
      Paint()
        ..color = const Color(0xFF0F0E0D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLightBeam(Canvas canvas, Size size, double light) {
    if (light < 0.01) return;
    const top = LampPhysics.shadeHeight;
    const halfWidth = LampPhysics.shadeWidth / 2;
    final length = size.longestSide * 1.4;
    final spread = length * 0.55;

    final beam = Path()
      ..moveTo(-halfWidth + 6, top)
      ..lineTo(halfWidth - 6, top)
      ..lineTo(halfWidth + spread, length)
      ..lineTo(-halfWidth - spread, length)
      ..close();

    canvas.drawPath(
      beam,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
        ..shader = ui.Gradient.linear(const Offset(0, top), Offset(0, length * 0.7), [
          _warmLight.withValues(alpha: 0.42 * light),
          _warmLight.withValues(alpha: 0),
        ]),
    );
  }

  void _drawShade(Canvas canvas, double light) {
    const h = LampPhysics.shadeHeight;
    const w = LampPhysics.shadeWidth / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -4, 18, 16), const Radius.circular(3)),
      Paint()..color = const Color(0xFF8C7A5B),
    );

    if (light > 0.01) {
      canvas.drawCircle(
        const Offset(0, h + 4),
        70,
        Paint()
          ..color = _warmLight.withValues(alpha: 0.75 * light)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
      );
    }

    final glassColor = Color.lerp(const Color(0xFFBDB6A6), const Color(0xFFFFF7DE), light)!;
    canvas.drawCircle(const Offset(0, h + 2), 19, Paint()..color = glassColor);

    final filament = Path()
      ..moveTo(-7, h - 2)
      ..lineTo(-4, h + 6)
      ..lineTo(-1, h - 1)
      ..lineTo(2, h + 6)
      ..lineTo(5, h - 1)
      ..lineTo(7, h + 4);
    canvas.drawPath(
      filament,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Color.lerp(const Color(0xFF6B5D4A), Colors.white, light)!,
    );

    final shade = Path()
      ..moveTo(-11, 8)
      ..lineTo(11, 8)
      ..cubicTo(40, 14, w - 4, 38, w, h)
      ..lineTo(-w, h)
      ..cubicTo(-w + 4, 38, -40, 14, -11, 8)
      ..close();
    canvas.drawPath(
      shade,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-w, 0),
          const Offset(w, 0),
          const [Color(0xFF0C221E), Color(0xFF2F5C53), Color(0xFF1A3D36), Color(0xFF0A1C19)],
          const [0, 0.32, 0.6, 1],
        ),
    );

    canvas.drawPath(
      Path()
        ..moveTo(-8, 12)
        ..cubicTo(-30, 18, -46, 36, -50, h - 8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, h), width: w * 2, height: 10),
      Paint()..color = Color.lerp(const Color(0xFF0B1A17), const Color(0xFFFFE3A3), light)!,
    );
  }

  void _drawCord(Canvas canvas, LampPhysics lamp) {
    final points = [lamp.cordStart.pos, ...lamp.cord.map((p) => p.pos)];
    final stretch = lamp.cordLength / lamp.cordRestLength;
    final thickness = (2.8 / sqrt(stretch)).clamp(1.2, 2.8);
    canvas.drawPath(
      _curveThrough(points),
      Paint()
        ..color = const Color(0xFFE6DCC7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );

    final beforeBead = lamp.cord[lamp.cord.length - 2].pos;
    final dir = lamp.bead.pos - beforeBead;
    canvas.save();
    canvas.translate(lamp.bead.pos.dx, lamp.bead.pos.dy);
    canvas.rotate(atan2(dir.dy, dir.dx) - pi / 2);
    final bead = Rect.fromCenter(center: const Offset(0, 10), width: 15, height: 24);
    canvas.drawOval(
      bead,
      Paint()
        ..shader = ui.Gradient.linear(
          bead.centerLeft,
          bead.centerRight,
          const [Color(0xFF6E4320), Color(0xFFC98E52), Color(0xFF7A4B25)],
          const [0, 0.4, 1],
        ),
    );
    canvas.restore();
  }

  void _drawHint(Canvas canvas, LampPhysics lamp) {
    if (controller.hintOpacity <= 0) return;
    final text = TextPainter(
      text: TextSpan(
        text: 'pull the cord  ·  tilt your phone',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55 * controller.hintOpacity),
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final position = lamp.bead.pos + const Offset(0, 56);
    text.paint(canvas, position - Offset(text.width / 2, 0));
  }

  Path _curveThrough(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final mid = (points[i] + points[i + 1]) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(LampPainter oldDelegate) => oldDelegate.controller != controller;
}
