import 'package:flutter/material.dart';
import '../core/gs1_parser.dart';
import '../services/auth_service.dart';
import 'caregiver_page.dart';
import 'login_page.dart';
import 'patient_page.dart';
import 'scanner_page.dart';

const kBlue = Color(0xFF2469CE);
const kNavy = Color(0xFF19345E);
const kBackground = Color(0xFFF3F7FC);

class MedicationApp extends StatelessWidget {
  const MedicationApp({
    super.key,
    this.home,
    this.authService = const AuthService(),
  });

  /// Test veya özel durumlar için başlangıç ekranı override'ı.
  final Widget? home;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    // Başlangıç ekranını belirle:
    // 1. Parametre olarak home verildiyse onu kullan.
    // 2. Supabase yapılandırılmamışsa (publishable key boşsa veya demo modunda) -> doğrudan HomeShell(isDemoMode: true).
    // 3. Supabase yapılandırılmış ve oturum açıksa -> HomeShell(isDemoMode: false).
    // 4. Supabase yapılandırılmış ama oturum yoksa -> LoginPage().
    final Widget initialScreen = home ??
        (!AuthService.isConfigured
            ? const HomeShell(isDemoMode: true)
            : (authService.isAuthenticated
                ? const HomeShell(isDemoMode: false)
                : const LoginPage()));

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
      home: initialScreen,
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.isDemoMode = true,
    this.authService = const AuthService(),
  });

  final bool isDemoMode;
  final AuthService authService;

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

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: Text(
          widget.isDemoMode
              ? 'Demo modundan çıkıp giriş ekranına dönmek istiyor musunuz?'
              : 'Oturumunuz kapatılacaktır. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE02424),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.authService.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = widget.authService.currentUserEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'İlaç ve Yakınlık Takibi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (widget.isDemoMode)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Center(child: Chip(label: Text('DEMO'))),
            )
          else if (userEmail != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Tooltip(
                  message: userEmail,
                  child: Chip(
                    avatar: const Icon(Icons.person, size: 16),
                    label: Text(
                      userEmail.length > 14
                          ? '${userEmail.substring(0, 11)}...'
                          : userEmail,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: _handleSignOut,
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
