-- =============================================================================
-- DEMO SEED — YALNIZCA KURGUSAL VERİ (Sprint 1, Issue #2)
-- =============================================================================
-- * Bu dosya migrations/ altında DEĞİLDİR; otomatik uygulanmaz. Yalnızca
--   geliştirme amaçlı bir Supabase projesinde, 20261021_001_initial_draft.sql
--   uygulandıktan SONRA, ekip onayıyla elle çalıştırılır.
-- * Tüm etken madde ve ürün adları uydurmadır; gerçek ilaçlarla eşleşmez.
-- * Tüm kayıtlar is_demo = true, kurallar is_verified = false'tur. Bu nedenle
--   check_drug_risk() bu verilerle hiçbir zaman "risk_found" döndürmez
--   (tasarım gereği: 'demo_only' döner). Etkileşim uyarısı demosu ayrı bir
--   ekip kararı gerektirir (bkz. docs/11_VERI_KAYNAGI_VE_LISANS_NOTU.md).
-- * UUID'ler sabittir ki seed tekrar çalıştırılabilsin (on conflict do nothing)
--   ve interaction_rules için kanonik sıra (ingredient_a_id < ingredient_b_id)
--   kolayca sağlansın: a000…01 < a000…02 < … < a000…08.
-- =============================================================================

begin;

-- 8 kurgusal etken madde
insert into public.ingredients (id, normalized_name) values
  ('a0000000-0000-4000-8000-000000000001', 'demo_etken_a'),
  ('a0000000-0000-4000-8000-000000000002', 'demo_etken_b'),
  ('a0000000-0000-4000-8000-000000000003', 'demo_etken_c'),
  ('a0000000-0000-4000-8000-000000000004', 'demo_etken_d'),
  ('a0000000-0000-4000-8000-000000000005', 'demo_etken_e'),
  ('a0000000-0000-4000-8000-000000000006', 'demo_etken_f'),
  ('a0000000-0000-4000-8000-000000000007', 'demo_etken_g'),
  ('a0000000-0000-4000-8000-000000000008', 'demo_etken_h')
on conflict do nothing; -- hedefsiz: id VEYA normalized_name çakışırsa seed tümden geri alınmasın (Metehan, PR #11)

-- 10 kurgusal ürün (GTIN-14 kontrol basamakları geçerli; tools/check_demo_seed.py doğrular)
-- Ürün I ve J, A ve B ile aynı etken maddeyi taşır: "farklı marka, aynı etken madde" senaryosu.
insert into public.products (gtin, display_name, ingredient_id, is_demo, data_source) values
  ('99990000000008', 'Örnek Ürün A', 'a0000000-0000-4000-8000-000000000001', true, 'DEMO — kurgusal'),
  ('99990000000015', 'Örnek Ürün B', 'a0000000-0000-4000-8000-000000000002', true, 'DEMO — kurgusal'),
  ('99990000000022', 'Örnek Ürün C', 'a0000000-0000-4000-8000-000000000003', true, 'DEMO — kurgusal'),
  ('99990000000039', 'Örnek Ürün D', 'a0000000-0000-4000-8000-000000000004', true, 'DEMO — kurgusal'),
  ('99990000000046', 'Örnek Ürün E', 'a0000000-0000-4000-8000-000000000005', true, 'DEMO — kurgusal'),
  ('99990000000053', 'Örnek Ürün F', 'a0000000-0000-4000-8000-000000000006', true, 'DEMO — kurgusal'),
  ('99990000000060', 'Örnek Ürün G', 'a0000000-0000-4000-8000-000000000007', true, 'DEMO — kurgusal'),
  ('99990000000077', 'Örnek Ürün H', 'a0000000-0000-4000-8000-000000000008', true, 'DEMO — kurgusal'),
  ('99990000000084', 'Örnek Ürün I', 'a0000000-0000-4000-8000-000000000001', true, 'DEMO — kurgusal'),
  ('99990000000091', 'Örnek Ürün J', 'a0000000-0000-4000-8000-000000000002', true, 'DEMO — kurgusal')
on conflict (gtin) do nothing;

-- 4 kurgusal etkileşim kuralı (kanonik sıra: a < b). Açıklamalar temsilidir, tıbbi bilgi değildir.
insert into public.interaction_rules
  (ingredient_a_id, ingredient_b_id, severity, explanation, source_name, source_reference, verified_on, is_verified, is_demo)
values
  ('a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'major',
   'DEMO: A ve B birlikte kullanıldığında temsili "ciddi" etkileşim senaryosu.', 'DEMO — kurgusal', null, null, false, true),
  ('a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'moderate',
   'DEMO: A ve C için temsili "orta" etkileşim senaryosu.', 'DEMO — kurgusal', null, null, false, true),
  ('a0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000005', 'minor',
   'DEMO: D ve E için temsili "hafif" etkileşim senaryosu.', 'DEMO — kurgusal', null, null, false, true),
  ('a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000006', 'major',
   'DEMO: B ve F için temsili "ciddi" etkileşim senaryosu.', 'DEMO — kurgusal', null, null, false, true)
on conflict do nothing;

commit;
