import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/gs1_parser.dart';

/// Katalog sorgusunun sonucu (Issue #31).
///
/// Durum isimleri sunucudaki `check_drug_risk()` ile bilinçli olarak hizalıdır
/// (`product_not_found`, `not_evaluated`), böylece Sprint 4'te etkileşim
/// kontrolü eklenirken aynı sözlük kullanılabilir.
///
/// **Tıbbi sınır:** Hiçbir durum "ilaç güvenli" anlamına gelmez.
/// [katalogdaYok] ("bu kodu tanımıyoruz") ile [sorgulanamadi] ("soramadık")
/// asla aynı duruma indirgenmemelidir.
enum CatalogStatus {
  /// Ürün ve en az bir etken madde katalogda bulundu.
  bulundu,

  /// GTIN katalogda kayıtlı değil. Ürünün var olmadığını kanıtlamaz.
  katalogdaYok,

  /// Ürün var ama etken maddesi kayıtlı değil; kontrol tamamlanamaz.
  degerlendirilmedi,

  /// Sorgu hiç yapılamadı: bağlantı yok, yetki yok veya kod biçimi geçersiz.
  sorgulanamadi,
}

/// Katalogda bulunan tek bir etken madde.
@immutable
class CatalogIngredient {
  const CatalogIngredient({
    required this.name,
    this.needsReview = false,
  });

  /// Gösterilecek ad (`display_name`, yoksa `normalized_name`).
  final String name;

  /// TİTCK kaynağında etken madde yerine kategori adı geçen kayıtlar için.
  /// Bu kayıtlar doğrulanmış etken madde sayılmaz.
  final bool needsReview;
}

/// Katalog sorgusunun sonucu.
@immutable
class CatalogResult {
  const CatalogResult({
    required this.status,
    required this.gtin,
    this.productName,
    this.ingredients = const <CatalogIngredient>[],
    this.isDemo = false,
    this.reason,
  });

  final CatalogStatus status;
  final String gtin;

  /// Ürün adı; yalnızca [CatalogStatus.bulundu] ve
  /// [CatalogStatus.degerlendirilmedi] durumlarında dolu olur.
  final String? productName;

  final List<CatalogIngredient> ingredients;

  /// Kayıt demo/kurgusal veriden geliyorsa true. Arayüz bunu DEMO olarak
  /// etiketlemek zorundadır.
  final bool isDemo;

  /// [CatalogStatus.sorgulanamadi] ve [CatalogStatus.degerlendirilmedi]
  /// durumlarında nedenin kullanıcıya gösterilebilir açıklaması.
  final String? reason;

  /// Etken maddelerden en az biri inceleme bekliyorsa true.
  bool get needsReview => ingredients.any((i) => i.needsReview);

  /// Arayüzün doğrudan kullanabileceği varsayılan Türkçe metin.
  ///
  /// Bilinçli olarak hiçbir durumda "güvenli", "doğrulandı" veya "uygun"
  /// ifadesi geçmez; etkileşim kontrolü bu sürümde bağlı değildir.
  String get kullaniciMesaji {
    switch (status) {
      case CatalogStatus.bulundu:
        if (needsReview) {
          return 'Ürün katalogda bulundu, ancak etken madde bilgisi inceleme '
              'bekliyor. İlaç kontrolü tamamlanmadı.';
        }
        return 'Ürün katalogda bulundu. Etkileşim kontrolü henüz bağlı değil.';
      case CatalogStatus.katalogdaYok:
        return 'Bu kod katalogda bulunamadı. Ürün doğrulanmadı.';
      case CatalogStatus.degerlendirilmedi:
        return reason ??
            'Ürünün etken maddesi kayıtlı değil; kontrol tamamlanamadı.';
      case CatalogStatus.sorgulanamadi:
        return reason ?? 'Katalog sorgulanamadı. Kontrol tamamlanamadı.';
    }
  }
}

/// Katalog satırlarını getiren kaynak. Testlerde sahte uygulama verilebilsin,
/// üretimde Supabase kullanılsın diye ayrıştırılmıştır.
abstract class CatalogSource {
  /// `products` tablosundan tek satır; kayıt yoksa null.
  Future<Map<String, dynamic>?> fetchProduct(String gtin);

  /// `product_ingredients` üzerinden bağlı `ingredients` satırları.
  Future<List<Map<String, dynamic>>> fetchIngredients(String gtin);
}

