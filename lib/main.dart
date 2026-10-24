import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/medication_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  // Demo, Supabase olmadan açılır. Gerçek Auth/veri bağlantısı henüz kurulmadı.
  // Hatalı/bozuk URL-anahtar verilirse bile DEMO ekranı açılabilsin diye hata yutuluyor.
  if (url.isNotEmpty && publishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
      );
    } catch (e) {
      debugPrint('Supabase başlatılamadı, DEMO modunda devam ediliyor: $e');
    }
  }

  runApp(const MedicationApp());
}
