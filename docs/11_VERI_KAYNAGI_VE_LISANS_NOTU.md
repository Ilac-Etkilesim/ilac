# Veri kaynağı ve lisans notu (Sprint 1)

**Durum:** Gerçek ilaç / etken madde / etkileşim verisi **henüz temin edilmedi**. Elimizdeki tek veri
`data/demo_products.csv` ve `supabase/seed/demo_seed.sql` içindeki **tamamen kurgusal** kayıtlardır.

## Demo seed ne işe yarar, ne işe yaramaz

| Kullanım | Durum |
|---|---|
| GTIN → ürün eşleştirme denemesi (Sprint 3, Gizem) | ✅ Uygun — 10 ürünün GTIN kontrol basamakları geçerli, parser'dan geçiyor |
| Supabase şema/RLS testleri (Sprint 2, Metehan) | ✅ Uygun — FK ve kanonik sıra kısıtları seed'de sağlanıyor |
| Etkileşim uyarısı demosu ("A ile B birlikte alınmaz") | ❌ **Çıkmaz** — `check_drug_risk()` demo ürünlerde `demo_only` döner; sorgu `is_verified=true and is_demo=false` kuralları arar |

Son satır **bilinçli bir güvenlik tasarımıdır**: doğrulanmamış veriyle kimseye "etkileşim var/yok" denmemeli.
Sunum/demoda etkileşim uyarısı göstermek istiyorsak seçenekler:

1. Fonksiyona açık bir "demo modu" parametresi eklemek (yalnızca demo ürünler için, ekranda "DEMO" etiketiyle) — ekip kararı + Metehan/Ahmet incelemesi gerekir.
2. Gerçek, lisanslı ve doğrulanmış veri gelene kadar etkileşim ekranını "kontrol tamamlanamadı" durumunda bırakmak.

## Gerçek veri için açık sorular (Ali döndüğünde)

- Hangi kaynak? (Resmî kurum listeleri, açık veri setleri, lisanslı ticari veri tabanları) — kullanım şartları ve yeniden dağıtım izni.
- GTIN ↔ ürün ↔ etken madde eşleşmesi hangi kaynaktan ve ne sıklıkla güncellenecek?
- Etkileşim kuralları için kaynak gösterimi (`source_name`, `source_reference`, `verified_on`) zorunlu; `is_verified=true` yapma yetkisi kimde?
- KVKK: ürün kataloğu kişisel veri değil, ama hasta-ilaç ilişkisi kişisel sağlık verisidir — saklama ve aktarım kuralı ayrı belgelenmeli (`docs/01_MVP_VE_KARARLAR.md`).

## Doğrulama

- `python3 tools/check_demo_seed.py` → CSV/seed tutarlılığı, GTIN kontrol basamakları, FK ve kanonik sıra.
- `flutter test` → `test/demo_products_test.dart` CSV'deki her GTIN'in uygulama parser'ından geçtiğini doğrular.
- Seed'i uygulamak: yalnızca geliştirme Supabase projesinde, migration sonrası, ekip onayıyla (`supabase/seed/` migrations dışında olduğu için otomatik uygulanmaz).
