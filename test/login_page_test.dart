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

  testWidgets('Giriş ekranında gerekli bileşenler ve zorunlu demo notu görünür', (tester) async {
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
    expect(find.text('E-posta Adresi'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);

    // Butonlar
    expect(find.widgetWithText(ElevatedButton, 'Giriş Yap'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Giriş Yapmadan Demo Olarak Devam Et'),
      findsOneWidget,
    );
  });

  testWidgets('Form boş bırakılıp Giriş Yap tıklandığında Türkçe validasyon hataları gösterilir', (tester) async {
    await tester.pumpWidget(createLoginWidget());

    final loginButton = find.widgetWithText(ElevatedButton, 'Giriş Yap');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Lütfen e-posta adresinizi giriniz.'), findsOneWidget);
  });

  testWidgets('Geçersiz e-posta girildiğinde validasyon hatası gösterilir', (tester) async {
    await tester.pumpWidget(createLoginWidget());

    final emailField = find.widgetWithText(TextFormField, 'ornek@alanadi.com');
    await tester.enterText(emailField, 'gecersiz-eposta');

    final loginButton = find.widgetWithText(ElevatedButton, 'Giriş Yap');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Lütfen geçerli bir e-posta adresi giriniz.'), findsOneWidget);
  });

  testWidgets('Giriş başarısız olduğunda ekranda Türkçe hata mesajı gösterilir', (tester) async {
    await tester.pumpWidget(createLoginWidget(
      authService: const _FakeFailingAuthService(),
    ));

    final emailField = find.widgetWithText(TextFormField, 'ornek@alanadi.com');
    await tester.enterText(emailField, 'test@ornek.com');

    final passwordFields = find.byType(TextFormField);
    await tester.enterText(passwordFields.at(1), '123456');

    final loginButton = find.widgetWithText(ElevatedButton, 'Giriş Yap');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(
      find.text('E-posta veya şifre hatalı. Lütfen bilgilerinizi kontrol ediniz.'),
      findsOneWidget,
    );
  });

  testWidgets('Giriş yapmadan demo olarak devam et tıklandığında HomeShell ekranına yönlendirilir', (tester) async {
    await tester.pumpWidget(createLoginWidget());

    final demoButton = find.widgetWithText(OutlinedButton, 'Giriş Yapmadan Demo Olarak Devam Et');
    await tester.tap(demoButton);
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('Bugünün ilaçları'), findsOneWidget);
  });

  testWidgets('HomeShell üzerinde çıkış butonu bulunur ve tıklandığında onay diyalogu açılır', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeShell(isDemoMode: true),
    ));

    final logoutButton = find.byIcon(Icons.logout);
    expect(logoutButton, findsOneWidget);

    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(find.text('Çıkış Yap'), findsWidgets);
    expect(find.text('İptal'), findsOneWidget);
  });
}
