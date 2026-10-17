import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/applet_settings.dart';

void main() {
  group('persistAppletSetting / resolveStoredAppletSetting', () {
    late LanisDatabase db;
    late TypedSettings settings;

    setUp(() {
      db = LanisDatabase.open();
      settings = TypedSettings.shared(db);
    });

    tearDown(() {
      db.dispose();
    });

    test('persists Map<String, String?> as a JSON map (not toString)', () {
      // Mimics color-picker clears that previously failed `is Map<String, dynamic>`.
      final colors = <String, String?>{'secabc': null, 'secdef': 'FF112233'};
      persistAppletSetting(settings, 'stundenplan.php/lesson-colors', colors);

      final loaded = resolveStoredAppletSetting(
        settings,
        'stundenplan.php/lesson-colors',
        <String, dynamic>{},
      );
      expect(loaded, isA<Map>());
      expect((loaded as Map)['secdef'], 'FF112233');
      expect(loaded.containsKey('secabc'), isTrue);
      expect(loaded['secabc'], isNull);
    });

    test('recovers from corrupted Map.toString() storage as empty default', () {
      settings.setString(
        'stundenplan.php/lesson-colors',
        '{sa4ca70bd0e42bfe29d4a12a94e5ba4f6: FF112233}',
      );

      final loaded = resolveStoredAppletSetting(
        settings,
        'stundenplan.php/lesson-colors',
        <String, dynamic>{},
      );
      expect(loaded, isA<Map>());
      expect((loaded as Map), isEmpty);
      expect(settings.getString('stundenplan.php/lesson-colors'), isNull);
    });

    test('does not treat map-default keys as bools', () {
      settings.setString('stundenplan.php/lesson-colors', 'not-a-bool');
      final loaded = resolveStoredAppletSetting(
        settings,
        'stundenplan.php/lesson-colors',
        <String, dynamic>{},
      );
      expect(loaded, isA<Map>());
      expect(loaded, isEmpty);
    });
  });
}
