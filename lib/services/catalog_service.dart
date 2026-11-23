import '../core/gs1_parser.dart';

/// Katalogda yer alan ürün bilgisi.
/// Sprint 0 / Sprint 3 demo veri modeli.
class CatalogProduct {
  const CatalogProduct({
    required this.gtin,
    required this.name,
    required this.activeIngredients,
    this.isDemo = true,
    this.description,
  });

  final String gtin;
  final String name;
  final List<String> activeIngredients;
  final bool isDemo;
  final String? description;

  String get ingredientsSummary => activeIngredients.join(', ');
}

/// Karekod / Barkod sorgulama sonuç durumu.
enum CatalogResultStatus {
  /// Ürün katalogda bulundu.
  found,

  /// GTIN ayrıştırıldı ancak katalogda kayıtlı değil.
  notFound,

  /// Karekod okunamadı, format tanınmadı veya teknik sorgu gerçekleştirilemedi.
  queryFailed,
}

/// Barkod sorgulama neticesinde dönen veri paketi.
class CatalogLookupResult {
  const CatalogLookupResult._({
    required this.status,
    this.product,
    this.gtin,
    this.rawCode,
    this.message,
  });

  factory CatalogLookupResult.found(CatalogProduct product, {String? rawCode}) {
    return CatalogLookupResult._(
      status: CatalogResultStatus.found,
      product: product,
      gtin: product.gtin,
      rawCode: rawCode,
    );
  }

  factory CatalogLookupResult.notFound({required String gtin, String? rawCode}) {
    return CatalogLookupResult._(
      status: CatalogResultStatus.notFound,
      gtin: gtin,
      rawCode: rawCode,
      message: 'Katalogda bulunamadı. Bu barkod numarası kayıtlarımızda yer almıyor.',
    );
  }

  factory CatalogLookupResult.queryFailed({String? message, String? rawCode}) {
    return CatalogLookupResult._(
      status: CatalogResultStatus.queryFailed,
      rawCode: rawCode,
      message: message ?? 'Barkod bilgisi sorgulanamadı. Karekod okunamadı veya sunucuya erişilemedi.',
    );
  }

  final CatalogResultStatus status;
  final CatalogProduct? product;
  final String? gtin;
  final String? rawCode;
  final String? message;

  bool get isFound => status == CatalogResultStatus.found;
  bool get isNotFound => status == CatalogResultStatus.notFound;
  bool get isQueryFailed => status == CatalogResultStatus.queryFailed;
}

/// #S3-03 Katalog Servisi (Yerel Demo / Mock & İleride Supabase Entegrasyonu).
class CatalogService {
  const CatalogService({Map<String, CatalogProduct>? initialCatalog})
      : _customCatalog = initialCatalog;

  final Map<String, CatalogProduct>? _customCatalog;

  /// Kurgusal demo ürün kataloğu (data/demo_products.csv ile uyumlu).
  static const Map<String, CatalogProduct> defaultDemoCatalog = {
    '99990000000008': CatalogProduct(
      gtin: '99990000000008',
      name: 'Örnek Ürün A',
      activeIngredients: ['DEMO_ETKEN_A', 'Asetilsalisilik Asit 100 mg'],
      isDemo: true,
    ),
    '99990000000015': CatalogProduct(
      gtin: '99990000000015',
      name: 'Örnek Ürün B',
      activeIngredients: ['DEMO_ETKEN_B', 'Metformin Hidroklorür 1000 mg'],
      isDemo: true,
    ),
    '99990000000022': CatalogProduct(
      gtin: '99990000000022',
      name: 'Örnek Ürün C',
      activeIngredients: ['DEMO_ETKEN_C', 'Amlodipin 5 mg'],
      isDemo: true,
    ),
    '99990000000039': CatalogProduct(
      gtin: '99990000000039',
      name: 'Örnek Ürün D',
      activeIngredients: ['DEMO_ETKEN_D', 'Atorvastatin 20 mg'],
      isDemo: true,
    ),
    '99990000000046': CatalogProduct(
      gtin: '99990000000046',
      name: 'Örnek Ürün E',
      activeIngredients: ['DEMO_ETKEN_E', 'Omeprazol 20 mg'],
      isDemo: true,
    ),
    '99990000000053': CatalogProduct(
      gtin: '99990000000053',
      name: 'Örnek Ürün F',
      activeIngredients: ['DEMO_ETKEN_F', 'Parasetamol 500 mg'],
      isDemo: true,
    ),
    // Testlerde ve denemelerde sıkça kullanılan GS1 örnek GTIN'i
    '01234567890128': CatalogProduct(
      gtin: '01234567890128',
      name: 'Örnek İlaç A',
      activeIngredients: ['Parasetamol 500 mg'],
      isDemo: true,
    ),
  };

  Map<String, CatalogProduct> get _catalog => _customCatalog ?? defaultDemoCatalog;

  /// Kameradan veya okuyucudan gelen ham karekod dizgisini işler ve ürünü arar.
  Future<CatalogLookupResult> lookup(String? rawCode) async {
    if (rawCode == null || rawCode.trim().isEmpty) {
      return CatalogLookupResult.queryFailed(
        rawCode: rawCode,
        message: 'Karekod bilgisi okunamadı. Lütfen kamerayı karekoda yaklaştırıp yeniden deneyin.',
      );
    }

    final gtin = extractGtin(rawCode);
    if (gtin == null) {
      return CatalogLookupResult.queryFailed(
        rawCode: rawCode,
        message: 'Karekoddan standart barkod numarası (GTIN) ayrıştırılamadı. Kod bozuk veya tanınmayan formatta olabilir.',
      );
    }

    return lookupByGtin(gtin, rawCode: rawCode);
  }

  /// Doğrudan 14 haneli GTIN ile katalog araması yapar.
  Future<CatalogLookupResult> lookupByGtin(String gtin, {String? rawCode}) async {
    final product = _catalog[gtin];
    if (product != null) {
      return CatalogLookupResult.found(product, rawCode: rawCode);
    }
    return CatalogLookupResult.notFound(gtin: gtin, rawCode: rawCode);
  }
}