/// Supabase tablolarını doğrudan sorgulayan kaynak.
///
/// Ali'nin #30 sorgusu hazır olduğunda bu sınıf RPC çağrısına çevrilebilir;
/// [CatalogService] ve arayüz tarafı değişmez.
class SupabaseCatalogSource implements CatalogSource {
  const SupabaseCatalogSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> fetchProduct(String gtin) async {
    return await _client
        .from('products')
        .select('gtin, display_name, is_demo')
        .eq('gtin', gtin)
        .maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients(String gtin) async {
    final rows = await _client
        .from('product_ingredients')
        .select('ingredients(display_name, normalized_name, needs_review)')
        .eq('product_gtin', gtin);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}

/// Okunan GTIN'i katalogla eşleştiren servis (Issue #31).
///
/// Supabase yapılandırılmamışsa uygulama DEMO modunda çalışmaya devam eder;
/// bu durumda sorgu [CatalogStatus.sorgulanamadi] döner, istisna fırlatmaz.
class CatalogService {
  const CatalogService({CatalogSource? source}) : _sourceOverride = source;

  final CatalogSource? _sourceOverride;

  /// Supabase istemcisi başlatılmış mı?
  static bool get isConfigured {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kullanılacak kaynak; Supabase başlatılmamışsa null.
  CatalogSource? get source {
    if (_sourceOverride != null) return _sourceOverride;
    try {
      return SupabaseCatalogSource(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  /// GTIN ile katalog sorgusu yapar. Hiçbir koşulda istisna fırlatmaz;
  /// her hata [CatalogStatus.sorgulanamadi] olarak döner.
  Future<CatalogResult> lookupGtin(String rawGtin) async {
    final gtin = rawGtin.trim();

    if (!isValidGtin14(gtin)) {
      return CatalogResult(
        status: CatalogStatus.sorgulanamadi,
        gtin: gtin,
        reason: 'Kod 14 haneli geçerli bir GTIN değil; katalog sorgulanmadı.',
      );
    }

    final catalogSource = source;
    if (catalogSource == null) {
      return CatalogResult(
        status: CatalogStatus.sorgulanamadi,
        gtin: gtin,
        reason: 'Katalog bağlantısı yapılandırılmadı (DEMO modu). '
            'Kontrol tamamlanamadı.',
      );
    }

    final Map<String, dynamic>? product;
    try {
      product = await catalogSource.fetchProduct(gtin);
    } catch (e) {
      debugPrint('Katalog ürün sorgusu başarısız: $e');
      return CatalogResult(
        status: CatalogStatus.sorgulanamadi,
        gtin: gtin,
        reason: mapCatalogError(e),
      );
    }

    if (product == null) {
      return CatalogResult(status: CatalogStatus.katalogdaYok, gtin: gtin);
    }

    final productName = (product['display_name'] as String?)?.trim();
    final isDemo = product['is_demo'] == true;

    final List<Map<String, dynamic>> rows;
    try {
      rows = await catalogSource.fetchIngredients(gtin);
    } catch (e) {
      debugPrint('Katalog etken madde sorgusu başarısız: $e');
      return CatalogResult(
        status: CatalogStatus.sorgulanamadi,
        gtin: gtin,
        productName: productName,
        isDemo: isDemo,
        reason: mapCatalogError(e),
      );
    }

    final ingredients = parseIngredients(rows);
    if (ingredients.isEmpty) {
      return CatalogResult(
        status: CatalogStatus.degerlendirilmedi,
        gtin: gtin,
        productName: productName,
        isDemo: isDemo,
        reason: 'Ürünün etken maddesi kayıtlı değil; kontrol tamamlanamadı.',
      );
    }

    return CatalogResult(
      status: CatalogStatus.bulundu,
      gtin: gtin,
      productName: productName,
      ingredients: ingredients,
      isDemo: isDemo,
    );
  }

  /// `ingredients(...)` iç içe satırlarını ayrıştırır.
  ///
  /// Supabase iç içe ilişkiyi tek nesne veya liste olarak döndürebildiği için
  /// iki biçim de desteklenir. Adı boş olan kayıtlar atlanır.
  @visibleForTesting
  static List<CatalogIngredient> parseIngredients(
    List<Map<String, dynamic>> rows,
  ) {
    final result = <CatalogIngredient>[];
    final seen = <String>{};

    for (final row in rows) {
      final nested = row['ingredients'];
      final items = nested is List ? nested : [nested];

      for (final item in items) {
        if (item is! Map) continue;
        final display = (item['display_name'] as String?)?.trim();
        final normalized = (item['normalized_name'] as String?)?.trim();
        final name = (display != null && display.isNotEmpty)
            ? display
            : (normalized ?? '');
        if (name.isEmpty) continue;
        if (!seen.add(name.toLowerCase())) continue;

        result.add(CatalogIngredient(
          name: name,
          needsReview: item['needs_review'] == true,
        ));
      }
    }
    return result;
  }

  /// Ağ/yetki hatalarını kullanıcıya gösterilebilir Türkçe metne çevirir.
  /// Hiçbiri "ürün bulunamadı" anlamına gelmez — sorgu yapılamamıştır.
  @visibleForTesting
  static String mapCatalogError(Object error) {
    final lower = error.toString().toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('connection refused') ||
        lower.contains('timeout')) {
      return 'Sunucuya bağlanılamadı; katalog kontrolü tamamlanamadı. '
          'İnternet bağlantınızı kontrol ediniz.';
    }
    if (lower.contains('jwt') ||
        lower.contains('unauthorized') ||
        lower.contains('permission denied') ||
        lower.contains('row-level security')) {
      return 'Katalog sorgusu için oturum gerekiyor; kontrol tamamlanamadı.';
    }
    return 'Katalog sorgulanamadı; kontrol tamamlanamadı.';
  }
}
