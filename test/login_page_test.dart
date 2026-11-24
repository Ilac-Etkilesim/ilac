import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/services/auth_service.dart';
import 'package:ilac_yakinlik_takip/ui/login_page.dart';
import 'package:ilac_yakinlik_takip/ui/medication_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeFailingAuthService extends AuthService {
  const _FakeFailingAuthService();

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw const AuthException('E-posta veya şifre hatalı. Lütfen bilgilerinizi kontrol ediniz.');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createLoginWidget({AuthService authService = const AuthService()}) {
    return MaterialApp(
      home: LoginPage(authService: authService),
    );
  }

  Future<void> setLargeScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> tapTarget(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('Giriş ekranında gerekli bileşenler ve zorunlu demo notu görünür', (tester) async {
    await setLargeScreen(tester);
    await tester.pumpWidget(createLoginWidget());

    // Başlık ve logo
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('İlaç ve Yakınlık Takibi'), findsOneWidget);

    // Zorunlu Demo Uyarı Metni
    expect(
      find.text('Bu bir demo girişidir, gerçek hasta hesabı değildir. Yalnızca test kullanıcıları içindir.'),
      findsOneWidget,
    );

    // Form alanları
    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);

    // Butonlar
    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
    expect(find.byKey(const Key('login_demo_button')), findsOneWidget);
  });

  testWidgets('Form boş bırakılıp Giriş Yap tıklandığında Türkçe validasyon hataları gösterilir', (tester) async {
    await setLargeScreen(tester);
    await tester.pumpWidget(createLoginWidget());

    final loginButton = find.byKey(const Key('login_submit_button'));
    await tapTarget(tester, loginButton);

    expect(find.text('Lütfen e-posta adresinizi giriniz.'), findsOneWidget);
  });

  testWidgets('Geçersiz e-posta girildiğinde validasyon hatası gösterilir', (tester) async {
    await setLargeScreen(tester);
    await tester.pumpWidget(createLoginWidget());

    final emailField = find.byKey(const Key('login_email_field'));
    await tester.enterText(emailField, 'gecersiz-eposta');
    await tester.pumpAndSettle();

    final loginButton = find.byKey(const Key('login_submit_button'));
    await tapTarget(tester, loginButton);

    expect(find.text('Lütfen geçerli bir e-posta adresi giriniz.'), findsOneWidget);
  });

  testWidgets('Giriş başarısız olduğunda ekranda Türkçe hata mesajı gösterilir', (tester) async {
    await setLargeScreen(tester);
    await tester.pumpWidget(createLoginWidget(
      authService: const _FakeFailingAuthService(),
    ));

    final emailField = find.byKey(const Key('login_email_field'));
    await tester.enterText(emailField, 'test@ornek.com');

    final passwordField = find.byKey(const Key('login_password_field'));
    await tester.enterText(passwordField, '123456');
    await tester.pumpAndSettle();

    final loginButton = find.byKey(const Key('login_submit_button'));
    await tapTarget(tester, loginButton);

    expect(
      find.text('E-posta veya şifre hatalı. Lütfen bilgilerinizi kontrol ediniz.'),
      findsOneWidget,
    );
  });

  testWidgets('Giriş yapmadan demo olarak devam et tıklandığında HomeShell ekranına yönlendirilir', (tester) async {
    await setLargeScreen(tester);
    await tester.pumpWidget(createLoginWidget());

    final demoButton = find.byKey(const Key('login_demo_button'));
    await tapTarget(tester, demoButton);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('Bugünün ilaçları'), findsOneWidget);
  });

  testWidgets('HomeShell üzerinde çıkış butonu bulunur ve tıklandığında onay diyalogu açılır', (tester) async {
    await setLargeScreen(tester);
    await tester.pumpWidget(const MaterialApp(
      home: HomeShell(isDemoMode: true),
    ));

    final logoutButton = find.byIcon(Icons.logout);
    expect(logoutButton, findsOneWidget);

    await tapTarget(tester, logoutButton);

    expect(find.text('Çıkış Yap'), findsWidgets);
    expect(find.text('İptal'), findsOneWidget);
  });
}
