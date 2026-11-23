import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/services/catalog_service.dart';
import 'package:ilac_yakinlik_takip/ui/scan_result_sheet.dart';

void main() {
  Widget createTestWidget(CatalogLookupResult result, {VoidCallback? onRetry}) {
    return MaterialApp(
      home: Scaffold(
        body: ScanResultSheet(
          result: result,
          onRetry: onRetry,
        ),
      ),
    );
  }

  group('ScanResultSheet Widget Testleri', () {
    testWidgets('1. Ürün bulunduğunda ürün adı ve etken madde(ler) ekranda gösterilir', (tester) async {
      const product = CatalogProduct(
        gtin: '99990000000008',
        name: 'Örnek İlaç A',
        activeIngredients: ['Asetilsalisilik Asit 100 mg', 'DEMO_ETKEN_A'],
        isDemo: true,
      );
      final result = CatalogLookupResult.found(product);

      await tester.pumpWidget(createTestWidget(result));

      // Ürün adı görünmeli
      expect(find.byKey(const Key('scan_result_product_name')), findsOneWidget);
      expect(find.text('Örnek İlaç A'), findsOneWidget);

      // Etken maddeler görünmeli
      expect(find.byKey(const Key('scan_result_ingredients')), findsOneWidget);
      expect(find.text('Asetilsalisilik Asit 100 mg, DEMO_ETKEN_A'), findsOneWidget);

      // Barkod (GTIN) görünmeli
      expect(find.byKey(const Key('scan_result_gtin')), findsOneWidget);
      expect(find.textContaining('99990000000008'), findsOneWidget);

      // Demo etiketi görünmeli
      expect(find.text('DEMO VERİSİ · TEMSİLİ KAYIT'), findsOneWidget);

      // Tıbbi sınır uyarısı yer almalı
      expect(
        find.textContaining('İlaç etkileşim kontrolü bu sürümde henüz bağlı değildir'),
        findsOneWidget,
      );
    });

    testWidgets('2. "Katalogda bulunamadı" durumu farklı ve açık bir mesajla gösterilir', (tester) async {
      final result = CatalogLookupResult.notFound(gtin: '99990000009999');

      await tester.pumpWidget(createTestWidget(result));

      // Başlık
      expect(find.byKey(const Key('scan_result_not_found_title')), findsOneWidget);
      expect(find.text('Katalogda Bulunamadı'), findsOneWidget);

      // Açıklama ve GTIN
      expect(find.textContaining('katalog kayıtlarında yer almıyor'), findsOneWidget);
      expect(find.byKey(const Key('scan_result_not_found_gtin')), findsOneWidget);
      expect(find.textContaining('99990000009999'), findsOneWidget);

      // Tıbbi bilgilendirme uyarısı
      expect(find.textContaining('etkileşim kontrolü yapılamaz'), findsOneWidget);
    });

    testWidgets('3. "Sorgulanamadı" durumu farklı ve açık bir mesajla gösterilir', (tester) async {
      final result = CatalogLookupResult.queryFailed(
        message: 'Karekod okunamadı veya sunucuya erişilemedi.',
      );

      var retried = false;
      await tester.pumpWidget(createTestWidget(result, onRetry: () => retried = true));

      // Başlık
      expect(find.byKey(const Key('scan_result_query_failed_title')), findsOneWidget);
      expect(find.text('Sorgulanamadı'), findsOneWidget);

      // Hata mesajı
      expect(find.byKey(const Key('scan_result_failed_message')), findsOneWidget);
      expect(find.text('Karekod okunamadı veya sunucuya erişilemedi.'), findsOneWidget);

      // Yeniden dene butonu
      expect(find.byKey(const Key('scan_result_retry_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scan_result_retry_button')));
      expect(retried, isTrue);
    });

    testWidgets('4. Yaşlı kullanıcı için dokunma alanı en az 48 px kuralını karşılar', (tester) async {
      const product = CatalogProduct(
        gtin: '99990000000008',
        name: 'Örnek İlaç A',
        activeIngredients: ['DEMO_ETKEN_A'],
      );
      final result = CatalogLookupResult.found(product);

      await tester.pumpWidget(createTestWidget(result));

      final closeButtonFinder = find.byKey(const Key('scan_result_close_button'));
      expect(closeButtonFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(closeButtonFinder);
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
      // Tasarımımızda 52 px olarak belirlendi:
      expect(renderBox.size.height, equals(52.0));
    });

    testWidgets('5. KABUL KRİTERİ: Ekranda hiçbir yerde "güvenli", "doğrulandı" veya "uygun" ifadesi bulunmaz',
        (tester) async {
      // 3 durumu da test edelim:
      final scenarios = [
        CatalogLookupResult.found(
          const CatalogProduct(
            gtin: '99990000000008',
            name: 'Örnek İlaç A',
            activeIngredients: ['DEMO_ETKEN_A'],
          ),
        ),
        CatalogLookupResult.notFound(gtin: '99990000009999'),
        CatalogLookupResult.queryFailed(),
      ];

      final forbiddenWords = ['güvenli', 'doğrulandı', 'uygun'];

      for (final scenario in scenarios) {
        await tester.pumpWidget(createTestWidget(scenario));

        final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final textWidget in allTextWidgets) {
          final content = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
          final lowerContent = content.toLowerCase();

          for (final word in forbiddenWords) {
            expect(
              lowerContent.contains(word),
              isFalse,
              reason: 'Yasaklı kelime ("$word") bulundu: "$content"',
            );
          }
        }
      }
    });
  });
}
