@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/services/catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Katalog servisinin GERÇEK Supabase projesine karşı doğrulanması (Issue #31).
///
/// Normal `flutter test` çalıştırmasında bu dosya **atlanır** — anahtarlar
/// verilmediği sürece hiçbir ağ çağrısı yapılmaz, CI etkilenmez.
///
/// Çalıştırmak için (anahtarlar depoya yazılmaz, komut satırından verilir):
///
/// ```
/// flutter test test/catalog_service_live_test.dart \
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key> \
///   --dart-define=TEST_EMAIL=<test hesabı> \
///   --dart-define=TEST_PASSWORD=<test şifresi>
/// ```
void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const email = String.fromEnvironment('TEST_EMAIL');
  const password = String.fromEnvironment('TEST_PASSWORD');

  final yapilandirildi =
      url.isNotEmpty && key.isNotEmpty && email.isNotEmpty && password.isNotEmpty;

  group('CatalogService — canlı Supabase', () {
    setUpAll(() async {
      if (!yapilandirildi) return;
      TestWidgetsFlutterBinding.ensureInitialized();
      // TestWidgetsFlutterBinding tüm HTTP isteklerini 400 döndüren sahte bir
      // istemciye yönlendirir. Bu dosya bilerek GERÇEK sunucuya gittiği için
      // o yönlendirme kaldırılıyor.
      HttpOverrides.global = null;
      // Supabase oturumu SharedPreferences'ta saklıyor; test ortamında eklenti
      // yok, bu yüzden sahte depo veriliyor (app_smoke_test ile aynı yöntem).
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(url: url, publishableKey: key);
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
    });

    test('demo ürün bulunur ve etken maddesi gelir', () async {
      const service = CatalogService();
      final result = await service.lookupGtin('99990000000008');

      expect(result.status, CatalogStatus.bulundu);
      expect(result.productName, isNotEmpty);
      expect(result.ingredients, isNotEmpty);
      // Demo seed kayıtlarında display_name boş; normalized_name'e düşmeli.
      expect(result.ingredients.single.name, isNotEmpty);
      expect(result.isDemo, isTrue, reason: 'seed kayıtları is_demo = true');
    }, skip: yapilandirildi ? false : 'canlı anahtarlar verilmedi');

    test('katalogda olmayan GTIN katalogdaYok döner', () async {
      const service = CatalogService();
      final result = await service.lookupGtin('12345678901231');

      expect(result.status, CatalogStatus.katalogdaYok);
      expect(result.kullaniciMesaji, contains('doğrulanmadı'));
    }, skip: yapilandirildi ? false : 'canlı anahtarlar verilmedi');
  });
}
