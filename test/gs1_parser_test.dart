import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/core/gs1_parser.dart';

void main() {
  test('GS1 DataMatrix ham verisinden GTIN ayrıştırılır', () {
    expect(extractGtin(']d2010123456789012821ABC123'), '01234567890128');
  });
  test('Parantezli gösterimden GTIN ayrıştırılır', () {
    expect(extractGtin('(01)01234567890128(17)271231'), '01234567890128');
  });
  test('Yanlış kontrol basamaklı GTIN reddedilir', () {
    expect(extractGtin('0101234567890129'), isNull);
  });
  test('Belirsiz barkod güvenilir GTIN olarak kabul edilmez', () {
    expect(extractGtin('rastgele-veri'), isNull);
  });
  test('14 haneden fazla rakam içeren bozuk kod sessizce kabul edilmez', () {
    expect(extractGtin('(01)012345678901284(17)260101'), isNull);
  });

  group('normalizeManualGtin (elle giriş)', () {
    test('geçerli 14 hane (01) önekiyle döner ve extractGtin onu okur', () {
      final r = normalizeManualGtin('01234567890128');
      expect(r, '(01)01234567890128');
      expect(extractGtin(r), '01234567890128');
    });
    test('boşluk ve tireler temizlenir', () {
      expect(normalizeManualGtin('0123 4567-8901 28'), '(01)01234567890128');
    });
    test('yanlış kontrol basamağı reddedilir', () {
      expect(normalizeManualGtin('01234567890129'), isNull);
    });
    test('14 haneden kısa/uzun veya harf içeren giriş reddedilir', () {
      expect(normalizeManualGtin('0123456789012'), isNull);
      expect(normalizeManualGtin('012345678901280'), isNull);
      expect(normalizeManualGtin('0123456789012a'), isNull);
    });
  });
}
