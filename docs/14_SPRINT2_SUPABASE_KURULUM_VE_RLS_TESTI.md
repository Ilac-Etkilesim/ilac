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

Bu, Supabase'in birebir aynısı değildir; bu yüzden ardından canlı doğrulama da yapıldı (aşağıdaki tablo).

## Canlı doğrulama sonuçları (2 Kasım 2026, dev Supabase projesi — Metehan)

`rls_scenarios.sql` SQL Editor'de tek seferde çalıştırıldı; çıktı: **`TÜM SENARYOLAR GEÇTİ`** (ekran görüntüsü Issue #5'te).
Betik ilk başarısız kontrolde hata vererek durduğu için bu çıktı, aşağıdaki tüm kontrollerin geçtiğini gösterir.

| Senaryo | Beklenen | Sonuç | Not |
|---|---|---|---|
| 001 + 002 hatasız uygulandı | Geçer | Geçti | SQL Editor, sırayla |
| 1 — Hasta kendi verisini görüyor, başkasınınkini görmüyor | Geçer | Geçti | 1a–1d |
| #15 — `product_gtin` güncellenemiyor, `dose_label` güncellenebiliyor | Geçer | Geçti | |
| #16 — Dünün dozu değişmiyor, bugünkü değişiyor, `updated_at` doluyor | Geçer | Geçti | `scheduled_date` de değiştirilemiyor |
| #17/#23 — `check_drug_risk` 8 durumu doğru döndürüyor | Geçer | Geçti | risk_found, same_ingredient, kombine ürün, needs_review, demo_only, product_not_found |
| 2 — Aktif yakın okuyor, yazamıyor | Geçer | Geçti | 2a–2d |
| 3 — Revoked/pending yakın hasta verisini göremiyor | Geçer | Geçti | 3a–3f |
| 4 — Katalog salt okunur, kurallar kapalı, anon fonksiyonu çağıramıyor | Geçer | Geçti | 4a–4d |
| Test verisi geri alındı (rollback) | Evet | Evet | Betik sonunda `rollback` |
| `service_role` hiçbir yerde paylaşılmadı | Evet | Evet | Yalnızca publishable key kullanılacak |

## Açık konular

- ~~`dose_events` için geçmiş tarihli insert hâlâ serbest~~ — çözüldü (Melike, c1a3981): `dose_events_write_own` artık yalnızca bugünün tarihiyle insert'e izin veriyor, update ile tutarlı.
- `same_ingredient` ve demo modu: demo ürünler hâlâ erken `demo_only` döner; bu yüzden aynı etken madde uyarısı demo verisiyle gösterilemez (bkz. PR #11 incelemesi, "demo modu").
- `same_ingredient` ve `needs_review`: Ali'nin incelemesinde bulundu — paylaşılan belirsiz ATC grup kayıtları (needs_review=true) yanlış pozitif same_ingredient üretiyordu; `check_drug_risk()`'e `and not i.needs_review` eklenerek düzeltildi, gerçek veriyle doğrulandı (Tazeracin/Tienam örneği).
- Arayüz: `same_ingredient` ve `needs_review` durumlarının ekranda gösterimi (Afra/Melike ile).
