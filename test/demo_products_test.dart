import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/core/gs1_parser.dart';

/// data/demo_products.csv içindeki her demo GTIN, uygulamanın kendi
/// ayrıştırıcısından geçmelidir; yoksa tarama → katalog eşleştirme demosu
/// daha başlamadan "GTIN ayrıştırılamadı" der.
void main() {
  late List<Map<String, String>> rows;

  setUpAll(() {
    final lines = File('data/demo_products.csv')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final header = lines.first.split(',');
    rows = lines.skip(1).map((l) {
      final cells = l.split(',');
      return {for (var i = 0; i < header.length; i++) header[i]: cells[i]};
    }).toList();
  });

  test('CSV boş değil ve beklenen sütunlara sahip', () {
    expect(rows, isNotEmpty);
    expect(rows.first.keys, containsAll(['gtin', 'product_name', 'ingredient_label', 'is_demo']));
  });

  test('her demo GTIN geçerli bir GTIN-14 kontrol basamağına sahip', () {
    for (final r in rows) {
      expect(isValidGtin14(r['gtin']!), isTrue, reason: 'Geçersiz GTIN: ${r['gtin']}');
    }
  });

  test('her demo GTIN, GS1 (01) biçiminde ayrıştırılabiliyor', () {
    for (final r in rows) {
      expect(extractGtin('(01)${r['gtin']}'), r['gtin']);
    }
  });

  test('tüm kayıtlar DEMO olarak işaretli ve GTIN tekrar etmiyor', () {
    expect(rows.every((r) => r['is_demo'] == 'true'), isTrue);
    expect(rows.map((r) => r['gtin']).toSet().length, rows.length);
  });
}
