# Sprint 2 — Dev Supabase kurulumu ve RLS doğrulaması (Metehan)

**İlgili Issue'lar:** #5 (kurulum + canlı doğrulama), #15, #16, #17, #23
**Teknik gözden geçiren:** Eray
**Dosyalar:**
- `supabase/migrations/20261021_001_initial_draft.sql` — Sprint 0 taslağı
- `supabase/migrations/20261102_002_sprint2_rls_and_catalog.sql` — bu sprintin değişiklikleri
- `supabase/tests/rls_scenarios.sql` — senaryo testleri (kendi kendini geri alır)

## 002 migration'ı ne değiştiriyor?

| Issue | Değişiklik |
|---|---|
| #15 | `patient_medications`: güncelleme yetkisi yalnızca `active`, `dose_label`, `scheduled_time` sütunlarında. `product_gtin` yalnızca insert ile belirlenir. |
| #16 | `dose_events`: yalnızca **bugünün** (Türkiye saati) dozu değiştirilebilir ve yalnızca `status` sütunu. Değişiklik `updated_at` ile işaretlenir; yakın tarafı "sonradan değiştirildi" gösterebilir. Ekip kararı: "aynı gün izin". |
| #23 | `product_ingredients` tablosu (çok etken maddeli ürünler), `products.atc_code`, `products.license_status`, `ingredients.display_name / atc_codes / needs_review / review_reason`. `products.ingredient_id` artık boş olabilir. Mevcut ürünler yeni tabloya otomatik taşınır. |
| #17 | `check_drug_risk()`: ürünün **tüm** etken maddelerini karşılaştırır; aynı etken madde listede varsa `same_ingredient` döner. Etkileşim bulunsa bile `same_ingredient` bayrağı yanıtta kalır. |

`check_drug_risk()` yanıt durumları: `product_not_found` · `demo_only` · `not_evaluated` · `same_ingredient` · `risk_found`.
Her yanıtta `same_ingredient` ve `needs_review` (bool) alanları var. Hiçbir durum "güvenli" anlamına gelmez.

## Uygulama sırası

1. `20261021_001_initial_draft.sql`
2. `20261102_002_sprint2_rls_and_catalog.sql`
3. (İsteğe bağlı) `supabase/seed/demo_seed.sql` — 002'den önce ya da sonra çalıştırılabilir; 002 önceden yüklenmiş demo ürünleri `product_ingredients`'a taşır.
4. Gerçek katalog (PR #22 birleştikten sonra, ayrı onayla): `ingredients.csv` → `products.csv` → `product_ingredients.csv`. `atc_codes` alanı `;` ile ayrılmıştır, `text[]`'e çevrilerek yüklenir. CSV'ler repoya commit edilmez.

## #5 — Kurulum adımları (Metehan yapacak)

1. **Ekipten açık onay al** (CLAUDE.md kuralı) — Issue #5'e "uygulanıyor" yorumu yaz.
2. supabase.com'da **yalnızca geliştirme amaçlı** yeni proje aç (ücretsiz katman, bölge: Avrupa). Gerçek hasta verisi girme.
3. SQL Editor'de sırayla 001 ve 002'yi çalıştır.
4. SQL Editor'de `supabase/tests/rls_scenarios.sql` dosyasının tamamını çalıştır. Sonda **`TÜM SENARYOLAR GEÇTİ`** görmelisin. Betik test kullanıcılarını ve verilerini kendisi oluşturup sonda geri alır; veritabanında iz bırakmaz.
5. Kabul kriterindeki "2 test auth kullanıcısı" için ayrıca Dashboard → Authentication → Add user ile `hasta` ve `yakin` test hesapları açılabilir (Flutter girişini denemek için, #24).
6. Uygulamada yalnızca **publishable key** kullan. `service_role` anahtarını hiçbir dosyaya, PR'a veya mesaja yazma.
7. Aşağıdaki tabloyu doldurup Issue #5'e yaz.

## Yerel ön doğrulama (2 Kasım 2026)

Gerçek Supabase açılmadan önce, betikler yerelde **PGlite** (Node'da çalışan PostgreSQL) ile, Supabase'in `auth.uid()` fonksiyonunu ve `anon`/`authenticated` rollerini taklit eden küçük bir katman üzerinde çalıştırıldı:

| Adım | Sonuç |
|---|---|
| 001 migration | Geçti (`pgcrypto` satırı atlandı; `gen_random_uuid` PostgreSQL çekirdeğinde var) |
| demo seed → 002 | Geçti; 10 demo ürün `product_ingredients`'a taşındı |
| demo seed tekrar (002 sonrası) | Geçti (tekrar çalıştırılabilir) |
| `rls_scenarios.sql` | **Tüm senaryolar geçti**; rollback sonrası test kullanıcısı kalmadı |
| Negatif kontrol: 002 olmadan senaryolar | Beklendiği gibi **başarısız** (`#15 BAŞARISIZ: product_gtin güncellenebildi`) — testler gerçekten hata yakalıyor |

Bu, Supabase'in birebir aynısı değildir; canlı doğrulama (aşağıdaki tablo) yine de gereklidir.

## Canlı doğrulama sonuçları (doldurulacak)

| Senaryo | Beklenen | Sonuç | Not |
|---|---|---|---|
| 001 + 002 hatasız uygulandı | Geçer | | |
| 1 — Hasta kendi verisini görüyor, başkasınınkini görmüyor | Geçer | | |
| #15 — `product_gtin` güncellenemiyor, `dose_label` güncellenebiliyor | Geçer | | |
| #16 — Dünün dozu değişmiyor, bugünkü değişiyor, `updated_at` doluyor | Geçer | | |
| #17/#23 — `check_drug_risk` 8 durumu doğru döndürüyor | Geçer | | |
| 2 — Aktif yakın okuyor, yazamıyor | Geçer | | |
| 3 — Revoked/pending yakın hasta verisini göremiyor | Geçer | | |
| 4 — Katalog salt okunur, kurallar kapalı, anon fonksiyonu çağıramıyor | Geçer | | |
| `service_role` hiçbir yerde paylaşılmadı | Evet | | |

## Açık konular

- `dose_events` için geçmiş tarihli **insert** hâlâ serbest (ör. dünün dozu bugün "taken" olarak eklenebilir). #16 yalnızca güncellemeyi kapsıyor; ayrı karar gerekir.
- `same_ingredient` ve demo modu: demo ürünler hâlâ erken `demo_only` döner; bu yüzden aynı etken madde uyarısı demo verisiyle gösterilemez (bkz. PR #11 incelemesi, "demo modu").
- Arayüz: `same_ingredient` ve `needs_review` durumlarının ekranda gösterimi (Afra/Melike ile).
