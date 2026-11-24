# İlaç Kullanım ve Yakınlık Takip Sistemi — Claude Code Çalışma Kuralları

## Durum
- Sprint 0 Flutter DEMO prototipidir; çalışan klinik ürün değildir.
- Mobil arayüz ve doz onayı demo verileri kullanır; gerçek Auth/ilaç etkileşim kontrolü/FCM henüz bağlı değildir.
- GS1 DataMatrix/GTIN yalnızca teknik deneme olarak okunur.
- Supabase SQL dosyası TASLAKTIR ve otomatik olarak uygulanmamalıdır.

## Çalışma biçimi
1. Önce görev kapsamını ve ilgili dosyaları özetle. Gerekmedikçe başka modülleri değiştirme.
2. Kullanıcının onayı olmadan toplu refactor, sürüm yükseltme, mimari değişiklik, depoya push veya PR merge yapma.
3. Her görevi küçük, gözden geçirilebilir değişikliklere ayır; yapılan değişiklikleri ve test sonucunu raporla.
4. Görev bittiğinde mümkünse `flutter analyze` ve `flutter test` çalıştır; bunlar çalışmazsa nedeni açıkça yaz.
5. Her özellik için hata/izin/boş veri durumlarını ele al; Türkçe, büyük ve erişilebilir arayüzü koru.
6. Ekip akışı: feature dalı -> PR -> teknik inceleme -> liderin süreç onayı -> dev; kararlı sürüm -> main.

## Güvenlik ve tıbbi sınırlar
- Gerçek hasta verisi, erişim anahtarı, service_role, FCM sunucu kimlik bilgisi veya gizli `.env` değerlerini Git'e ekleme.
- Supabase migration, uzaktaki veriyi değiştirme, erişim yetkisi genişletme ve dış sisteme bildirim gönderme öncesinde açık onay iste.
- Kural tabanlı etkileşim sonucu bile verinin eksiksizliğini veya %100 doğruluğu garanti etmez.
- 'Kesin güvenli' ifadeleri kullanma. 'Bilinen etkileşim saptanmadı' ile 'kontrol tamamlanamadı' durumlarını ayır.
- Demo verilerini her zaman DEMO/temsili olarak etiketle; gerçek tedavi önerisi verme.
- Kullanıcı 'İçtim' dememişse 'alınmadı' değil 'alımı onaylanmadı' ifadesini kullan.

## İlk isteğe önerilen yanıt
Mevcut dosyaları incele; uygulamayı çalıştırmak için ön koşulları belirle, ardından kullanıcı izniyle yalnızca derleme/test engellerini düzelt.
