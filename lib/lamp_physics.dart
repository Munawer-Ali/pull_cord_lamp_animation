import 'dart:math';
import 'dart:ui';

class Point {
  Point(this.pos, {double mass = 1, this.damping = 0.6}) : prev = pos, invMass = mass == double.infinity ? 0 : 1 / mass;

  Offset pos;
  Offset prev;
  Offset vel = Offset.zero;
  final double invMass;
  final double damping;
}

class Stick {
  Stick(this.a, this.b, this.length, {this.softness = 0, this.rope = false});

  final Point a;
  final Point b;
  final double length;
  final double softness;
  final bool rope;
}

class LampPhysics {
  LampPhysics(Size size) {
    _setup(size);
  }

  static const shadeHeight = 70.0;
  static const shadeWidth = 124.0;

  final points = <Point>[];
  final _sticks = <Stick>[];
  final _cordSticks = <Stick>[];

  late Point ceiling;
  late List<Point> cable;
  late Point shadeTop;
  late Point shadeBottom;
  late Point cordStart;
  late List<Point> cord;
  late double cordRestLength;

  Offset gravity = const Offset(0, 1);

  Point? _dragging;
  Offset _dragTo = Offset.zero;
  double _dragSoftness = 0;

  Point get bead => cord.last;

  bool get pullingCord => _dragging != null && cord.contains(_dragging);

  void _setup(Size size) {
    ceiling = _point(Offset(size.width / 2, 0), mass: double.infinity);

    final cableLength = size.height * 0.26;
    final cableStep = cableLength / 8;
    cable = [];
    for (var i = 1; i < 8; i++) {
      cable.add(_point(ceiling.pos + Offset(0, cableStep * i)));
    }

    final top = ceiling.pos + Offset(0, cableLength);
    shadeTop = _point(top, mass: 40, damping: 0.35);
    shadeBottom = _point(top + const Offset(0, shadeHeight), mass: 40, damping: 0.35);
    cordStart = _point(top + const Offset(34, shadeHeight - 4), mass: 40, damping: 0.35);
    final otherSide = _point(top + const Offset(-34, shadeHeight - 4), mass: 40, damping: 0.35);

    var last = ceiling;
    for (final p in [...cable, shadeTop]) {
      _sticks.add(Stick(last, p, cableStep, rope: true));
      last = p;
    }

    _lock(shadeTop, shadeBottom);
    _lock(shadeBottom, cordStart);
    _lock(cordStart, shadeTop);
    _lock(shadeBottom, otherSide);
    _lock(otherSide, shadeTop);

    cordRestLength = size.height * 0.17;
    final cordStep = cordRestLength / 14;
    cord = [];
    for (var i = 1; i <= 14; i++) {
      cord.add(_point(cordStart.pos + Offset(0, cordStep * i), mass: i == 14 ? 3 : 0.4, damping: 1.4));
    }
    last = cordStart;
    for (final p in cord) {
      final stick = Stick(last, p, cordStep, softness: 1 / 12000, rope: true);
      _sticks.add(stick);
      _cordSticks.add(stick);
      last = p;
    }
  }

  Point _point(Offset pos, {double mass = 1, double damping = 0.6}) {
    final p = Point(pos, mass: mass, damping: damping);
    points.add(p);
    return p;
  }

  void _lock(Point a, Point b) {
    _sticks.add(Stick(a, b, (b.pos - a.pos).distance));
  }

  Offset get shadeDirection {
    final d = shadeBottom.pos - shadeTop.pos;
    return d / d.distance;
  }

  double get shadeAngle {
    final d = shadeDirection;
    return atan2(d.dy, d.dx) - pi / 2;
  }

  Offset get bulb => shadeBottom.pos - shadeDirection * 2;

  double get cordLength {
    var total = 0.0;
    var last = cordStart;
    for (final p in cord) {
      total += (p.pos - last.pos).distance;
      last = p;
    }
    return total;
  }

  void startDrag(Offset at) {
    if ((bead.pos - at).distance < 48) {
      _dragging = bead;
      _dragSoftness = 2e-7;
    } else {
      Point? closest;
      var closestDistance = 30.0;
      for (final p in cord) {
        final d = (p.pos - at).distance;
        if (d < closestDistance) {
          closestDistance = d;
          closest = p;
        }
      }
      final shadeMiddle = (shadeTop.pos + shadeBottom.pos) / 2;
      if (closest != null) {
        _dragging = closest;
        _dragSoftness = 2e-7;
      } else if ((shadeMiddle - at).distance < 75) {
        _dragging = shadeBottom;
        _dragSoftness = 2e-5;
      } else {
        return;
      }
    }
    updateDrag(at);
  }

  void updateDrag(Offset to) {
    final p = _dragging;
    if (p == null) return;
    var target = to;
    if (cord.contains(p)) {
      final part = (cord.indexOf(p) + 1) / cord.length;
      final maxLength = cordRestLength * part * 2.2;
      final fromStart = target - cordStart.pos;
      if (fromStart.distance > maxLength) {
        target = cordStart.pos + fromStart / fromStart.distance * maxLength;
      }
    }
    _dragTo = target;
  }

  void endDrag() {
    _dragging = null;
  }

  void update(double dt) {
    const steps = 20;
    final h = dt / steps;
    final g = gravity * 2000;

    for (var s = 0; s < steps; s++) {
      for (final p in points) {
        if (p.invMass == 0) continue;
        p.vel = (p.vel + g * h) * (1 - p.damping * h);
        p.prev = p.pos;
        p.pos += p.vel * h;
      }

      for (final stick in _sticks) {
        _solveStick(stick, h);
      }

      final dragged = _dragging;
      if (dragged != null) {
        final w = dragged.invMass + _dragSoftness / (h * h);
        dragged.pos += (_dragTo - dragged.pos) * (dragged.invMass / w);
      }

      for (final p in points) {
        if (p.invMass == 0) continue;
        p.vel = (p.pos - p.prev) / h;
      }

      _rubberFriction(h);
    }
  }

  void _solveStick(Stick stick, double h) {
    final delta = stick.b.pos - stick.a.pos;
    final distance = delta.distance;
    if (distance == 0) return;
    final diff = distance - stick.length;
    if (stick.rope && diff <= 0) return;
    final w = stick.a.invMass + stick.b.invMass + stick.softness / (h * h);
    if (w == 0) return;
    final dir = delta / distance;
    final move = diff / w;
    stick.a.pos += dir * (move * stick.a.invMass);
    stick.b.pos -= dir * (move * stick.b.invMass);
  }

  void _rubberFriction(double h) {
    final linkLoss = 1 - exp(-600 * h);
    for (final stick in _cordSticks) {
      final delta = stick.b.pos - stick.a.pos;
      final distance = delta.distance;
      if (distance <= stick.length) continue;
      final dir = delta / distance;
      final relVel = stick.b.vel - stick.a.vel;
      final speed = relVel.dx * dir.dx + relVel.dy * dir.dy;
      final impulse = speed * linkLoss / (stick.a.invMass + stick.b.invMass);
      stick.a.vel += dir * (impulse * stick.a.invMass);
      stick.b.vel -= dir * (impulse * stick.b.invMass);
    }

    final toBead = bead.pos - cordStart.pos;
    if (toBead.distance == 0 || cordLength <= cordRestLength) return;
    final dir = toBead / toBead.distance;
    final bounceLoss = 1 - exp(-8 * h);
    for (final p in cord) {
      final relVel = p.vel - cordStart.vel;
      p.vel -= dir * ((relVel.dx * dir.dx + relVel.dy * dir.dy) * bounceLoss);
    }
  }
}
