-- =============================================================================
-- GTIN İLE KATALOG SORGUSU SENARYOLARI (Issue #30)
-- =============================================================================
-- * Yalnızca GELİŞTİRME Supabase projesinde, SQL Editor'de (postgres rolüyle)
--   001, 002 ve 004 migration'ları uygulandıktan SONRA çalıştırılır. 003
--   uygulanmış olsa da olmasa da çalışır (test kullanıcısı açmaz).
-- * Her şey tek transaction içinde yapılır ve sonda ROLLBACK edilir:
--   veritabanında hiçbir test verisi KALMAZ.
-- * Bir kontrol başarısız olursa betik o noktada hata mesajıyla durur.
--   Sonda "KATALOG SORGUSU SENARYOLARI GEÇTİ" görünüyorsa hepsi geçmiştir.
-- * Tüm adlar ve GTIN'ler kurgusaldır (9998 ile başlar).
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0) Kurulum (postgres olarak)
-- ---------------------------------------------------------------------------
insert into public.ingredients (id, normalized_name, display_name, atc_codes, needs_review, review_reason) values
  ('b0000000-0000-4000-8000-000000003001', 'test_s_etken_a', 'TEST S Etken A', '{T01AA01}', false, null),
  ('b0000000-0000-4000-8000-000000003002', 'test_s_etken_b', 'TEST S Etken B', '{}',        false, null),
  ('b0000000-0000-4000-8000-000000003003', 'test_s_grup',    'TEST S grup adı', '{}',       true,  'kategori adı, madde değil'),
  ('b0000000-0000-4000-8000-000000003004', 'test_s_etken_c', '',               '{}',        false, null);

insert into public.products (gtin, display_name, atc_code, license_status, is_demo, data_source) values
  ('99980000000010', 'TEST S Tek maddeli',      'T01AA01', 'aktif',  false, 'TEST'),
  ('99980000000027', 'TEST S Kombine (A + B)',  'T01AA51', 'aktif',  false, 'TEST'),
  ('99980000000034', 'TEST S Grup adlı (B + ?)', 'T01AA52', 'aktif', false, 'TEST'),
  ('99980000000041', 'TEST S Etken maddesiz',   null,      'askıda', false, 'TEST'),
  ('99980000000058', 'TEST S Demo ürün',        null,      null,     true,  'TEST'),
  ('99980000000065', 'TEST S Adı boş madde',    null,      'aktif',  false, 'TEST');

insert into public.product_ingredients (product_gtin, ingredient_id) values
  ('99980000000010', 'b0000000-0000-4000-8000-000000003001'),
  ('99980000000027', 'b0000000-0000-4000-8000-000000003001'),
  ('99980000000027', 'b0000000-0000-4000-8000-000000003002'),
  ('99980000000034', 'b0000000-0000-4000-8000-000000003002'),
  ('99980000000034', 'b0000000-0000-4000-8000-000000003003'),
  ('99980000000058', 'b0000000-0000-4000-8000-000000003001'),
  ('99980000000065', 'b0000000-0000-4000-8000-000000003004');

-- ---------------------------------------------------------------------------
-- 1) Yapı: tek sürüm, yalnızca GTIN alır, security invoker, search_path sabit,
--    anon çalıştıramaz
-- ---------------------------------------------------------------------------
do $$ begin
  assert (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'catalog_lookup') = 1,
    '1a: catalog_lookup tek bir sürüm olmalı';
  assert (select pg_get_function_identity_arguments(p.oid) from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'catalog_lookup') = 'p_gtin text',
    '1b: catalog_lookup yalnızca p_gtin almalı';
  assert (select not p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')
          from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'catalog_lookup'),
    '1c: catalog_lookup security invoker olmalı ve search_path sabit olmalı';
  assert has_function_privilege('authenticated', 'public.catalog_lookup(text)', 'EXECUTE'),
    '1d: authenticated fonksiyonu çalıştırabilmeli';
  assert not has_function_privilege('anon', 'public.catalog_lookup(text)', 'EXECUTE'),
    '1e: anon fonksiyonu çalıştıramamalı';
end $$;

-- ---------------------------------------------------------------------------
-- 2) Giriş yapmış kullanıcı olarak sorgular
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000003001","role":"authenticated"}', true);

