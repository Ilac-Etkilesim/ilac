import 'package:flutter/material.dart';
import '../services/catalog_service.dart';

const kNavy = Color(0xFF19345E);
const kBlue = Color(0xFF2469CE);
const kWarningAmber = Color(0xFFB45309);
const kWarningBg = Color(0xFFFEF3C7);
const kDangerRed = Color(0xFFB91C1C);
const kDangerBg = Color(0xFFFEE2E2);
const kInfoBlue = Color(0xFF1D4ED8);
const kInfoBg = Color(0xFFDBEAFE);

/// Karekod okuma sonucunu gösteren yaşlı dostu alt sayfa (Bottom Sheet).
class ScanResultSheet extends StatelessWidget {
  const ScanResultSheet({
    super.key,
    required this.result,
    this.onRetry,
  });

  final CatalogResult result;
  final VoidCallback? onRetry;

  /// Alt sayfayı modal olarak açan yardımcı fonksiyon.
  static Future<void> show(
    BuildContext context, {
    required CatalogResult result,
    VoidCallback? onRetry,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ScanResultSheet(
        result: result,
        onRetry: onRetry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst tutamaç çubuğu
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Duruma göre içerik (Dört durum: bulundu, degerlendirilmedi, katalogdaYok, sorgulanamadi)
              switch (result.status) {
                CatalogStatus.bulundu => _buildFoundContent(context),
                CatalogStatus.degerlendirilmedi => _buildNotEvaluatedContent(context),
                CatalogStatus.katalogdaYok => _buildNotFoundContent(context),
                CatalogStatus.sorgulanamadi => _buildQueryFailedContent(context),
              },

              const SizedBox(height: 20),

              // Kapat / Tamam Butonu (Minimum 52 px dokunma alanı - yaşlı dostu)
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  key: const Key('scan_result_close_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Kapat',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              // Yeniden dene butonu (yalnızca sorgu başarısızsa ve callback varsa)
              if (result.status == CatalogStatus.sorgulanamadi && onRetry != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    key: const Key('scan_result_retry_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kNavy,
                      side: const BorderSide(color: kBlue, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRetry!();
                    },
                    child: const Text(
                      'Yeniden Dene',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Ürün katalogda bulundu ekranı
  Widget _buildFoundContent(BuildContext context) {
    final productName = result.productName ?? 'Kayıtlı Ürün';
    final ingredientsText = result.ingredients.isNotEmpty
        ? result.ingredients.map((i) => i.name).join(', ')
        : 'Belirtilmedi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Demo etiketi
        if (result.isDemo)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade300),
              ),
              child: const Text(
                'DEMO VERİSİ · TEMSİLİ KAYIT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ),

        // Ürün Adı (Büyük ve okunaklı)
        Text(
          productName,
          key: const Key('scan_result_product_name'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: kNavy,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        // Etken Madde Kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD6E4F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.biotech, color: kBlue, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Etken Madde(ler)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ingredientsText,
                key: const Key('scan_result_ingredients'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (result.needsReview) ...[
                const SizedBox(height: 6),
                Text(
                  'Etken madde bilgisi inceleme bekliyor.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
              if (result.gtin.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Barkod (GTIN): ${result.gtin}',
                  key: const Key('scan_result_gtin'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tıbbi Sınır Uyarısı
        _buildMedicalNoticeBox(
          title: 'Tıbbi Bilgilendirme',
          message:
              'Ürün adının görüntülenmesi ilacın durumunu veya kişisel tedavi sürecinizi değerlendirmez. '
              'İlaç etkileşim kontrolü bu sürümde henüz bağlı değildir. '
              'İlaç alımı öncesinde hekiminize veya eczacınıza danışınız.',
          backgroundColor: kInfoBg,
          borderColor: kInfoBlue,
          textColor: const Color(0xFF1E3A8A),
          icon: Icons.info_outline,
        ),
      ],
    );
  }

  /// 2. Değerlendirilmedi ekranı (Ürün var ama etken madde kayıtlı değil)
  Widget _buildNotEvaluatedContent(BuildContext context) {
    final productName = result.productName ?? 'Kayıtlı Ürün';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Demo etiketi
        if (result.isDemo)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade300),
              ),
              child: const Text(
                'DEMO VERİSİ · TEMSİLİ KAYIT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ),

        // Ürün Adı
        Text(
          productName,
          key: const Key('scan_result_product_name'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: kNavy,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        // Durum kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.help_outline, color: kWarningAmber, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Etken Madde Kaydı Yok',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.reason ??
                    'Ürünün etken madde bilgisi katalogda yer almadığından inceleme tamamlanamadı.',
                key: const Key('scan_result_not_evaluated_reason'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
              if (result.gtin.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Barkod (GTIN): ${result.gtin}',
                  key: const Key('scan_result_gtin'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF78350F),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tıbbi Sınır Uyarısı
        _buildMedicalNoticeBox(
          title: 'Tıbbi Bilgilendirme',
          message:
              'Etken madde bilgisi bulunmayan ürünlerde etkileşim değerlendirmesi yapılamaz. '
              'İlacınız hakkında bilgi almak için hekim veya eczacınıza danışınız.',
          backgroundColor: kWarningBg,
          borderColor: kWarningAmber,
          textColor: const Color(0xFF78350F),
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  /// 3. Katalogda bulunamadı ekranı
  Widget _buildNotFoundContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Durum ikonu ve başlık
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kWarningBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.search_off, color: kWarningAmber, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Katalogda Bulunamadı',
                key: Key('scan_result_not_found_title'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Açıklama kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Okunan barkod numarası katalog kayıtlarında yer almıyor.',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
              if (result.gtin.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Barkod (GTIN): ${result.gtin}',
                  key: const Key('scan_result_not_found_gtin'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF78350F),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tıbbi Sınır Uyarısı
        _buildMedicalNoticeBox(
          title: 'Tıbbi Bilgilendirme',
          message:
              'Katalogda yer almayan ürünler için etken madde listelenemez ve etkileşim kontrolü yapılamaz. '
              'İlacınız hakkında bilgi almak için hekiminize veya eczacınıza başvurunuz.',
          backgroundColor: kWarningBg,
          borderColor: kWarningAmber,
          textColor: const Color(0xFF78350F),
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  /// 4. Doğrulanamadı / Sorgulanamadı ekranı
  Widget _buildQueryFailedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Durum ikonu ve başlık
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kDangerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.error_outline, color: kDangerRed, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Sorgulanamadı',
                key: Key('scan_result_query_failed_title'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Açıklama kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Text(
            result.reason ??
                'Karekod bilgisi okunamadı veya sunucuya erişilemedi. Lütfen barkodun net göründüğünden emin olun.',
            key: const Key('scan_result_failed_message'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF991B1B),
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bilgilendirme kutusu
        _buildMedicalNoticeBox(
          title: 'Bilgilendirme',
          message:
              'Karekod standartlara uymadığında veya kamera netleyemediğinde barkod sorgulanamaz. '
              'Karekod alanının aydınlık ve net olduğundan emin olup yeniden deneyebilirsiniz.',
          backgroundColor: Colors.grey.shade100,
          borderColor: Colors.grey.shade400,
          textColor: Colors.grey.shade800,
          icon: Icons.help_outline,
        ),
      ],
    );
  }

  /// Ortak Tıbbi / Bilgilendirme Kutusu
  Widget _buildMedicalNoticeBox({
    required String title,
    required String message,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
