import 'package:shared_preferences/shared_preferences.dart';

/// Doz onaylarının cihazda kalıcı olarak saklanmasını sağlar.
/// Kayıt anahtarı güne bağlıdır (örn. "taken_2026-10-26"),
/// böylece ertesi gün liste sıfırdan başlar.
class DoseStorage {
  const DoseStorage();

  static final DoseStorage instance = const DoseStorage();

  static String dayKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'taken_$y-$m-$d';
  }

  Future<Set<int>> loadTaken(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = dayKey(day);
    final rawList = prefs.getStringList(key);
    if (rawList == null) return <int>{};
    return rawList.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> saveTaken(DateTime day, Set<int> takenIds) async {
    final prefs = await SharedPreferences.getInstance();
    final key = dayKey(day);
    final stringList = takenIds.map((id) => id.toString()).toList();
    await prefs.setStringList(key, stringList);
  }
}
