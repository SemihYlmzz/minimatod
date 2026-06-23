// Premium App Store frame compositor.
//
// Takes the raw device screenshots from store_screenshots/_raw/ and composites
// each into a marketing frame (gradient background + headline + subhead + the
// screen floating with rounded corners and a soft shadow), rendered in Flutter
// at the exact App Store pixel sizes. Writes to store_screenshots/v1.4.0/.
//
//   fvm flutter test test/screenshot_frames_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = '/Users/semihyilmaz/Desktop/minimatod/store_screenshots';

class _Frame {
  const _Frame({
    required this.raw,
    required this.out,
    required this.headline,
    required this.subhead,
    required this.bgTop,
    required this.bgBottom,
    required this.text,
    required this.accent,
    required this.isPad,
  });
  final String raw; // raw png id
  final String out; // output relative path under v1.4.0/
  final String headline;
  final String subhead;
  final int bgTop;
  final int bgBottom;
  final int text;
  final int accent;
  final bool isPad;
}

const _accent = 0xFF5EA9FF;

const _frames = <_Frame>[
  // iPhone 6.9" — 1320 x 2868
  _Frame(
    raw: 'iphone_home',
    out: 'iphone/1_chaos',
    headline: 'Control your chaos',
    subhead: 'Every note and task in one calm place',
    bgTop: 0xFFFFFFFF,
    bgBottom: 0xFFEEF2F7,
    text: 0xFF0E0F12,
    accent: _accent,
    isPad: false,
  ),
  _Frame(
    raw: 'iphone_voice',
    out: 'iphone/2_voice',
    headline: 'Just speak it',
    subhead: 'Capture any thought as a voice note',
    bgTop: 0xFFFFFFFF,
    bgBottom: 0xFFE9EFF7,
    text: 0xFF0E0F12,
    accent: _accent,
    isPad: false,
  ),
  _Frame(
    raw: 'iphone_organize',
    out: 'iphone/3_nest',
    headline: 'Nests forever',
    subhead: 'Infinite structure, never lose a thought',
    bgTop: 0xFFFFFFFF,
    bgBottom: 0xFFEDF1F6,
    text: 0xFF0E0F12,
    accent: _accent,
    isPad: false,
  ),
  _Frame(
    raw: 'iphone_dark',
    out: 'iphone/4_dark',
    headline: 'Calm after dark',
    subhead: 'A dark theme that feels effortless',
    bgTop: 0xFF13233A,
    bgBottom: 0xFF0E1A2B,
    text: 0xFFF4F7FB,
    accent: _accent,
    isPad: false,
  ),
  // iPad 13" — 2064 x 2752
  _Frame(
    raw: 'ipad_home',
    out: 'ipad/1_room',
    headline: 'Room to think',
    subhead: 'Three panes on the big screen',
    bgTop: 0xFFFFFFFF,
    bgBottom: 0xFFEAF0F7,
    text: 0xFF0E0F12,
    accent: _accent,
    isPad: true,
  ),
  _Frame(
    raw: 'ipad_detail',
    out: 'ipad/2_focus',
    headline: 'Focus, full size',
    subhead: 'Open a note, hear it, refine it',
    bgTop: 0xFFFFFFFF,
    bgBottom: 0xFFE8EEF6,
    text: 0xFF0E0F12,
    accent: _accent,
    isPad: true,
  ),
  _Frame(
    raw: 'ipad_dark',
    out: 'ipad/3_dark',
    headline: 'Beautiful in dark',
    subhead: 'The whole desk goes quiet',
    bgTop: 0xFF13233A,
    bgBottom: 0xFF0B1626,
    text: 0xFFF4F7FB,
    accent: _accent,
    isPad: true,
  ),
];

Future<void> _loadSystemFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<ui.Image> _loadImage(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

Widget _frameWidget(_Frame f, ui.Image shot) {
  final w = f.isPad ? 2064.0 : 1284.0;
  final headlineSize = f.isPad ? 108.0 : 92.0;
  final subSize = f.isPad ? 50.0 : 42.0;
  final topPad = f.isPad ? 150.0 : 132.0;
  final sidePad = f.isPad ? 230.0 : 120.0;
  final radius = f.isPad ? 56.0 : 60.0;
  final aspect = shot.width / shot.height;

  return Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      width: w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(f.bgTop), Color(f.bgBottom)],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: topPad),
          // Small accent bar above the headline.
          Container(
            width: f.isPad ? 84 : 72,
            height: f.isPad ? 9 : 8,
            decoration: BoxDecoration(
              color: Color(f.accent),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(height: f.isPad ? 34 : 30),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sidePad),
            child: Text(
              f.headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SFPro',
                fontSize: headlineSize,
                height: 1.04,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                color: Color(f.text),
              ),
            ),
          ),
          SizedBox(height: f.isPad ? 20 : 18),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sidePad),
            child: Text(
              f.subhead,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SFPro',
                fontSize: subSize,
                height: 1.25,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
                color: Color(f.text).withValues(alpha: 0.6),
              ),
            ),
          ),
          SizedBox(height: f.isPad ? 84 : 78),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, f.isPad ? 120 : 150),
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0E1A2B).withValues(alpha: 0.22),
                          blurRadius: f.isPad ? 80 : 70,
                          spreadRadius: 2,
                          offset: Offset(0, f.isPad ? 36 : 32),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: RawImage(image: shot, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'composite premium App Store frames',
    (tester) async {
      addTearDown(tester.view.reset);

      for (final f in _frames) {
        final size = f.isPad
            ? const Size(2064, 2752)
            : const Size(1284, 2778); // iPhone 6.5" slot

        late ui.Image shot;
        await tester.runAsync(() async {
          await _loadSystemFont('SFPro', '/System/Library/Fonts/SFNS.ttf');
          shot = await _loadImage('$_base/v1.4.0/raw/${f.raw}.png');
        });

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;

        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: _frameWidget(f, shot),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = File('$_base/v1.4.0/${f.out}.png');
          await out.parent.create(recursive: true);
          await out.writeAsBytes(bytes!.buffer.asUint8List());
          // ignore: avoid_print
          print('FRAME ${f.out} ${image.width}x${image.height}');
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
