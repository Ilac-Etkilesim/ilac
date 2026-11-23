import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilac_yakinlik_takip/services/catalog_service.dart';
import 'package:ilac_yakinlik_takip/ui/medication_app.dart';
import 'package:ilac_yakinlik_takip/ui/scan_result_sheet.dart';

void main() {
  testWidgets('Karekod okut butonu mevcuttur ve erişilebilirlik boyutunu (en az 48px) korur', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MedicationApp());

    final scanButtonFinder = find.byType(FloatingActionButton);
    expect(scanButtonFinder, findsOneWidget);

    final renderBox = tester.renderObject<RenderBox>(scanButtonFinder);
    expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
    expect(find.text('Karekod / İlaç Okut'), findsOneWidget);
  });

  testWidgets('ScanResultSheet.show fonksiyonu çağrıldığında sonuç alt sayfası açılır', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ScanResultSheet.show(
                  context,
                  result: CatalogLookupResult.found(
                    const CatalogProduct(
                      gtin: '99990000000008',
                      name: 'Örnek Ürün A',
                      activeIngredients: ['DEMO_ETKEN_A'],
                    ),
                  ),
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanResultSheet), findsOneWidget);
    expect(find.text('Örnek Ürün A'), findsOneWidget);
    expect(find.text('DEMO_ETKEN_A'), findsOneWidget);
    expect(find.text('Kapat'), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanResultSheet), findsNothing);
  });
}
