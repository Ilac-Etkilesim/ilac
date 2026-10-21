# İlaç Kullanım ve Yakınlık Takip Sistemi
## Sprint 0 — Flutter teknik prototipi (DEMO, klinik ürün değil)

**Önemli:** Bu paket çalışan ürün olduğunu iddia etmez. Ekranlarda örnek ilaçlar kullanılır; doz onayı bellekte tutulur.
Kamera gerçek GS1 DataMatrix okuma denemesini yapar, ancak **ilaç tanımlama ve tıbbi etkileşim analizi bağlı değildir**.
Yerel bildirim yalnızca kullanıcı butona bastığında bir **test bildirimi** olarak gösterilir.
Hasta-yakın bağlantısı ve FCM gönderimi henüz yoktur.

### Mevcut GitHub deposuna ekleme
Klonlanmış `Ilac-Etkilesim/ilac` deposuna **yalnızca ZIP içindeki `ilac_yakinlik_sprint0` klasörünün İÇERİĞİNİ** ekleyin. `.git/` klasörünü silmeyin veya değiştirmeyin. Çakışmaları kontrol edin. Detaylar: `docs/07_MEVCUT_GITHUB_DEPOSUNA_KURULUM.md`. Claude Code çalışma kuralları: `CLAUDE.md`.

### Gerekenler
- Flutter **3.38.1+** ve bununla uyumlu Dart SDK
- Android Studio/Android SDK ve USB hata ayıklaması açık bir Android telefon
- Python 3 (yalnızca native proje oluşturma yardımcı betiği için)
- Git (önerilir)

### Kurulum
1. ZIP'i çıkar ve terminalde proje klasörüne gir.
2. `flutter doctor -v` komutuyla ortamı denetle.
3. `python tools/bootstrap_native.py` komutunu **bir kez** çalıştır. (Varsa `python3` kullan.)
4. `flutter pub get`
5. `flutter analyze`
6. `flutter test`
7. `flutter devices` ile telefonu gör, ardından `flutter run`.

Bu çalışma ortamında Flutter SDK bulunmadığı için proje tarafımızdan `flutter run` ile derlenememiştir.
Paket sürümleri resmi pub.dev kaynaklarına göre seçilmiştir; ekip makinesinde test edilmelidir.

### Opsiyonel Supabase ayarı
Önce Supabase'te **geliştirme projesi** oluşturun. `supabase/migrations/...sql` yalnızca inceleme sonrası uygulanmalıdır.
Auth ve canlı veritabanı arayüzleri henüz bağlı değildir.

İlk bağlantı kontrolü için (publishable key):
```
flutter run --dart-define=SUPABASE_URL=https://YOURPROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```
`service_role` veya başka bir gizli sunucu anahtarını **asla** `--dart-define` ile mobil uygulamaya koymayın.
Ekipte gerçek kullanıcı tıbbi bilgilerini demo projesine girmeyin.

### Sprint 0 modülleri
| Parça | Durum |
|---|---|
| Flutter ekran iskeleti | Kod hazır; cihazda doğrulama bekliyor |
| İlaç kartları / doz onayı | Bellek içi DEMO |
| GS1 DataMatrix okuma | Kamera kodu yazıldı; fiziksel cihaz testi bekliyor |
| GTIN ayrıştırma | İlk basit ayrıştırıcı + birim testleri |
| Android test bildirimi | Anlık bildirim kodu; izin/test bekliyor |
| Supabase şeması/RLS | SQL taslağı, uygulanmadı |
| Supabase Auth | Sonraki sprint |
| Yakın bağlantısı/FCM | Sonraki sprint |
| Gerçek ilaç verileri ve klinik risk değerlendirmesi | Henüz yok |

### Dosyalar
- `lib/`: Flutter prototipi
- `test/`: Dart/Flutter testleri
- `supabase/migrations/`: taslak veritabanı/erişim kuralları
- `data/`: **yalnızca kurgusal** test verisi
- `docs/`: mimari, ekip, Sprint 0 ve kalite süreci
- `.github/`: Issue/PR şablonları

### İlk hafta kabul kapısı
Aynı telefon üzerinde uygulama açılması, DataMatrix GTIN okunması ve anlık deneme bildirimi görülmesi
+ Supabase Auth/RLS taslağının teknik incelemesi. Başarısızlıklar raporlanır; gerçekmiş gibi gösterilmez.

### Kaynaklar
- https://docs.flutter.dev/
- https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- https://pub.dev/packages/mobile_scanner
- https://pub.dev/packages/flutter_local_notifications
