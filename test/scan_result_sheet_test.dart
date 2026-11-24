import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/services/catalog_service.dart';
import 'package:ilac_yakinlik_takip/ui/scan_result_sheet.dart';

void main() {
  Widget createTestWidget(CatalogResult result, {VoidCallback? onRetry}) {
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
      const result = CatalogResult(
        status: CatalogStatus.bulundu,
        gtin: '99990000000008',
        productName: 'Örnek İlaç A',
        ingredients: [
          CatalogIngredient(name: 'Asetilsalisilik Asit 100 mg'),
          CatalogIngredient(name: 'DEMO_ETKEN_A'),
        ],
        isDemo: true,
      );

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

    testWidgets('2. "degerlendirilmedi" durumu: ürün var ama etken madde yoksa açıkça gösterilir', (tester) async {
      const result = CatalogResult(
        status: CatalogStatus.degerlendirilmedi,
        gtin: '99990000000015',
        productName: 'Örnek İlaç B',
        reason: 'Ürünün etken maddesi kayıtlı değil; kontrol tamamlanamadı.',
        isDemo: true,
      );

      await tester.pumpWidget(createTestWidget(result));

      // Ürün adı görünmeli
      expect(find.byKey(const Key('scan_result_product_name')), findsOneWidget);
      expect(find.text('Örnek İlaç B'), findsOneWidget);

      // Etken madde kaydı yok kartı ve nedeni
      expect(find.text('Etken Madde Kaydı Yok'), findsOneWidget);
      expect(find.byKey(const Key('scan_result_not_evaluated_reason')), findsOneWidget);
      expect(find.textContaining('kontrol tamamlanamadı'), findsOneWidget);

      // Tıbbi değerlendirme yapılamaz uyarısı
      expect(find.textContaining('etkileşim değerlendirmesi yapılamaz'), findsOneWidget);
    });

    testWidgets('3. "katalogdaYok" durumu: farklı ve açık bir mesajla gösterilir', (tester) async {
      const result = CatalogResult(
        status: CatalogStatus.katalogdaYok,
        gtin: '99990000009999',
      );

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

    testWidgets('4. "sorgulanamadi" durumu: farklı ve açık bir hata mesajı ile gösterilir', (tester) async {
      const result = CatalogResult(
        status: CatalogStatus.sorgulanamadi,
        gtin: '',
        reason: 'Sunucuya bağlanılamadı; katalog kontrolü tamamlanamadı.',
      );

      var retried = false;
      await tester.pumpWidget(createTestWidget(result, onRetry: () => retried = true));

      // Başlık
      expect(find.byKey(const Key('scan_result_query_failed_title')), findsOneWidget);
      expect(find.text('Sorgulanamadı'), findsOneWidget);

      // Hata mesajı
      expect(find.byKey(const Key('scan_result_failed_message')), findsOneWidget);
      expect(find.text('Sunucuya bağlanılamadı; katalog kontrolü tamamlanamadı.'), findsOneWidget);

      // Yeniden dene butonu
      expect(find.byKey(const Key('scan_result_retry_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scan_result_retry_button')));
      expect(retried, isTrue);
    });

    testWidgets('5. Yaşlı kullanıcı için dokunma alanı en az 48 px kuralını karşılar (52 px)', (tester) async {
      const result = CatalogResult(
        status: CatalogStatus.bulundu,
        gtin: '99990000000008',
        productName: 'Örnek İlaç A',
        ingredients: [CatalogIngredient(name: 'DEMO_ETKEN_A')],
      );

      await tester.pumpWidget(createTestWidget(result));

      final closeButtonFinder = find.byKey(const Key('scan_result_close_button'));
      expect(closeButtonFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(closeButtonFinder);
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, equals(52.0));
    });

    testWidgets('6. KABUL KRİTERİ: Ekranda hiçbir yerde "güvenli", "doğrulandı" veya "uygun" ifadesi bulunmaz',
        (tester) async {
      // 4 durumu da test edelim:
      final scenarios = [
        const CatalogResult(
          status: CatalogStatus.bulundu,
          gtin: '99990000000008',
          productName: 'Örnek İlaç A',
          ingredients: [CatalogIngredient(name: 'DEMO_ETKEN_A')],
        ),
        const CatalogResult(
          status: CatalogStatus.degerlendirilmedi,
          gtin: '99990000000015',
          productName: 'Örnek İlaç B',
          reason: 'Ürünün etken maddesi kayıtlı değil; kontrol tamamlanamadı.',
        ),
        const CatalogResult(
          status: CatalogStatus.katalogdaYok,
          gtin: '99990000009999',
        ),
        const CatalogResult(
          status: CatalogStatus.sorgulanamadi,
          gtin: '',
          reason: 'Karekod okunamadı.',
        ),
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
