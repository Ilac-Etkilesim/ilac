import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/services/catalog_service.dart';

void main() {
  group('CatalogService testleri', () {
    const service = CatalogService();

    test('Kayıtlı demo GTIN ile ürün adı ve etken madde(ler) başarıyla bulunur', () async {
      // 99990000000008 demo_products.csv içindeki Örnek Ürün A
      final result = await service.lookupByGtin('99990000000008');

      expect(result.status, CatalogResultStatus.found);
      expect(result.isFound, isTrue);
      expect(result.product, isNotNull);
      expect(result.product!.name, 'Örnek Ürün A');
      expect(result.product!.activeIngredients, contains('DEMO_ETKEN_A'));
      expect(result.product!.isDemo, isTrue);
    });

    test('DataMatrix ham verisinden (GS1 formatı) ürün başarıyla eşleştirilir', () async {
      // ]d2019999000000001521LOT1234
      final result = await service.lookup(']d2019999000000001521LOT1234');

      expect(result.status, CatalogResultStatus.found);
      expect(result.product!.name, 'Örnek Ürün B');
      expect(result.product!.activeIngredients, contains('DEMO_ETKEN_B'));
    });

    test('Parantezli GS1 formatından ürün başarıyla eşleştirilir', () async {
      // (01)99990000000022(17)261231
      final result = await service.lookup('(01)99990000000022(17)261231');

      expect(result.status, CatalogResultStatus.found);
      expect(result.product!.name, 'Örnek Ürün C');
      expect(result.product!.activeIngredients, contains('DEMO_ETKEN_C'));
    });

    test('Katalogda olmayan geçerli GTIN "Katalogda bulunamadı" (notFound) olarak döner', () async {
      // 01234567890128 dışındaki geçerli GTIN kontrol rakamlı numara: 00000000000000
      final result = await service.lookupByGtin('00000000000000');

      expect(result.status, CatalogResultStatus.notFound);
      expect(result.isNotFound, isTrue);
      expect(result.gtin, '00000000000000');
      expect(result.product, isNull);
      expect(result.message, contains('Katalogda bulunamadı'));
    });

    test('Karekod okunamadığında veya boş geldiğinde "Sorgulanamadı" (queryFailed) olarak döner', () async {
      final nullResult = await service.lookup(null);
      expect(nullResult.status, CatalogResultStatus.queryFailed);
      expect(nullResult.isQueryFailed, isTrue);

      final emptyResult = await service.lookup('   ');
      expect(emptyResult.status, CatalogResultStatus.queryFailed);
    });

    test('Bozuk veya GTIN içermeyen karekodda "Sorgulanamadı" (queryFailed) olarak döner', () async {
      final invalidResult = await service.lookup('rastgele-tanimsiz-karekod');
      expect(invalidResult.status, CatalogResultStatus.queryFailed);
      expect(invalidResult.isQueryFailed, isTrue);
      expect(invalidResult.message, contains('ayrıştırılamadı'));
    });

    test('Özel katalog ile başlatıldığında özel ürünleri çözer', () async {
      final customService = CatalogService(
        initialCatalog: {
          '11111111111117': const CatalogProduct(
            gtin: '11111111111117',
            name: 'Özel Test İlacı',
            activeIngredients: ['Özel Etken Madde'],
          ),
        },
      );

      final result = await customService.lookupByGtin('11111111111117');
      expect(result.status, CatalogResultStatus.found);
      expect(result.product!.name, 'Özel Test İlacı');
      expect(result.product!.ingredientsSummary, 'Özel Etken Madde');
    });
  });
}
