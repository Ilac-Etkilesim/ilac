import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kimlik doğrulama işlemlerini yöneten servis sınıfı.
///
/// Supabase bağlantısı yoksa veya publishable key tanımlanmamışsa
/// güvenli bir şekilde demo modunu destekler.
class AuthService {
  const AuthService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  /// Supabase istemcisinin başlatılıp başlatılmadığını güvenli şekilde döndürür.
  static bool get isConfigured {
    try {
      return Supabase.instance.client != null;
    } catch (_) {
      return false;
    }
  }

  /// Aktif Supabase istemcisini döndürür; henüz başlatılmamışsa null döner.
  SupabaseClient? get client {
    if (_clientOverride != null) return _clientOverride;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Aktif oturumdaki kullanıcı (varsa).
  User? get currentUser => client?.auth.currentUser;

  /// Kullanıcının e-posta adresi (varsa).
  String? get currentUserEmail => currentUser?.email;

  /// Kullanıcının oturum açıp açmadığı bilgisi.
  bool get isAuthenticated => currentUser != null;

  /// Auth durum değişikliklerini dinleyen stream.
  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;

  /// E-posta ve şifre ile giriş yapar.
  ///
  /// Başarısızlık durumunda anlaşılır Türkçe mesaj içeren [AuthException] fırlatır.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw const AuthException(
        'Supabase bağlantısı henüz yapılandırılmadı. Lütfen Demo modunda devam ediniz.',
      );
    }

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(mapAuthError(e.message, statusCode: e.statusCode));
    } catch (e) {
      throw AuthException(
        'Giriş yapılırken beklenmeyen bir hata oluştu: $e',
      );
    }
  }

  /// Oturumu kapatır.
  Future<void> signOut() async {
    final supabase = client;
    if (supabase != null) {
      try {
        await supabase.auth.signOut();
      } catch (e) {
        debugPrint('Çıkış yapılırken hata oluştu: $e');
      }
    }
  }

  /// Supabase veya ağdan gelen hata mesajlarını anlaşılır Türkçe metinlere dönüştürür.
  static String mapAuthError(String rawMessage, {String? statusCode}) {
    final lower = rawMessage.toLowerCase();

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid email or password')) {
      return 'E-posta veya şifre hatalı. Lütfen bilgilerinizi kontrol ediniz.';
    }
    if (lower.contains('email not confirmed')) {
      return 'E-posta adresiniz henüz onaylanmamış. Lütfen e-postanızı kontrol ediniz.';
    }
    if (lower.contains('user not found')) {
      return 'Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.';
    }
    if (lower.contains('too many requests') ||
        lower.contains('rate limit') ||
        lower.contains('over_request_rate_limit')) {
      return 'Çok fazla başarısız deneme yapıldı. Lütfen biraz bekleyip tekrar deneyiniz.';
    }
    if (lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused')) {
      return 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol ediniz.';
    }
    if (lower.contains('password should be at least')) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    if (lower.contains('unable to validate email address')) {
      return 'Lütfen geçerli bir e-posta adresi giriniz.';
    }

    return 'Giriş yapılamadı: $rawMessage';
  }
}
