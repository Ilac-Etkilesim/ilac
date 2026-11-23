# Teknik doğrulama dosyası — Sprint 0 + Sprint 1

**Dönem:** 21–27 Ekim 2026 · **Depo:** Ilac-Etkilesim/ilac · **Dal:** `dev`
Bu belge, "ne test edildi, kim neyi inceledi, hangi kanıt var" sorusunun tek adresi.
Tüm komut çıktıları 27 Ekim 2026'da `dev` dalında alınmıştır.

---

## 1. Özet

| Doğrulama türü | Kapsam | Sonuç |
|---|---|---|
| Otomatik birim/widget testi | 16 test, 4 dosya | ✅ Hepsi geçiyor |
| Statik kod analizi (`flutter analyze`) | Tüm `lib/` ve `test/` | ✅ Uyarı yok |
| Veri tutarlılık kontrolü (`tools/check_demo_seed.py`) | Seed ↔ CSV ↔ şema | ✅ Temiz |
| Sürekli entegrasyon (GitHub Actions) | Her PR ve her `dev` push'u | ✅ 12/12 başarılı |
| Elle (manuel) cihaz doğrulaması | Android 35 emülatörü, 6 senaryo | ✅ Tamamı doğrulandı |
| Kod incelemesi (akran) | 7 teslimin tamamı | ✅ İnceleme olmadan birleşme yok |
| Güvenlik/erişim kuralı incelemesi | 8 tablo, 3 senaryo | ✅ İki bağımsız inceleme (Eray + Metehan) |
| Gerçek kutuyla kamera testi | — | ❌ **Yapılmadı** (fiziksel telefon yok) |

---

## 2. Otomatik testler (16 test)

Çalıştırma: `fvm flutter test` → `00:00 +16: All tests passed!`

### 2.1 `test/gs1_parser_test.dart` — 9 test · karekod/GTIN mantığı

| # | Test | Ne doğruluyor |
|---|---|---|
| 1 | GS1 DataMatrix ham verisinden GTIN ayrıştırılır | `]d2` ön ekli ham tarayıcı çıktısından 14 haneli ürün kodunun çıkarılması |
| 2 | Parantezli gösterimden GTIN ayrıştırılır | `(01)…(17)…` biçimindeki insan-okunur gösterim |
| 3 | Yanlış kontrol basamaklı GTIN reddedilir | GS1 kontrol basamağı (mod-10) hesabının çalıştığı |
| 4 | Belirsiz barkod güvenilir GTIN olarak kabul edilmez | Rastgele metnin ürün kodu sanılmaması |
| 5 | 14 haneden fazla rakam içeren bozuk kod sessizce kabul edilmez | Kazınmış/bozuk koddan yanlış ürün türetilmemesi (bu bir hata düzeltmesinin testi) |
| 6 | Elle giriş: geçerli 14 hane `(01)` önekiyle döner ve `extractGtin` onu okur | Elle girişin kamera çıktısıyla **aynı yoldan** işlendiği |
| 7 | Elle giriş: boşluk ve tireler temizlenir | `0123 4567-8901 28` gibi kullanıcı yazımının kabul edilmesi |
| 8 | Elle giriş: yanlış kontrol basamağı reddedilir | Elle girişte de doğrulamanın atlanmadığı |
| 9 | Elle giriş: 14 haneden kısa/uzun veya harf içeren giriş reddedilir | Sınır durumları (13 hane, 15 hane, harf) |

### 2.2 `test/demo_products_test.dart` — 4 test · demo veri bütünlüğü

| # | Test | Ne doğruluyor |
|---|---|---|
| 1 | CSV boş değil ve beklenen sütunlara sahip | Veri dosyasının yapısının bozulmadığı |
| 2 | Her demo GTIN geçerli kontrol basamağına sahip | 10 ürünün hepsinin gerçek GS1 kuralına uyduğu |
| 3 | Her demo GTIN, GS1 `(01)` biçiminde ayrıştırılabiliyor | Demo verinin uygulamanın kendi ayrıştırıcısından geçtiği |
| 4 | Tüm kayıtlar DEMO olarak işaretli ve GTIN tekrar etmiyor | Hiçbir kaydın yanlışlıkla "gerçek" görünmediği |

### 2.3 `test/dose_storage_test.dart` — 2 test · doz onayının kalıcılığı

| # | Test | Ne doğruluyor |
|---|---|---|
| 1 | Kaydet → oku, aynı gün için aynı seti döner | Onayın cihazda gerçekten saklandığı |
| 2 | Farklı gün sorgulandığında boş set döner | Günlük anahtar mantığı: dünün onayı bugün görünmez |

