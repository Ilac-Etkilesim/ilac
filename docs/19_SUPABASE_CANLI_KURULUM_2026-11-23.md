# Supabase canlı kurulumu ve doğrulaması — 23 Kasım 2026

**Yapan:** Melike · **Proje:** `ilac-dev` · **Bölge:** Central EU (Frankfurt, `eu-central-1`)
**PostgreSQL:** 17 · **Plan:** Free

> ## ⚠️ Önce bir düzeltme (24 Kasım'da güncellendi)
> Bu belgenin ilk sürümü, 2 Kasım'daki dev Supabase projesinin **hiç var olmadığını**
> varsayıyordu. **Bu yanlıştı.** Metehan'ın PR #37 incelemesinde belirttiği ve
> Issue #5'te doğrulanabildiği üzere, proje 2 Kasım'da gerçekten kurulmuş,
> 001 ve 002 uygulanmış ve `rls_scenarios.sql` çıktısı ekran görüntüsüyle
> paylaşılmıştır (2 Kasım, 18:42).
>
> **Olan şu:** o proje daha sonra silinmiş, silinmeden önce ekibe bildirilmemiştir.
> Bu yüzden 23 Kasım'da proje bulunamadı, anahtarlar alınamadı ve ortam sıfırdan
> yeniden kuruldu.
>
> Dolayısıyla `docs/14`'teki sonuçlar **uydurma değil**, silinmiş bir projenin
> gerçek kayıtlarıdır. Ancak bugünkü ortamı temsil etmezler; çalışan ortam
> bu belgede anlatılandır.
>
> **Çıkarılan ders:** ortak bir ortam silinmeden önce ekibe haber verilmeli.
> Bu, verinin değil, doğrulama zincirinin kaybolmasına yol açtı.

---

## 1. Uygulanan migration'lar

| Sıra | Dosya | Sonuç |
|---|---|---|
| 1 | `20261021_001_initial_draft.sql` | ✅ Hatasız |
| 2 | `20261102_002_sprint2_rls_and_catalog.sql` | ✅ Hatasız |
| 3 | `20261123_003_profile_on_signup.sql` | ✅ Hatasız (bu kurulumda yazıldı) |

Kurulum sonrası şema durumu:

```
tablo = 9 · politika = 14 · fonksiyon = 6 · auth trigger = 1 · RLS açık tablo = 9/9
```

## 2. RLS senaryo testleri — gerçek sonuç

`supabase/tests/rls_scenarios.sql` canlı projede çalıştırıldı:

```
TÜM SENARYOLAR GEÇTİ
```

Betik sonunda `rollback` yapıyor; sonrasında doğrulandı:
`auth.users = 0 · profiles = 0 · products = 0 · dose_events = 0` (hiç iz kalmadı).

## 3. Bu kurulumda bulunan ve düzeltilen 3 gerçek sorun

Hiçbiri yerel doğrulamada görünmüyordu; yalnızca gerçek kurulumda ortaya çıktı.

### 3.1 `profiles` satırı hiç oluşmuyordu (🔴 yüksek)