do $$ declare r jsonb; begin
  -- 2a) bulundu — tek etken madde
  r := public.catalog_lookup('99980000000010');
  assert r->>'status' = 'bulundu', format('2a: tek maddeli ürün bulundu olmalı; gelen %s', r);
  assert (r->>'ingredient_count')::int = 1 and r->'ingredients'->0->>'name' = 'TEST S Etken A',
    format('2a: tek etken madde dönmeli; gelen %s', r);
  assert r->'product'->>'display_name' = 'TEST S Tek maddeli' and r->>'reason' is null,
    format('2a: ürün adı dönmeli; gelen %s', r);

  -- 2b) bulundu — kombine ürün: iki etken madde de, sıralı
  r := public.catalog_lookup('99980000000027');
  assert r->>'status' = 'bulundu', format('2b: kombine ürün bulundu olmalı; gelen %s', r);
  assert (r->>'ingredient_count')::int = 2
     and jsonb_array_length(r->'ingredients') = 2
     and r->'ingredients'->0->>'name' = 'TEST S Etken A'
     and r->'ingredients'->1->>'name' = 'TEST S Etken B',
    format('2b: kombine üründe iki etken madde sıralı dönmeli; gelen %s', r);

  -- 2c) needs_review — maddelerden biri grup adı
  r := public.catalog_lookup('99980000000034');
  assert r->>'status' = 'needs_review' and r->>'reason' = 'etken_madde_inceleme_bekliyor',
    format('2c: grup adlı ürün needs_review olmalı; gelen %s', r);
  assert (r->>'ingredient_count')::int = 2
     and exists (select 1 from jsonb_array_elements(r->'ingredients') e
                 where (e->>'needs_review')::boolean and e->>'review_reason' = 'kategori adı, madde değil'),
    format('2c: inceleme bekleyen madde işaretli dönmeli; gelen %s', r);

  -- 2d) needs_review — ürün var, etken madde bağlantısı yok
  r := public.catalog_lookup('99980000000041');
  assert r->>'status' = 'needs_review' and r->>'reason' = 'etken_madde_yok'
     and (r->>'ingredient_count')::int = 0 and r->'product'->>'license_status' = 'askıda',
    format('2d: etken maddesiz ürün needs_review/etken_madde_yok olmalı; gelen %s', r);

  -- 2e) katalogda_yok — geçerli biçimde ama kayıtlı olmayan GTIN
  r := public.catalog_lookup('99980000000096');
  assert r->>'status' = 'katalogda_yok' and r->>'reason' = 'kayit_yok'
     and r->'product' = 'null'::jsonb and r->'ingredients' = '[]'::jsonb,
    format('2e: bilinmeyen GTIN açıkça katalogda_yok dönmeli (boş/null değil); gelen %s', r);
  assert r is not null and r->>'message' is not null,
    '2e: bilinmeyen GTIN için yanıt ve mesaj boş olmamalı';

  -- 2f) katalogda_yok — biçim hatalı / boş / null girişler
  r := public.catalog_lookup('123');
  assert r->>'status' = 'katalogda_yok' and r->>'reason' = 'gecersiz_gtin',
    format('2f: 14 hane olmayan kod gecersiz_gtin olmalı; gelen %s', r);
  r := public.catalog_lookup('9998000000001X');
  assert r->>'reason' = 'gecersiz_gtin', format('2f: harf içeren kod gecersiz_gtin olmalı; gelen %s', r);
  r := public.catalog_lookup(null);
  assert r->>'status' = 'katalogda_yok' and r->>'reason' = 'gecersiz_gtin',
    format('2f: null giriş gecersiz_gtin olmalı; gelen %s', r);

  -- 2g) Baştaki/sondaki boşluk temizlenir
  r := public.catalog_lookup('  99980000000010 ');
  assert r->>'status' = 'bulundu' and r->>'gtin' = '99980000000010',
    format('2g: boşluklu GTIN temizlenip bulunmalı; gelen %s', r);

  -- 2h) Demo ürün: bulunur, DEMO olarak işaretlenir
  r := public.catalog_lookup('99980000000058');
  assert r->>'status' = 'bulundu' and (r->'product'->>'is_demo')::boolean
     and r->>'message' like 'DEMO kayıt.%',
    format('2h: demo ürün bulundu + is_demo + DEMO mesajı dönmeli; gelen %s', r);

  -- 2i) display_name boşsa normalized_name gösterilir
  r := public.catalog_lookup('99980000000065');
  assert r->'ingredients'->0->>'name' = 'test_s_etken_c',
    format('2i: boş display_name yerine normalized_name dönmeli; gelen %s', r);
end $$;

-- 2j) Hiçbir mesaj "güvenli / doğrulandı / uygun" demez
do $$ declare g text; r jsonb; begin
  foreach g in array array['99980000000010','99980000000027','99980000000034',
                           '99980000000041','99980000000058','99980000000096','123'] loop
    r := public.catalog_lookup(g);
    assert lower(r->>'message') !~ '(güvenli|guvenli|doğrulandı|dogrulandi|uygun)',
      format('2j: mesajda yasak ifade var (%s): %s', g, r->>'message');
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3) anon — fonksiyonu çalıştıramaz
-- ---------------------------------------------------------------------------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  begin
    perform public.catalog_lookup('99980000000010');
    raise exception '3 BAŞARISIZ: anon catalog_lookup çalıştırabildi';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
select 'KATALOG SORGUSU SENARYOLARI GEÇTİ' as sonuc;
rollback;
