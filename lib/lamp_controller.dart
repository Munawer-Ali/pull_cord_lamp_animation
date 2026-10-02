import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'lamp_physics.dart';

class LampController extends ChangeNotifier {
  LampController(Size size) : physics = LampPhysics(size);

  final LampPhysics physics;

  bool lightOn = false;
  double brightness = 0;
  double hintOpacity = 1;

  double _time = 0;
  double _switchedAt = 0;
  bool _waitingForRelease = false;

  void setGravity(Offset g) {
    final strength = g.distance;
    if (strength < 0.4) {
      physics.gravity = g + Offset(0, 0.4 - strength);
    } else {
      physics.gravity = g;
    }
  }

  void update(double dt) {
    _time += dt;
    physics.update(dt);

    final stretch = physics.cordLength / physics.cordRestLength;
    if (!_waitingForRelease && physics.pullingCord && stretch > 1.45) {
      _waitingForRelease = true;
      lightOn = !lightOn;
      _switchedAt = _time;
      HapticFeedback.mediumImpact();
    }
    if (_waitingForRelease && stretch < 1.15) {
      _waitingForRelease = false;
    }

    if (lightOn) {
      brightness = _flicker(_time - _switchedAt);
      hintOpacity = max(0, hintOpacity - dt * 1.5);
    } else {
      brightness *= exp(-dt * 14);
    }

    notifyListeners();
  }

  double _flicker(double t) {
    const times = [0.0, 0.04, 0.09, 0.15, 0.21, 0.34];
    const values = [0.0, 0.8, 0.15, 0.9, 0.45, 1.0];
    for (var i = 1; i < times.length; i++) {
      if (t <= times[i]) {
        final progress = (t - times[i - 1]) / (times[i] - times[i - 1]);
        return values[i - 1] + (values[i] - values[i - 1]) * progress;
      }
    }
    return 1;
  }
}
