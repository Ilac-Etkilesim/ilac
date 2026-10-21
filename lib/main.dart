import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/medication_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  // Demo, Supabase olmadan açılır. Gerçek Auth/veri bağlantısı henüz kurulmadı.
  if (url.isNotEmpty && publishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }

  runApp(const MedicationApp());
}
