import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'lamp_controller.dart';
import 'lamp_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: LampScreen());
  }
}

class LampScreen extends StatefulWidget {
  const LampScreen({super.key});

  @override
  State<LampScreen> createState() => _LampScreenState();
}

class _LampScreenState extends State<LampScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  StreamSubscription<AccelerometerEvent>? _sensor;
  LampController? _lamp;
  Size? _lampSize;
  Duration _lastTick = Duration.zero;
  Offset _gravity = const Offset(0, 1);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _sensor = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (event) {
        final reading = Offset(-event.x, event.y) / 9.81;
        _gravity = Offset.lerp(_gravity, reading, 0.3)!;
      },
      onError: (_) {},
      cancelOnError: true,
    );
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1000000).clamp(0.0, 1 / 30);
    _lastTick = elapsed;
    if (_lamp == null || dt == 0) return;
    _lamp!.setGravity(_gravity);
    _lamp!.update(dt);
  }

  LampController _lampFor(Size size) {
    if (_lamp == null || _lampSize != size) {
      _lamp?.dispose();
      _lamp = LampController(size);
      _lampSize = size;
    }
    return _lamp!;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sensor?.cancel();
    _lamp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final lamp = _lampFor(constraints.biggest);
          return Listener(
            onPointerDown: (e) => lamp.physics.startDrag(e.localPosition),
            onPointerMove: (e) => lamp.physics.updateDrag(e.localPosition),
            onPointerUp: (_) => lamp.physics.endDrag(),
            onPointerCancel: (_) => lamp.physics.endDrag(),
            child: CustomPaint(size: constraints.biggest, painter: LampPainter(lamp)),
          );
        },
      ),
    );
  }
}
