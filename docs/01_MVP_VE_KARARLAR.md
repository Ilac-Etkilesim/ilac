# MVP ve teknik karar kaydı (2026-10-21)

## Ekip tarafından belirlenenler
- 8 üye; kişi başına haftada toplam 3 saat, 30 dakika ortak toplantı dahil.
- Yaklaşık 9–12 hafta; o hafta lider olan kişi kodlamadan muaf.
- Öncelikli teknoloji adayı Flutter, **1 hafta denemeden sonra onaylanacak**.
- Backend adayı: Supabase/PostgreSQL; veri hazırlama: Python/pandas.
- İlk cihaz: fiziksel Android telefon mevcut.
- Gerçek ilaç verileri henüz temin edilmedi; klinik veri kaynağı kararı açık.
- MVP: giriş/güvenlik, DataMatrix tarama, etkileşim sorgusu, ilaç takvimi/doz onayı,
  yerel hatırlatma, basit hasta-yakın bağlantısı, kritik bildirimi.
- Yakına bildirim yalnızca ciddi etkileşim veya geciken doz için.
- Geciken doz eşiği: **90 dakika önerisi**, henüz ekip onayı gerektirir.

## Öncelik dışı
- RAG, sesli asistan, premium/abonelik, gelişmiş rapor, otomatik tıbbi tavsiye, tam iOS sürümü.

## Çözülmemiş teknik kararlar
- Flutter denemesinin sonucu (kamera + bildirim + temel uygulama).
- Supabase proje sahibi, güvenli şifre ve anahtar yönetimi.
- Gerçek ilaç ve etkileşim kaynağı için erişim/lisans, doğrulama.
- Yakın bağlantısının iki taraflı onay/geri alma tasarımı.
- Doz gecikmesinde zamana duyarlı sunucu görevinin sıklığı.
- KVKK bakımından hukuki dayanak, saklama süresi, aktarım ve gerçek kullanıcı pilot koşulları.

## Temel ürün güvenliği
- Bilinen kayıt olmaması => "GÜVENLİ" değil, "kontrol tamamlanamadı / değerlendirilmedi".
- Doz onayının bulunmaması => "ilaç kesin alınmadı" değil, "alım henüz onaylanmadı".
- Kod/GTIN tanıma => tek başına ilacın etken maddesini veya klinik uygunluğunu doğrulamaz.
