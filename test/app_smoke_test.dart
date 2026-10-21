import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/ui/medication_app.dart';

void main() {
  testWidgets('Ana ekranda demo etiketi ve ilaç listesi görülür', (tester) async {
    await tester.pumpWidget(const MedicationApp());
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('Bugünün ilaçları'), findsOneWidget);
    expect(find.text('Örnek İlaç A'), findsWidgets);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });
}
