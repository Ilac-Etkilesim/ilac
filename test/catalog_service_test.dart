import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/services/catalog_service.dart';

/// Testlerde Supabase yerine kullanılan sahte katalog kaynağı.
class FakeCatalogSource implements CatalogSource {
  FakeCatalogSource({
    this.product,
    this.ingredientRows = const <Map<String, dynamic>>[],
    this.productError,
    this.ingredientError,
  });

  final Map<String, dynamic>? product;
  final List<Map<String, dynamic>> ingredientRows;
  final Object? productError;
  final Object? ingredientError;

  @override
  Future<Map<String, dynamic>?> fetchProduct(String gtin) async {
    if (productError != null) throw productError!;
    return product;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients(String gtin) async {
    if (ingredientError != null) throw ingredientError!;
    return ingredientRows;
  }
}

/// Kontrol hanesi doğru, test için kullanılan GTIN'ler.
const gecerliGtin = '99990000000008';

Map<String, dynamic> urun({
  String ad = 'Örnek İlaç A',
  bool demo = false,
}) =>
    {'gtin': gecerliGtin, 'display_name': ad, 'is_demo': demo};

Map<String, dynamic> etkenMadde({
  String? display,
  String? normalized,
  bool needsReview = false,
}) =>
    {
      'ingredients': {
        'display_name': display,
        'normalized_name': normalized,
        'needs_review': needsReview,
      }
    };

void main() {
  group('CatalogService — dört durum', () {
    test('bulundu: ürün ve etken madde döner', () async {
      final service = CatalogService(
        source: FakeCatalogSource(
          product: urun(),
          ingredientRows: [etkenMadde(display: 'Parasetamol')],
        ),
      );

      final result = await service.lookupGtin(gecerliGtin);

      expect(result.status, CatalogStatus.bulundu);
      expect(result.productName, 'Örnek İlaç A');
      expect(result.ingredients.single.name, 'Parasetamol');
      expect(result.needsReview, isFalse);
    });

    test('katalogdaYok: ürün satırı yoksa', () async {
      final service = CatalogService(source: FakeCatalogSource(product: null));

      final result = await service.lookupGtin(gecerliGtin);

      expect(result.status, CatalogStatus.katalogdaYok);
      expect(result.productName, isNull);
    });

    test('degerlendirilmedi: ürün var ama etken madde kaydı yok', () async {
      final service = CatalogService(
        source: FakeCatalogSource(product: urun(), ingredientRows: const []),
      );

      final result = await service.lookupGtin(gecerliGtin);

      expect(result.status, CatalogStatus.degerlendirilmedi);
      expect(result.productName, 'Örnek İlaç A');
      expect(result.reason, contains('kontrol tamamlanamadı'));
    });

    test('sorgulanamadi: sorgu sırasında hata oluşursa', () async {
      final service = CatalogService(
        source: FakeCatalogSource(
          productError: Exception('SocketException: Failed host lookup'),
        ),
      );

      final result = await service.lookupGtin(gecerliGtin);

      expect(result.status, CatalogStatus.sorgulanamadi);
      expect(result.reason, contains('bağlanılamadı'));
    });

    test('sorgulanamadi: etken madde sorgusu hata verirse ürün adı korunur',
        () async {
      final service = CatalogService(
        source: FakeCatalogSource(
          product: urun(),
          ingredientError: Exception('permission denied for table'),
        ),
      );

      final result = await service.lookupGtin(gecerliGtin);

      expect(result.status, CatalogStatus.sorgulanamadi);
      expect(result.productName, 'Örnek İlaç A');
      expect(result.reason, contains('oturum'));
    });
  });

  group('CatalogService — giriş doğrulama ve yapılandırma', () {
    test('geçersiz GTIN katalogdaYok değil, sorgulanamadi döner', () async {
      final service = CatalogService(
        source: FakeCatalogSource(product: urun()),
      );

      final result = await service.lookupGtin('12345');

      expect(result.status, CatalogStatus.sorgulanamadi);
      expect(result.status, isNot(CatalogStatus.katalogdaYok));
    });

    test('kontrol hanesi tutmayan 14 hane reddedilir', () async {
      final service = CatalogService(source: FakeCatalogSource());

      final result = await service.lookupGtin('99990000000001');

      expect(result.status, CatalogStatus.sorgulanamadi);
    });

    test('baştaki/sondaki boşluklar temizlenir', () async {
      final service = CatalogService(
        source: FakeCatalogSource(
          product: urun(),
          ingredientRows: [etkenMadde(display: 'Parasetamol')],
        ),
      );

      final result = await service.lookupGtin('  $gecerliGtin  ');

      expect(result.status, CatalogStatus.bulundu);
      expect(result.gtin, gecerliGtin);
    });

    test('Supabase yapılandırılmamışsa istisna değil sorgulanamadi döner',
        () async {
      const service = CatalogService();

      final result = await service.lookupGtin(gecerliGtin);

      expect(result.status, CatalogStatus.sorgulanamadi);
      expect(result.reason, contains('DEMO'));
    });
  });

  group('CatalogService — etken madde ayrıştırma', () {
    test('display_name yoksa normalized_name kullanılır', () {
      final list = CatalogService.parseIngredients([
        etkenMadde(normalized: 'parasetamol'),
      ]);

      expect(list.single.name, 'parasetamol');
    });

    test('çok etken maddeli ürün tüm maddeleri listeler', () {
      final list = CatalogService.parseIngredients([
        etkenMadde(display: 'Parasetamol'),
        etkenMadde(display: 'Kafein'),
      ]);

      expect(list.map((i) => i.name), ['Parasetamol', 'Kafein']);
    });

    test('aynı etken madde iki kez sayılmaz', () {
      final list = CatalogService.parseIngredients([
        etkenMadde(display: 'Parasetamol'),
        etkenMadde(display: 'parasetamol'),
      ]);

      expect(list, hasLength(1));
    });

    test('iç içe liste biçimi de desteklenir', () {
      final list = CatalogService.parseIngredients([
        {
          'ingredients': [
            {'display_name': 'Parasetamol', 'needs_review': false},
            {'display_name': 'Kafein', 'needs_review': true},
          ]
        }
      ]);

      expect(list, hasLength(2));
      expect(list.last.needsReview, isTrue);
    });

    test('adı boş olan kayıt atlanır', () {
      final list = CatalogService.parseIngredients([
        etkenMadde(display: '  ', normalized: ''),
        etkenMadde(display: 'Parasetamol'),
      ]);

      expect(list.single.name, 'Parasetamol');
    });
  });

  group('CatalogService — tıbbi dil sınırları', () {
    test('hiçbir mesajda "güvenli/doğrulandı/uygun" ifadesi geçmez', () {
      final mesajlar = [
        const CatalogResult(status: CatalogStatus.bulundu, gtin: gecerliGtin)
            .kullaniciMesaji,
        const CatalogResult(
                status: CatalogStatus.katalogdaYok, gtin: gecerliGtin)
            .kullaniciMesaji,
        const CatalogResult(
                status: CatalogStatus.degerlendirilmedi, gtin: gecerliGtin)
            .kullaniciMesaji,
        const CatalogResult(
                status: CatalogStatus.sorgulanamadi, gtin: gecerliGtin)
            .kullaniciMesaji,
      ];

      for (final mesaj in mesajlar) {
        final lower = mesaj.toLowerCase();
        expect(lower, isNot(contains('güvenli')));
        expect(lower, isNot(contains('doğrulandı')));
        expect(lower, isNot(contains('uygun')));
      }
    });

    test('katalogda bulunamadı mesajı ürünü doğrulanmış göstermez', () {
      const result =
          CatalogResult(status: CatalogStatus.katalogdaYok, gtin: gecerliGtin);

      expect(result.kullaniciMesaji, contains('doğrulanmadı'));
    });

    test('inceleme bekleyen etken madde kullanıcıya bildirilir', () {
      const result = CatalogResult(
        status: CatalogStatus.bulundu,
        gtin: gecerliGtin,
        ingredients: [CatalogIngredient(name: 'Ağrı kesici', needsReview: true)],
      );

      expect(result.needsReview, isTrue);
      expect(result.kullaniciMesaji, contains('inceleme'));
    });

    test('demo kaydı isDemo bayrağıyla işaretlenir', () async {
      final service = CatalogService(
        source: FakeCatalogSource(
          product: urun(demo: true),
          ingredientRows: [etkenMadde(display: 'Parasetamol')],
        ),
      );

      final result = await service.lookupGtin(gecerliGtin);

      expect(result.isDemo, isTrue);
    });
  });
}
