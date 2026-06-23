// Headless App Store screenshot generator.
//
// Renders the REAL app screens (seeded with an attractive demo board) at exact
// device pixel sizes and writes raw PNGs to store_screenshots/_raw/. A separate
// step composites these into premium marketing frames.
//
// Not a normal test — run explicitly:
//   fvm flutter test test/screenshots_test.dart
//
// Lessons baked in: load FontManifest fonts (MaterialIcons) + a real text font,
// or glyphs/text render as boxes; do all real-async work (fonts, ffi DB,
// RenderRepaintBoundary.toImage) inside tester.runAsync(); never pumpAndSettle
// (entrance animations never settle) — use a few fixed pump()s instead.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/core/database/app_database.dart';
import 'package:minimatod/core/settings/app_settings_controller.dart';
import 'package:minimatod/core/theme/app_themes.dart';
import 'package:minimatod/features/attachments/data/attachment_model.dart';
import 'package:minimatod/features/attachments/data/attachments_repository.dart';
import 'package:minimatod/features/attachments/data/sqlite_blob_store.dart';
import 'package:minimatod/features/attachments/presentation/audio_controller.dart';
import 'package:minimatod/features/notes/data/note_model.dart';
import 'package:minimatod/features/notes/data/notes_repository.dart';
import 'package:minimatod/features/notes/presentation/narrow/notes_view.dart';
import 'package:minimatod/features/notes/presentation/notes_controller.dart';
import 'package:minimatod/features/notes/presentation/wide/wide_home_shell.dart';
import 'package:minimatod/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _rawDir = '/Users/semihyilmaz/Desktop/minimatod/store_screenshots/_raw';

