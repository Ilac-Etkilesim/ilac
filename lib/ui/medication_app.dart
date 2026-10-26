import 'package:flutter/material.dart';
import '../core/gs1_parser.dart';
import 'caregiver_page.dart';
import 'patient_page.dart';
import 'scanner_page.dart';

const kBlue = Color(0xFF2469CE);
const kNavy = Color(0xFF19345E);
const kBackground = Color(0xFFF3F7FC);

class MedicationApp extends StatelessWidget {
  const MedicationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İlaç ve Yakınlık Takibi',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kBlue, surface: Colors.white),
        scaffoldBackgroundColor: kBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBackground,
          foregroundColor: kNavy,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE1E9F3)),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.bold, color: kNavy),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: kNavy),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: kNavy),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedIndex = 0;

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (!mounted || code == null) return;
    final gtin = extractGtin(code);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 7),
      content: Text(gtin == null
          ? 'Kod okundu, fakat GTIN ayrıştırılamadı. Ürün doğrulanmadı.'
          : 'GTIN: $gtin — Ürün eşleştirme ve tıbbi kontrol henüz bağlı değil.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlaç ve Yakınlık Takibi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text('DEMO'))),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: const [PatientPage(), CaregiverPage()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedIndex == 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 66,
                  child: FloatingActionButton.extended(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner, size: 30),
                    label: const Text('Karekod / İlaç Okut',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    elevation: 4,
                  ),
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.medication_outlined), label: 'Hasta'),
          NavigationDestination(icon: Icon(Icons.family_restroom), label: 'Yakınım'),
        ],
      ),
    );
  }
}
