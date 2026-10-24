/// Sprint 0: Yalnızca GS1 AI(01) / GTIN-14 ayrıştırılır.
/// Bu işlem ilaç kimliğini veya tıbbi güvenliği doğrulamaz.
String? extractGtin(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final value = raw.startsWith(']d2') ? raw.substring(3) : raw;

  // (?!\d): 14 haneden sonra fazladan rakam varsa (bozuk/kazınmış kod) sessizce
  // ilk 14 haneyi alıp yanlış bir GTIN üretmeyelim.
  final labelled = RegExp(r'\(01\)(\d{14})(?!\d)').firstMatch(value);
  if (labelled != null) {
    final gtin = labelled.group(1)!;
    return isValidGtin14(gtin) ? gtin : null;
  }

  if (value.startsWith('01') && value.length >= 16) {
    final gtin = value.substring(2, 16);
    return isValidGtin14(gtin) ? gtin : null;
  }
  return null;
}

/// GTIN-14 kontrol rakamı denetimi (GS1). Ürün kataloğunda kayıt olduğunu kanıtlamaz.
bool isValidGtin14(String value) {
  if (!RegExp(r'^\d{14}$').hasMatch(value)) return false;
  final digits = value.split('').map(int.parse).toList();
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    sum += digits[i] * (i.isEven ? 3 : 1);
  }
  final expected = (10 - sum % 10) % 10;
  return digits[13] == expected;
}
