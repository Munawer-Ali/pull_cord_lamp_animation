# pull_cord_lamp

https://github.com/user-attachments/assets/07d3f623-67ca-42c3-b9cc-aaf78cef2a24

A hanging lamp with a rubber pull cord. Pull the cord to switch the light on,
let go and it snaps back. Tilt the phone and the lamp swings to wherever real
"down" is.

Everything is drawn with `CustomPainter` and moved by a small physics loop.
No images and no animation packages. The only dependency is `sensors_plus`,
for the tilt.

## Demo

_Screen recording to go here: save one as `docs/demo.gif` and link it._

## Running it

```sh
flutter pub get
flutter run
flutter test
```

Built against Flutter 3.44, Dart SDK ^3.12. Use a real phone to try the tilt;
on a simulator there is no accelerometer, so the lamp just hangs straight down.

## Controls

| | |
|---|---|
| pull the bead down | stretch the cord, past ~1.45x the light switches |
| let go | cord snaps back with a small bounce |
| drag the cord sideways | swing the lamp |
| drag the shade | push the lamp around |
| tilt or shake the phone | lamp follows gravity |

## How it works

| File | |
|---|---|
| `lib/lamp_physics.dart` | points, sticks and the solver |
| `lib/lamp_controller.dart` | light on/off, flicker, haptics |
| `lib/lamp_painter.dart` | cable, shade, bulb, light beam, cord |
| `lib/main.dart` | ticker, touch, accelerometer |

The lamp is a chain of points joined by sticks:

```
ceiling (pinned)
  cable    8 rope sticks, can't stretch, can go slack
  shade    4 heavy points locked into one body
  cord     14 soft sticks, the rubber
  bead     heavier last point
```

Every frame is split into 20 small steps. Each step moves the points by their
velocity and gravity, then pulls every stick back towards its length. Cable
sticks snap back fully. Cord sticks have a `softness`, so they only pull back
part of the way, and that leftover stretch is the rubber.

Gravity comes from the accelerometer, flipped into screen coordinates. When the
phone is rotated 30 degrees the lamp hangs at 30 degrees, and a shake shows up
as a swing because the shake is in the reading too.

Two things took the longest:

- **The shade hung crooked.** The cord is tied to one side of the shade, so
  the weight pulled the whole lamp over by about 20 degrees. There is now a
  matching heavy point on the other side, and it hangs within ~3 degrees.
- **The cord whipped over the lamp.** A stretched cord stores a lot of energy,
  and on release the bead flew 300px up. `_rubberFriction` now damps the
  bounce along the cord but leaves the sideways swing alone, so it snaps back
  about 80px and settles in under a second.

## Tweaking

| What | Where |
|---|---|
| cord stiffness | `softness: 1 / 12000` in `lamp_physics.dart`, bigger number = stretchier |
| how far to pull | `stretch > 1.45` in `lamp_controller.dart` |
| how long it swings | the `damping` values in `lamp_physics.dart` |
| bounce after release | `exp(-8 * h)` in `_rubberFriction` |
