# Mobil giriş ekranı — ekran görüntüleri (PR #27 kanıtı)

PR #27'de (Afra, giriş ekranı) "Test kanıtı" bölümündeki `[ ] Görsel/video/log eklendi`
kutusu işaretsiz kalmıştı. Bu dosya o eksiği kapatıyor: aşağıdaki 9 ekran görüntüsü,
Android emülatöründe (API 35), gerçek `dev` koduyla, gerçek dokunuşlarla alındı.

**Dürüstlük notu:** Bu set, Supabase'in henüz gerçek bir publishable key ile
yapılandırılmadığı bir derlemeden alındı (sahte/erişilemez bir proje URL'i ile
derlendi) — bu yüzden #3'teki hata mesajı gerçek bir ağ hatasıdır, kurgu değil.
Gerçek bir hesapla uçtan uca başarılı giriş (`HomeShell(isDemoMode: false)`,
e-posta rozeti) henüz gösterilemedi; bunun için Metehan'ın dev projesinin
publishable key'i bekleniyor (bkz. Issue #5 yorumu, 2026-11-13). O anahtar
gelince bu klasöre 2-3 ekran daha eklenip bu dosya güncellenecek.

## Görseller

| # | Dosya | Ne gösteriyor |
|---|---|---|
| 1 | [01_giris_ekrani.png](ekran_goruntuleri/sprint2_mobil_giris/01_giris_ekrani.png) | Yeni `LoginPage` — demo uyarısı, e-posta/şifre alanları |
| 2 | [02_form_validasyon.png](ekran_goruntuleri/sprint2_mobil_giris/02_form_validasyon.png) | Boş form gönderilince Türkçe validasyon hataları |
| 3 | [03_giris_hata_mesaji.png](ekran_goruntuleri/sprint2_mobil_giris/03_giris_hata_mesaji.png) | Gerçek ağ hatası → `AuthService.mapAuthError` ile Türkçe mesaj ("Sunucuya bağlanılamadı") |
| 4 | [04_demo_modu_cikis_butonu.png](ekran_goruntuleri/sprint2_mobil_giris/04_demo_modu_cikis_butonu.png) | "Giriş yapmadan demo olarak devam et" sonrası `HomeShell`, AppBar'da yeni çıkış ikonu |
| 5 | [05_cikis_onay_dialogu.png](ekran_goruntuleri/sprint2_mobil_giris/05_cikis_onay_dialogu.png) | Çıkış ikonuna basınca çıkan onay diyaloğu |
| 6 | [06_doz_onayi_1_4.png](ekran_goruntuleri/sprint2_mobil_giris/06_doz_onayi_1_4.png) | "İçtim" sonrası doz sayacının 0/4 → 1/4 canlı güncellenmesi |
| 7 | [07_elle_giris_dialogu.png](ekran_goruntuleri/sprint2_mobil_giris/07_elle_giris_dialogu.png) | Karekod okunamazsa elle 14 haneli GTIN girişi diyaloğu |
| 8 | [08_kamera_canli_onizleme.png](ekran_goruntuleri/sprint2_mobil_giris/08_kamera_canli_onizleme.png) | Kamera izni verilince gerçek canlı önizleme (emülatör test deseni) |
| 9 | [09_yakinim_ekrani.png](ekran_goruntuleri/sprint2_mobil_giris/09_yakinim_ekrani.png) | "Yakınım" sekmesi — "temsili ekran, gerçek bağlantı sonraki sprintlerde" notu |

## Nasıl alındı
`flutter run -d emulator-5554 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
ile Pixel 6 / API 35 emülatöründe, `adb shell input tap/text` ile gerçek dokunuşlar
simüle edilerek `adb shell screencap` ile alındı. Koordinatlar `uiautomator dump`
ile widget sınırlarından doğrulandı.