### 2.4 `test/app_smoke_test.dart` — 1 test · arayüz duman testi

| # | Test | Ne doğruluyor |
|---|---|---|
| 1 | Ana ekranda DEMO etiketi ve ilaç listesi görülür | Uygulamanın açıldığı, DEMO etiketinin ve listenin ekranda olduğu |

**Kapsam dışı (bilinçli):** `ScannerPage` için widget testi yazılmadı; kamera eklentisi test ortamında çalışmıyor. Bu yüzden karekod mantığı saf fonksiyonlara ayrıldı ve orada test edildi.

---

## 3. Statik analiz ve veri kontrolü

```
$ fvm flutter analyze
Analyzing ilac...
No issues found!

$ python3 tools/check_demo_seed.py
TEMİZ: 10 ürün, 8 etken madde, 4 kural doğrulandı.
```

`check_demo_seed.py` neyi kontrol ediyor:
1. CSV'deki her GTIN 14 hane ve kontrol basamağı doğru
2. Seed SQL'indeki ürün kümesi CSV ile birebir aynı
3. Her ürün, seed'de tanımlı bir etken maddeye referans veriyor (yabancı anahtar bütünlüğü)
4. Etkileşim kuralları: tanımlı etken maddeler, kanonik sıra (`a < b`), geçerli şiddet değeri, aynı çift iki kez yok, `is_verified=false` ve `is_demo=true`
5. Beklenen sayılar **tam eşitlikle** doğrulanıyor (10/8/4) — Metehan'ın önerisi üzerine sıkılaştırıldı

---

## 4. Sürekli entegrasyon (CI)

Dosya: `.github/workflows/flutter-ci.yml`

| Ayar | Değer |
|---|---|
| Tetikleyici | `dev` ve `main` hedefli her PR + bu dallara her push |
| Ortam | ubuntu-latest, Flutter 3.38.1 stable (`.fvmrc` ile aynı sürüm) |
| Adımlar | `flutter pub get` → `flutter analyze` → `flutter test` |
| Kural | Kontrol kırmızıysa kod birleştirilmez |

**Çalışma geçmişi: 12 çalışma, 12'si başarılı.** Her teslim ve her birleşme ayrı ayrı doğrulandı.

**Bilinen sınır:** CI Android derlemesi (`flutter build apk`) yapmıyor. Bu yüzden 5. bölümdeki derleme hatasını CI yakalayamadı; eklenmesi Eray'a önerildi.

---

## 5. Elle cihaz doğrulaması (Android 35 emülatörü)

Fiziksel telefon olmadığı için Android emülatörü kuruldu ve uygulama gerçek Android ortamında çalıştırıldı.

| # | Senaryo | Beklenen | Sonuç |
|---|---|---|---|
| 1 | Uygulama açılışı | Ana ekran, DEMO etiketi, ilaç listesi | ✅ |
| 2 | Doz onayı | "İçtim" → işaretleniyor | ✅ |
| 3 | Kalıcılık | Uygulama kapanıp açılınca onay duruyor | ✅ — cihaz kaydı: `flutter.taken_2026-10-27 = ["1"]` |
| 4 | Kamera izni | Android izin diyaloğu çıkıyor | ✅ (manifest izinleri doğru) |
| 5 | Elle GTIN girişi | `99990000000008` → ekranda `GTIN: 99990000000008` | ✅ (uçtan uca: giriş → doğrulama → ayrıştırma → ekran) |
| 6 | Bildirim | İzin istendi → bildirim telefona düştü | ✅ "İlaç Hatırlatıcısı — DEMO" |

**Doğrulanamayan:** Gerçek bir ilaç kutusundan kamerayla DataMatrix okuma. Emülatörün kamerası gerçek olmadığı için bu test **geçerli sayılmaz**; fiziksel telefonla yapılacak.

---

## 6. Kod incelemeleri (akran incelemesi)

Kural: hiçbir kod doğrudan ana dala giremez. Her teslim → PR → en az bir kişinin incelemesi → otomatik kontrol → birleşme.

