import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilac_yakinlik_takip/services/dose_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DoseStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('kaydet -> oku aynı gün için aynı seti döner', () async {
      const storage = DoseStorage();
      final today = DateTime(2026, 10, 26);
      final takenDoses = {1, 3};

      await storage.saveTaken(today, takenDoses);
      final loaded = await storage.loadTaken(today);

      expect(loaded, equals(takenDoses));
    });

    test('farklı gün sorgulandığında boş set döner', () async {
      const storage = DoseStorage();
      final day1 = DateTime(2026, 10, 26);
      final day2 = DateTime(2026, 10, 27);

      await storage.saveTaken(day1, {1, 2, 4});
      final loadedDay2 = await storage.loadTaken(day2);

      expect(loadedDay2, isEmpty);
    });
  });
}