Future<void> _loadBundledFonts() async {
  final manifest = await rootBundle.loadString('FontManifest.json');
  final fonts = json.decode(manifest) as List<dynamic>;
  for (final font in fonts) {
    final loader = FontLoader(font['family'] as String);
    for (final asset in font['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(asset['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _loadSystemFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

ThemeData _withFont(ThemeData base, String family) => base.copyWith(
  textTheme: base.textTheme.apply(fontFamily: family),
  primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
);

Widget _wrap(GlobalKey key, ThemeData theme, Widget home) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'generate App Store screenshots',
    (tester) async {
      // The AudioController constructs a just_audio player; with no platform it
      // throws MissingPluginException (harmless here — we only read attachment
      // metadata, never play). Stub the channels so the generator runs clean.
      final messenger = tester.binding.defaultBinaryMessenger;
      for (final name in const [
        'com.ryanheise.just_audio.methods',
        'com.ryanheise.audio_session',
        'com.ryanheise.av_audio_session',
        'com.ryanheise.android_audio_manager',
        'com.llfbandit.record/messages',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(name),
          (call) async => null,
        );
      }

      late NotesController controller;
      late AppDatabase db;
      final settings = AppSettingsController(null);
      final now = DateTime.now();
      var order = 1000;
      var seq = 0; // drives recent, natural-looking created times

      await tester.runAsync(() async {
        // Load the text font FIRST so the engine's null-family fallback resolves
        // to SF (not MaterialIcons) — otherwise widgets that set a null-family
        // style (e.g. DetailTabs' AnimatedDefaultTextStyle) render as boxes.
        await _loadSystemFont('SFPro', '/System/Library/Fonts/SFNS.ttf');
        await _loadBundledFonts();

        db = AppDatabase(databaseName: inMemoryDatabasePath);
        final repo = SqfliteNotesRepository(db);
        final attachments = SqfliteAttachmentsRepository(db);
        final blobs = SqliteBlobStore(db);

        // Items are added top-of-list first (descending sort_order).
        Future<void> add(
          String id, {
          required ItemType type,
          required String content,
          String? parentId,
          String? icon,
          int? color,
          String? body,
          bool isDone = false,
          int? reminderInDays,
        }) async {
          await repo.add(Item(
            id: id,
            type: type,
            content: content,
            parentId: parentId,
            icon: icon,
            color: color,
            body: body,
            isDone: isDone,
            reminderAt: reminderInDays == null
                ? null
                : DateTime(now.year, now.month, now.day + reminderInDays, 9),
            sortOrder: order--,
            createdAt: now.subtract(Duration(minutes: seq++ * 4 + 2)),
            updatedAt: now,
          ));
        }

        // ---- Root board (notes, then tasks) ----
        await add('japan',
            type: ItemType.note,
            content: 'Japan trip · April',
            icon: 'calendar',
            color: 0xFFE57697,
            body:
                'Two weeks across Tokyo, Kyoto, and Osaka. Cherry blossoms '
                'should peak the first week. Slow mornings, long walks, one '
                'nice dinner per city.');
        await add('q2',
            type: ItemType.note,
            content: 'Q2 product launch',
            icon: 'work',
            color: 0xFF64B5F6,
            body:
                'Shipping the new onboarding flow. Keep scope tight — landing '
                'page, three emails, and a short demo video.');
        await add('song',
            type: ItemType.note,
            content: 'Song idea — late train',
            icon: 'music',
            color: 0xFFB39DDB,
            body:
                'Slow tempo, minor key. A hummed melody about empty platforms '
                'at midnight. Try it on the piano this weekend.');
        await add('reading',
            type: ItemType.note,
            content: 'Reading list',
            icon: 'book',
            color: 0xFF81C784,
            body:
                'On a quiet-fiction streak. Aiming for one book a fortnight.');
        await add('home',
            type: ItemType.note,
            content: 'Home & garden',
            icon: 'home',
            color: 0xFFFF8A65,
            body:
                'Small weekend fixes to make the place feel calmer. Repot the '
                'herbs before they outgrow the windowsill.');
        await add('groceries',
            type: ItemType.task,
            content: 'Pick up groceries',
            reminderInDays: 1);
        await add('run',
            type: ItemType.task, content: 'Morning run — 5K', isDone: true);

        // ---- Japan subtree (3 levels deep) ----
        await add('jp-kyoto',
            type: ItemType.note,
            content: 'Kyoto days',
            parentId: 'japan',
            icon: 'star',
            color: 0xFF4DB6AC,
            body:
                'Three nights near Gion. Keep it unhurried — temples in the '
                'morning, tea in the afternoon.');
        await add('jp-packing',
            type: ItemType.note,
            content: 'Packing list',
            parentId: 'japan',
            icon: 'check',
            reminderInDays: 5);
        await add('jp-flights',
            type: ItemType.task,
            content: 'Book return flights',
            parentId: 'japan',
            isDone: true);
        await add('jp-jr',
            type: ItemType.task,
            content: 'Order JR Rail Pass',
            parentId: 'japan',
            isDone: true);

        await add('kyoto-fushimi',
            type: ItemType.task,
            content: 'Fushimi Inari at sunrise',
            parentId: 'jp-kyoto');
        await add('kyoto-bamboo',
            type: ItemType.task,
            content: 'Arashiyama bamboo grove',
            parentId: 'jp-kyoto');
        await add('kyoto-matcha',
            type: ItemType.task,
            content: 'Matcha tasting in Uji',
            parentId: 'jp-kyoto',
            isDone: true);

        await add('pack-passport',
            type: ItemType.task,
            content: 'Passport + visa printout',
            parentId: 'jp-packing',
            isDone: true);
        await add('pack-adapter',
            type: ItemType.task,
            content: 'Travel adapter + power bank',
            parentId: 'jp-packing');
        await add('pack-camera',
            type: ItemType.task,
            content: 'Camera + spare batteries',
            parentId: 'jp-packing');

        // ---- Q2 subtree ----
        await add('q2-sync',
            type: ItemType.note,
            content: 'Team sync notes',
            parentId: 'q2',
            icon: 'note',
            body:
                'Design is unblocked, copy is in review, and we are holding '
                'the launch date. Follow up with marketing on the emails.');
        await add('q2-copy',
            type: ItemType.task,
            content: 'Finalize landing page copy',
            parentId: 'q2',
            isDone: true);
        await add('q2-demo',
            type: ItemType.task,
            content: 'Record demo video',
            parentId: 'q2',
            reminderInDays: 2);

        // ---- Song subtree (so the voice-note detail looks full) ----
        await add('song-hook',
            type: ItemType.task,
            content: 'Record the hook melody',
            parentId: 'song');
        await add('song-chords',
            type: ItemType.task,
            content: 'Find the chord progression',
            parentId: 'song');
        await add('song-verse',
            type: ItemType.task,
            content: 'Write the second verse',
            parentId: 'song',
            isDone: true);
        await add('song-beat',
            type: ItemType.task,
            content: 'Layer a soft drum loop',
            parentId: 'song');
        await add('song-bridge',
            type: ItemType.task,
            content: 'Try a key change at the bridge',
            parentId: 'song');

        // ---- Reading subtree ----
        await add('read-1',
            type: ItemType.task,
            content: 'Finish "The Overstory"',
            parentId: 'reading');
        await add('read-2',
            type: ItemType.task,
            content: 'Start "Project Hail Mary"',
            parentId: 'reading');

        // ---- Voice note on the song idea (shows the 1.4.0 headline feature) ----
        final clip = Uint8List.fromList(List<int>.generate(2048, (i) => i % 251));
        final hash = await blobs.write(clip);
        await attachments.add(Attachment(
          id: 'att-song',
          itemId: 'song',
          kind: AttachmentKind.audio,
          contentHash: hash,
          mimeType: 'audio/aac',
          byteSize: clip.length,
          createdAt: now,
          updatedAt: now,
        ));

        final audio = AudioController(attachments: attachments, blobs: blobs);
        await audio.load();
        controller = NotesController(repo, audio: audio);
        await controller.load();
      });
      addTearDown(() async => db.close());
      addTearDown(tester.view.reset);

      final light = _withFont(AppThemes.light, 'SFPro');
      final dark = _withFont(AppThemes.dark, 'SFPro');

      Future<void> shoot(
        String id,
        Size physical,
        double dpr,
        ThemeData theme,
        Widget home,
      ) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = physical;
        final key = GlobalKey();
        await tester.pumpWidget(_wrap(key, theme, home));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: dpr);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = File('$_rawDir/$id.png');
          await out.parent.create(recursive: true);
          await out.writeAsBytes(bytes!.buffer.asUint8List());
          // ignore: avoid_print
          print('SHOT $id ${image.width}x${image.height}');
        });
      }

      const iphone = Size(1320, 2868);
      const ipad = Size(2064, 2752);
      NotesView nv({Item? parent}) =>
          NotesView(controller: controller, settings: settings, parent: parent);

      // iPhone 6.9"
      await shoot('iphone_home', iphone, 3.0, light, nv());
      await shoot('iphone_voice', iphone, 3.0, light,
          nv(parent: controller.itemById('song')));
      await shoot('iphone_organize', iphone, 3.0, light,
          nv(parent: controller.itemById('japan')));
      await shoot('iphone_dark', iphone, 3.0, dark, nv());

      // iPad 13"
      await shoot('ipad_home', ipad, 2.0, light,
          WideHomeShell(controller: controller, settings: settings, initialSelectedId: 'japan'));
      await shoot('ipad_detail', ipad, 2.0, light,
          WideHomeShell(controller: controller, settings: settings, initialSelectedId: 'song'));
      await shoot('ipad_dark', ipad, 2.0, dark,
          WideHomeShell(controller: controller, settings: settings, initialSelectedId: 'japan'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