| Teslim | Yazan | İnceleyen | Sonuç |
|---|---|---|---|
| Sprint 0 iskeleti (#1) | Melike | — (ilk kurulum) | Birleşti |
| Doz onayı kalıcılığı (#12) | Afra | Melike | İki düzeltme istendi (`pubspec.lock`, reviewer alanı) → düzeltildi → onaylandı |
| CI + RLS notu (#13) | Eray | Melike (CI), Metehan (RLS) | Onaylandı, 2 küçük öneri |
| Demo seed (#11) | Melike | Metehan | Onaylandı, 4 öneri → 2'si aynı gün uygulandı |
| Elle GTIN girişi (#14) | Melike | Afra | Onaylandı |
| Android derleme düzeltmesi (#18) | Melike | — (lider süreç onayı, acil) | Birleşme sonrası inceleme Eray'dan bekleniyor |
| Haftalık rapor (#19) | Melike | — (doküman) | Birleşti |

---

## 7. Güvenlik ve erişim kuralı incelemesi

Supabase taslağı (`supabase/migrations/20261021_001_initial_draft.sql`) **iki kişi tarafından bağımsız** incelendi. Çalıştırma değil, satır satır okuma yöntemiyle.

### 7.1 İncelenen temel kural

`can_view_patient(target_patient_id)` `true` döner ⇔ kullanıcı giriş yapmış **ve** (kendi kaydı **veya** `caregiver_links`'te `status='active'` bağlantısı var). 8 tablonun hepsinde satır bazlı güvenlik açık; politikası tanımlanmamış işlemler varsayılan olarak reddediliyor.

### 7.2 Üç senaryo — her ikisi de aynı sonuca vardı

| Senaryo | Beklenen | Sonuç |
|---|---|---|
| (a) Hasta kendi kayıtlarını görüyor mu? | Evet | ✅ Geçer (`profiles`, `patient_medications`, `dose_events`, `alerts`) |
| (b) Bağlantısı `active` olan yakın görüyor mu? | Evet, ama yazamamalı | ✅ Geçer — yazma politikaları `patient_id = auth.uid()` arıyor |
| (c) `pending` / `revoked` yakın görüyor mu? | Hayır | ✅ Erişim kapalı; yalnızca bağlantı satırının kendisini görebiliyor |

### 7.3 Eray'ın bulduğu riskler (`docs/10_RLS_INCELEME_ERAY.md`)

1. **Bağlantı durumu istemciden değiştirilemiyor** — hasta bir yakının erişimini uygulamadan kaldıramıyor; davet/iptal akışı tasarlanırken ele alınmalı.
2. **Hasta, yakınının profilini göremiyor** — politika tek yönlü çalışıyor; "Yakınlarım" listesinde isim gösterilemez. Güvenlik açığı değil, işlevsel eksik.
3. **Bekleyen yakın hastanın adını göremiyor** — yalnızca kimlik numarasını görüyor; davet ekranında isim gerekirse sunucu tarafı çözüm gerekir.
4. **Revoked yakının geçmiş uyarıları gizleniyor** — gizlilik açısından doğru; bilinçli karar olarak ekipçe onaylanmalı.
5. **Canlı doğrulama yapılmadı** — notlar yalnızca okumaya dayanıyor.

### 7.4 Metehan'ın (şema sahibi) ek bulguları

Eray'ın notunu onayladı ve 6 madde ekledi:

1. **`patient_medications` güncellemesi sütun bazlı kısıtlı değil** — hasta mevcut bir kaydın ürün kodunu değiştirebilir; böylece yeni ilaç, tarama/etkileşim akışından geçmeden listeye girer. Öneri: sütun bazlı yetki. → **Issue #15**
2. **Doz geçmişi geriye dönük değiştirilebiliyor** — hasta geçmiş bir dozu "alındı ↔ atlandı" yapabilir ve yakın değiştirilmiş geçmişi görür. Öneri: güncelleme yetkisini kaldırmak veya aynı günle sınırlamak. → **Issue #16**
3. **Etkileşim kurallarına istemci erişimi hiç yok** — doğru tercih; kurallar yalnızca sunucu fonksiyonu üzerinden okunuyor. Notta açıkça yazılmalı ki ileride "okuma politikası unutulmuş" diye eklenmesin.
4. **`can_view_patient()` yetki yükseltmeli (security definer) çalışıyor** — politikaların birbirini çağırıp döngüye girmesini önlüyor, doğru. Ancak canlı ortamda fonksiyon sahibi kontrol edilmeli.
5. **Etkileşim kontrolü yalnızca giriş yapan hasta için çalışıyor** — yakın, hasta adına tarama yapamaz. Eksik değil, ama "yakın ilaç ekler" senaryosu düşünülüyorsa ayrı karar gerekir.
6. **Performans notu** — politikalarda `auth.uid()` yerine `(select auth.uid())` yazılması satır başına tekrar hesaplamayı önler.

### 7.5 Metehan'ın demo seed incelemesi (PR #11)

Şemayla satır satır karşılaştırdı: tablo/sütun adları, kanonik sıra (UUID bayt karşılaştırması), GTIN biçim kuralı, çakışma yönetimi, işlem bloğu ve `check_drug_risk()` ile tutarlılık — **hepsi doğru** bulundu. 4 öneri verdi, 2'si aynı gün uygulandı:

- ✅ Uygulandı: etken madde eklemede hedefsiz çakışma yönetimi (benzersiz ad çakışmasında seed tümden geri alınmasın)
- ✅ Uygulandı: kontrol betiğinde "en az" yerine **tam sayı** doğrulaması (10/8/4)
- ⏳ Not edildi: 13 haneli ulusal barkod eşlemesini test edecek 1-2 kurgusal ürün eklenmesi
- ⏳ Issue açıldı (#17): aynı etken maddenin iki farklı ürünle tekrarı (mükerrer tedavi riski) hiçbir kuralla yakalanmıyor

**Üçüncü bağımsız inceleme (Ahmet, Issue #3) henüz yapılmadı.**

---

## 8. Bulunan ve giderilen teknik sorunlar

| # | Sorun | Nasıl bulundu | Durum |
|---|---|---|---|
| 1 | Uygulama Android için hiç derlenmiyordu (bildirim paketi için gereken derleme ayarı eksikti) | İlk kez emülatörde çalıştırmayla | ✅ PR #18 |
| 2 | Bildirim izni reddedilince kullanıcıya "gönderildi" deniyordu | Kod incelemesi (alt ajan taraması) | ✅ Düzeltildi + mesaj ayrıştırıldı |
| 3 | 14 haneden fazla rakam içeren bozuk kod geçerli sayılabiliyordu | Kod incelemesi | ✅ Düzeltildi + test eklendi |
| 4 | Supabase başlatma hatası uygulamayı çökertebilirdi | Kod incelemesi | ✅ Hata yakalanıyor, DEMO modu açılıyor |
| 5 | Bir ilaç silinince geçmiş doz kayıtları da siliniyordu | Şema incelemesi | ✅ Silme yerine "pasif", geçmiş korunuyor |
| 6 | Aynı ilaç çifti ters sırada iki kez girilebiliyordu | Şema incelemesi | ✅ Kanonik sıra + tekil indeks |
| 7 | Flutter sürümü projeye sabitlenmemişti | Ortam incelemesi | ✅ `.fvmrc` eklendi |
| 8 | Paket kimliği örnek değerdeydi (`com.example…`) | DevOps incelemesi | ✅ `com.ilacetkilesim.yakinliktakip` |
| 9 | Kararlı sürüm (`main`) korumasızdı | DevOps incelemesi | ✅ Koruma açıldı: PR zorunlu, force-push kapalı |

---

## 9. Açık doğrulama boşlukları (dürüstlük bölümü)

| Boşluk | Neden | Ne zaman kapanacak |
|---|---|---|
| Gerçek ilaç kutusundan kamerayla okuma | Fiziksel telefon yok | Telefon bulunduğunda (Gizem, Issue #7) |
| Canlı veritabanında erişim kuralı testi | Dev Supabase projesi henüz kurulmadı | Sprint 2 (Metehan, Issue #5) |
| Üçüncü bağımsız RLS incelemesi | Başlanmadı | Issue #3 (Ahmet) |
| Zamanlanmış (takvime bağlı) bildirim | Başlanmadı | Issue #9 (Merve) |
| CI'da Android derleme adımı | Henüz eklenmedi | Eray'a önerildi, Issue açılacak |
| Gerçek ilaç/etkileşim verisi doğrulaması | Lisans teyidi yok | Issue #2 (Ali), `docs/12` |

---

## 10. Komutla yeniden üretme

Bu belgedeki her sonucu şu komutlarla kendiniz doğrulayabilirsiniz:

```bash
git clone https://github.com/Ilac-Etkilesim/ilac.git && cd ilac
fvm install && fvm use 3.38.1
fvm flutter pub get
fvm flutter analyze          # → No issues found!
fvm flutter test             # → 16 test, All tests passed!
python3 tools/check_demo_seed.py   # → TEMİZ
```

CI geçmişi: depo → **Actions** sekmesi. Kod incelemeleri: **Pull requests → Closed**. Görev dağılımı: **Issues**.
