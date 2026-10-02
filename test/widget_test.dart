import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pull_cord_lamp/lamp_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void run(LampController lamp, double seconds) {
    for (var i = 0; i < seconds * 60; i++) {
      lamp.update(1 / 60);
    }
  }

  test('lamp hangs straight when the phone is upright', () {
    final lamp = LampController(const Size(390, 844));
    run(lamp, 3);
    expect(lamp.physics.shadeAngle.abs(), lessThan(0.07));
    expect(lamp.lightOn, isFalse);
  });

  test('pulling the cord turns the light on and it settles after release', () {
    final lamp = LampController(const Size(390, 844));
    run(lamp, 3);
    final physics = lamp.physics;
    final start = physics.bead.pos;

    physics.startDrag(start);
    for (var i = 1; i <= 30; i++) {
      physics.updateDrag(start + Offset(0, 6.0 * i));
      run(lamp, 1 / 60);
    }
    expect(lamp.lightOn, isTrue);

    physics.endDrag();
    var highest = start.dy;
    for (var i = 0; i < 120; i++) {
      run(lamp, 1 / 60);
      if (physics.bead.pos.dy < highest) highest = physics.bead.pos.dy;
    }
    expect(start.dy - highest, lessThan(120));
    expect((physics.bead.pos.dy - start.dy).abs(), lessThan(15));
  });

  test('lamp follows gravity when the phone is tilted', () {
    final lamp = LampController(const Size(390, 844));
    lamp.setGravity(const Offset(0.5, 0.866));
    run(lamp, 8);
    expect(lamp.physics.shadeAngle, closeTo(-0.524, 0.05));
  });
}