`profiles` tablosu `auth.users`'a bağlıydı ama onu dolduran hiçbir şey yoktu:
ne trigger, ne de Flutter tarafında bir insert. Giriş ekranından (#24) kayıt olan
gerçek bir kullanıcı `auth.users`'ta var, `profiles`'ta yok olurdu; bu durumda
`patient_medications` ve `dose_events` yazılamaz, `can_view_patient()` üzerine
kurulu tüm RLS zinciri boşta kalırdı.

**Düzeltme:** `20261123_003_profile_on_signup.sql` — `on_auth_user_created`
trigger'ı + eski kullanıcılar için telafi sorgusu.
**Doğrulama:** İki test hesabı açıldı, ikisinin de profili otomatik oluştu.

### 3.2 RLS test fixture'ı trigger ile çakışıyordu (🟠 orta)

`rls_scenarios.sql`, `auth.users`'a kullanıcı ekledikten sonra `profiles`'a da
elle insert ediyordu. 3.1'deki trigger geldikten sonra bu
`duplicate key value violates unique constraint "profiles_pkey"` hatası verdi.

**Düzeltme:** Fixture'daki insert `on conflict (id) do update` ile güncellendi;
test adları korunuyor, çakışma yutuluyor.

### 3.3 Demo seed `product_ingredients`'ı doldurmuyordu (🟠 orta)

`docs/14` "seed, 002'den önce ya da sonra çalıştırılabilir" diyordu. Doğru değil:
bağlantı tablosunu dolduran sorgu yalnızca 002 uygulanırken bir kez çalışıyor.
Sıfırdan kurulan bir projede doğal sıra `001 → 002 → seed` olduğu için seed'in
eklediği ürünler o taşımayı kaçırıyordu.

**Canlı kanıt:** `ürün = 10 · product_ingredients = 0`

**Düzeltme:** `demo_seed.sql` sonuna tekrar çalıştırılabilir bağlantı insert'i
eklendi. Sonrası: `ürün = 10 · etken madde = 8 · bağlantı = 10 · kural = 4`

## 4. Test hesapları

| Hesap | Rol | Durum |
|---|---|---|
| `test-hasta@example.invalid` | Hasta | ✅ oluşturuldu, e-posta onaylı |
| `test-yakin@example.invalid` | Yakın | ✅ oluşturuldu, e-posta onaylı |

Şifreler rastgele üretildi ve **depoya yazılmadı**; yerel olarak
`~/.ilac_dev_test_accounts` (izin 600) dosyasında tutuluyor. Ekiple paylaşım
ayrı bir kanaldan yapılmalıdır. Hesaplar Admin API ile `email_confirm: true`
olarak açıldı; projenin e-posta onayı ayarı **değiştirilmedi**.

## 5. Katalog erişimi — canlı doğrulama (#31 ve #33'e girdi)

Gerçek kullanıcı oturumu (publishable key + giriş) ile PostgREST üzerinden:

| Kontrol | Sonuç |
|---|---|
| Giriş (publishable key) | ✅ token alındı |
| `products` okuma (GTIN ile) | ✅ ürün döndü |
| `product_ingredients` → `ingredients` okuma | ✅ etken madde döndü |
| Katalogda olmayan GTIN | ✅ boş liste (hata değil) |
| `products`'a INSERT denemesi | ✅ **reddedildi** (`42501 permission denied`) |

Son satır, Issue #33'ün (katalog salt okunur olmalı) asıl kabul kriteridir;
Metehan'ın incelemesi için ön kanıt olarak buraya yazılmıştır.

## 6. Flutter katalog servisi canlı testi (#31)

`test/catalog_service_live_test.dart` eklendi. Normal `flutter test`
çalıştırmasında **atlanır** (anahtar verilmediği sürece ağa çıkmaz, CI etkilenmez);
anahtarlarla çalıştırıldığında gerçek projeye bağlanır.

Sonuç: **2/2 geçti.** Doğrulananlar:
- Demo ürün bulundu, etken maddesi geldi, `isDemo = true` işaretlendi
- Katalogda olmayan GTIN `katalogdaYok` döndü (`sorgulanamadi` değil)

Ayrıca canlı veri, kodda tahmin edilen iki durumu doğruladı: iç içe `ingredients`
alanı **nesne** olarak dönüyor (liste değil) ve demo kayıtlarda `display_name`
boş olduğu için `normalized_name`'e düşülüyor.

Tüm takım: `flutter analyze` temiz · `flutter test` **49 geçti, 2 atlandı**.

## 6b. Issue #5 hakkında

İlk sürümde "#5 doğrulanmamış bir tabloya dayanarak kapatılmıştı, yeniden
açılmalı" denmişti. Metehan'ın açıklamasıyla bu değerlendirme değişti: #5
kapatıldığında doğrulama **gerçekten yapılmıştı**. Yeniden açmaya gerek yok;
#5'e bu belgeye ve PR #37'ye bağlantı veren bir yorum yeterli. Karar Sprint 3
liderindedir (Gizem, #29).

## 7. Yapılmayanlar (bilerek)

- **Gerçek TİTCK kataloğu yüklenmedi.** `docs/12`'deki ekip kararı gereği lisans
  teyidi alınmadan yüklenmeyecek. Bu Ali'nin açık görevidir. Sistem şu an demo
  veriyle çalışıyor; `check_drug_risk()` demo kayıtlarda tasarım gereği
  `demo_only` döner, etkileşim uyarısı gösterilmez.
- **GitHub entegrasyonu bağlanmadı.** Supabase GitHub App'i depoya push edilen
  migration'ları otomatik uygular; bu, CLAUDE.md'deki "migration öncesi açık
  onay" kuralını "PR merge = onay"a çevirir. Ekip kararı gerektirir.
- **Issue #30 (Ali) ve #33 (Metehan) sahiplerinde bırakıldı.** Üzerinde
  çalışacakları veritabanı artık hazır ve doğrulanmış durumda.

## 8. Erişim notları

- Yeni organizasyon kapsamlı erişim token'ı 30 gün sonra sona erer.
- Ücretsiz planda proje **7 gün hareketsiz kalırsa duraklatılır**; demo öncesi
  panelden uyandırıldığından emin olun.
- Ücretsiz planda otomatik yedek yoktur. Risk düşük: şemanın tamamı
  `supabase/migrations/` altında, bu belgedeki sırayla yeniden kurulabilir.

---

## 9. Migration takip tablosu (GitHub entegrasyonu öncesi zorunlu adım)

Supabase'in GitHub entegrasyonu, PR merge edildiğinde `supabase/migrations/`
altındaki dosyaları **otomatik uygular** ve hangilerinin uygulandığını
`supabase_migrations.schema_migrations` tablosundan takip eder.

Bu kurulumda migration'lar Management API ile elle uygulandı, yani takip
tablosundan geçmediler. Tablo hiç yoktu. Entegrasyon devreye girdiğinde
üçünü de "hiç uygulanmamış" sayıp baştan çalıştırmaya kalkardı.

**Bu neden kırılırdı:** `001_initial_draft.sql` tekrar çalıştırılabilir değil.
İçinde **13 adet `create policy`** var ve hiçbirinde `drop policy if exists`
koruması yok; ikinci çalıştırmada `policy already exists` hatası verir.
(Karşılaştırma: `002`'de üç politikanın üçünde de koruma var, `003` zaten
tekrar çalıştırılabilir yazıldı.)

**Yapılan:** Takip tablosu oluşturuldu ve uygulanan üç migration kaydedildi.
Bu, gerçeği yansıtır — üçü de gerçekten uygulandı:

| version | name |
|---|---|
| `20261021` | `001_initial_draft` |
| `20261102` | `002_sprint2_rls_and_catalog` |
| `20261123` | `003_profile_on_signup` |

Sürüm numaraları dosya adlarındaki ilk alt çizgiye kadar olan rakamlardan
türetildi (Supabase CLI'ın kuralı).

### Metehan'a öneri (kendi alanı, kararı onda)

`001`'deki her `create policy` öncesine `drop policy if exists` eklenirse dosya
tekrar çalıştırılabilir hale gelir. Takip tablosu sayesinde şu an gerekli
değil, ama sıfırdan kurulumların ve olası bir yeniden uygulamanın güvenliği
için sağlamlaştırma olur. `002` bu kalıbı zaten kullanıyor.
