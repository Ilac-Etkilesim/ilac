# Supabase canlı kurulumu ve doğrulaması — 23 Kasım 2026

**Yapan:** Melike · **Proje:** `ilac-dev` · **Bölge:** Central EU (Frankfurt, `eu-central-1`)
**PostgreSQL:** 17 · **Plan:** Free

> ## ⚠️ Önce bir düzeltme
> `docs/14_SPRINT2_SUPABASE_KURULUM_VE_RLS_TESTI.md` içindeki
> **"Canlı doğrulama sonuçları (2 Kasım 2026, dev Supabase projesi)"** tablosu ve
> `docs/15_KALICI_TEST_HESABI.md`, o tarihte **var olmayan** bir Supabase projesini
> anlatıyordu. Issue #5 bu tabloya dayanarak kapatılmıştı.
>
> Bu belge, 23 Kasım 2026'da **gerçekten kurulan ve çıktıları doğrulanan** ortamı
> anlatır. `docs/14`'ün yerel (PGlite) doğrulama bölümü geçerliliğini korur;
> yalnızca canlı bölüm geçersizdir.

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
