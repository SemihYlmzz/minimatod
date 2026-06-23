import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/core/notifications/notification_id_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> freshPrefs([Map<String, Object> seed = const {}]) {
    SharedPreferences.setMockInitialValues(seed);
    return SharedPreferences.getInstance();
  }

  test('same item id always maps to the same notification id', () async {
    final store = NotificationIdStore(await freshPrefs());
    final first = await store.idFor('item-a');
    final again = await store.idFor('item-a');
    expect(again, first);
  });

  test('different items get distinct ids (no collision)', () async {
    final store = NotificationIdStore(await freshPrefs());
    final ids = <int>{};
    for (var i = 0; i < 500; i++) {
      ids.add(await store.idFor('item-$i'));
    }
    expect(ids, hasLength(500));
    expect(ids.every((id) => id > 0), isTrue);
  });

  test('mappings persist across instances sharing the same prefs', () async {
    final prefs = await freshPrefs();
    final a = await NotificationIdStore(prefs).idFor('item-a');
    await NotificationIdStore(prefs).idFor('item-b');

    // A brand-new store over the same prefs keeps A's id and never reissues it.
    final reopened = NotificationIdStore(prefs);
    expect(await reopened.idFor('item-a'), a);
    final c = await reopened.idFor('item-c');
    expect(c, isNot(a));
  });

  test(
    'works without persistence (collision-free within the session)',
    () async {
      final store = NotificationIdStore(null);
      final a = await store.idFor('item-a');
      final b = await store.idFor('item-b');
      expect(a, isNot(b));
      expect(await store.idFor('item-a'), a);
    },
  );
}
