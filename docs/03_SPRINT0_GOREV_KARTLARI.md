# Sprint 0 (Bu hafta lider: Melike)

Her teknik kişi toplantı dışında **en fazla 2,5 saat** çalışır. Bir görev bitmiyorsa parçalanır.
Çıktılar PR, ekran görüntüsü/video veya belgelendirilmiş deneme kaydıyla kanıtlanır.

| Sahip | Issue | 2,5 saatte beklenen somut çıktı |
|---|---|---|
| Eray | #S0-01 Repo ve PR iş akışı | repo erişimi, `main`+`dev`, PR şablonu ve örnek PR |
| Metehan | #S0-02 Supabase Auth/RLS gözden geçirme | şema/RLS inceleme notu + iki kullanıcı için test planı |
| Gizem | #S0-03 DataMatrix fiziksel cihaz testi | bir gerçek ilaç kutusundan GTIN okuma denemesi, sonuç/engel kaydı |
| Ali | #S0-04 Test verisi ve kaynak incelemesi | 6+ kurgusal kayıt; kaynak/lisans/GTIN eşleşme risk notu |
| Afra | #S0-05 Flutter UI açılışı | `flutter run` + ilaç kartları ekran görüntüsü; dokunma alanı kontrolü |
| Ahmet | #S0-06 Yetki ve test senaryoları | hasta/yakın erişimi, izin iptali, başarısız tarama ve doz onayı senaryoları |
| Merve | #S0-07 Yerel bildirim denemesi | Android'de demo bildirimi ve izin ekranı kanıtı |
| Melike | Sprint 0 liderliği | 7 Issue takibi, inceleme/merge koordinasyonu, teknoloji kararı + haftalık rapor |

## Kabul kapısı
- Flutter kurulu ve `flutter doctor`, `flutter analyze`, `flutter test` çıktıları incelendi.
- Gerçek Android cihazda ana ekran çalışıyor.
- DataMatrix okuma denemesi yapıldı, sonucu kayıtlı.
- Yerel bildirim cihazda denendi.
- SQL/RLS taslağı review gördü; canlıya uygulanması için ayrıca karar alındı.
- PR ve Issue akışı ekipçe kullanıldı.
- Hiçbir demo verisi gerçek tıbbi öneri olarak sunulmadı.

## Engeller
Cihaz/kamera izin problemi => Issue içinde telefon modeli + Android sürümü + hata çıktısı.
Supabase proje/anahtar yok => UI mock modda devam eder.
Derleme hatası => tam çıktıyı PR açıklamasına ekleyin; gizli anahtarları paylaşmayın.
