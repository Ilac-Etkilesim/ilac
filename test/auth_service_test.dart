import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_yakinlik_takip/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthService Hata Çevirisi (mapAuthError)', () {
    test('Hatalı kimlik bilgisi Türkçe mesaja dönüştürülür', () {
      final msg = AuthService.mapAuthError('Invalid login credentials');
      expect(msg, 'E-posta veya şifre hatalı. Lütfen bilgilerinizi kontrol ediniz.');
    });

    test('Onaylanmamış e-posta Türkçe mesaja dönüştürülür', () {
      final msg = AuthService.mapAuthError('Email not confirmed');
      expect(msg, 'E-posta adresiniz henüz onaylanmamış. Lütfen e-postanızı kontrol ediniz.');
    });

    test('Kullanıcı bulunamadı hatası Türkçe mesaja dönüştürülür', () {
      final msg = AuthService.mapAuthError('User not found');
      expect(msg, 'Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.');
    });

    test('Rate limit / aşırı deneme hatası Türkçe mesaja dönüştürülür', () {
      final msg = AuthService.mapAuthError('Too many requests, try again later');
      expect(msg, 'Çok fazla başarısız deneme yapıldı. Lütfen biraz bekleyip tekrar deneyiniz.');
    });

    test('Ağ hatası Türkçe mesaja dönüştürülür', () {
      final msg = AuthService.mapAuthError('SocketException: Failed host lookup');
      expect(msg, 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol ediniz.');
    });

    test('Kısa şifre hatası Türkçe mesaja dönüştürülür', () {
      final msg = AuthService.mapAuthError('Password should be at least 6 characters');
      expect(msg, 'Şifre en az 6 karakter olmalıdır.');
    });

    test('Bilinmeyen bir hata orijinal mesajla formatlanır', () {
      final msg = AuthService.mapAuthError('Some random auth error');
      expect(msg, 'Giriş yapılamadı: Some random auth error');
    });
  });

  group('AuthService Bağlantı ve İstemci Durumu', () {
    test('Supabase initialize edilmediğinde isConfigured false döner', () {
      expect(AuthService.isConfigured, isFalse);
    });

    test('Supabase initialize edilmediğinde signInWithPassword hata fırlatır', () async {
      const service = AuthService();
      expect(
        () => service.signInWithPassword(email: 'test@ornek.com', password: 'secretpassword'),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Supabase bağlantısı henüz yapılandırılmadı'),
        )),
      );
    });
  });
}
