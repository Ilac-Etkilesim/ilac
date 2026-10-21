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
}
