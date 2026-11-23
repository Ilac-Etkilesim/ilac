-- =============================================================================
-- KATALOG ERİŞİM YETKİSİ VE RLS SENARYOLARI (Issue #33)
-- =============================================================================
-- * Yalnızca GELİŞTİRME Supabase projesinde, SQL Editor'de (postgres rolüyle)
--   001 ve 002 migration'ları uygulandıktan SONRA çalıştırılır. 003 uygulanmış
--   olsa da olmasa da çalışır.
-- * rls_scenarios.sql'den bağımsızdır; ikisi ayrı ayrı çalıştırılabilir.
-- * Her şey tek transaction içinde yapılır ve sonda ROLLBACK edilir:
--   veritabanında hiçbir test kullanıcısı / veri KALMAZ.
-- * Bir kontrol başarısız olursa betik o noktada hata mesajıyla durur.
--   Sonda "KATALOG SENARYOLARI GEÇTİ" görünüyorsa hepsi geçmiştir.
-- * Tüm adlar/UUID'ler/GTIN'ler kurgusaldır; gerçek hasta veya ilaç verisi yoktur.
--
-- Beklenen erişim modeli (katalog hasta verisi değildir):
--   tablo                | anon | authenticated     | RLS
--   ---------------------+------+-------------------+-----
--   products             | yok  | yalnızca SELECT   | açık
--   ingredients          | yok  | yalnızca SELECT   | açık
--   product_ingredients  | yok  | yalnızca SELECT   | açık
--   interaction_rules    | yok  | yok (yalnızca check_drug_risk üzerinden) | açık
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0) Kurulum (postgres olarak)
-- ---------------------------------------------------------------------------
-- İki ayrı hasta: KA ve KB
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000033a1', 'test-katalog-a@example.invalid'),
  ('00000000-0000-4000-8000-0000000033b1', 'test-katalog-b@example.invalid');

-- 003 trigger'ı varsa profiller zaten açılmıştır; yoksa burada açılır.
insert into public.profiles (id, display_name) values
  ('00000000-0000-4000-8000-0000000033a1', 'TEST Katalog Hasta A'),
  ('00000000-0000-4000-8000-0000000033b1', 'TEST Katalog Hasta B')
on conflict (id) do update set display_name = excluded.display_name;

insert into public.ingredients (id, normalized_name, display_name) values
  ('b0000000-0000-4000-8000-000000003301', 'test_k_etken_x', 'TEST K Etken X'),
  ('b0000000-0000-4000-8000-000000003302', 'test_k_etken_v', 'TEST K Etken V'),
  ('b0000000-0000-4000-8000-000000003303', 'test_k_etken_z', 'TEST K Etken Z');

insert into public.products (gtin, display_name, is_demo, data_source) values
  ('99970000000011', 'TEST K Ürün X',              false, 'TEST'),
  ('99970000000028', 'TEST K Ürün V',              false, 'TEST'),
  ('99970000000035', 'TEST K Ürün Z (B listesinde)', false, 'TEST'),
  ('99970000000042', 'TEST K Ürün Z (başka marka)',  false, 'TEST');

insert into public.product_ingredients (product_gtin, ingredient_id) values
  ('99970000000011', 'b0000000-0000-4000-8000-000000003301'),
  ('99970000000028', 'b0000000-0000-4000-8000-000000003302'),
  ('99970000000035', 'b0000000-0000-4000-8000-000000003303'),
  ('99970000000042', 'b0000000-0000-4000-8000-000000003303');

-- Doğrulanmış, demo olmayan tek kural: V × Z = major
insert into public.interaction_rules
  (ingredient_a_id, ingredient_b_id, severity, explanation, source_name,
   source_reference, verified_on, is_verified, is_demo)
values
  ('b0000000-0000-4000-8000-000000003302', 'b0000000-0000-4000-8000-000000003303', 'major',
   'TEST: V ve Z temsili ciddi etkileşim.', 'TEST', 'test', current_date, true, false);

-- A'nın listesinde X, B'nin listesinde Z var.
insert into public.patient_medications (id, patient_id, product_gtin, dose_label, scheduled_time) values
  ('c0000000-0000-4000-8000-000000003301', '00000000-0000-4000-8000-0000000033a1', '99970000000011', '1 tablet', '08:00'),
  ('c0000000-0000-4000-8000-000000003302', '00000000-0000-4000-8000-0000000033b1', '99970000000035', '1 tablet', '09:00');

-- ---------------------------------------------------------------------------
-- 5.0) Yapı: RLS açık, yazma yetkisi yok, politikalar yalnızca okuma
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
  catalog text[] := array['products','ingredients','product_ingredients','interaction_rules'];
begin
  foreach t in array catalog loop
    assert (select c.relrowsecurity from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relname = t),
      format('5.0a: %s tablosunda RLS açık olmalı', t);

    assert not has_table_privilege('authenticated', 'public.' || t,
                 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'),
      format('5.0b: authenticated rolünün %s üzerinde yazma yetkisi olmamalı', t);

    assert not has_table_privilege('anon', 'public.' || t,
                 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'),
      format('5.0c: anon rolünün %s üzerinde hiçbir yetkisi olmamalı', t);
  end loop;

  assert has_table_privilege('authenticated', 'public.products', 'SELECT')
     and has_table_privilege('authenticated', 'public.ingredients', 'SELECT')
     and has_table_privilege('authenticated', 'public.product_ingredients', 'SELECT'),
    '5.0d: authenticated katalog tablolarını okuyabilmeli';

  assert not has_table_privilege('authenticated', 'public.interaction_rules', 'SELECT'),
    '5.0e: interaction_rules istemciye doğrudan kapalı olmalı';

  assert not exists (select 1 from pg_policies
                     where schemaname = 'public' and tablename = any(catalog)
                       and cmd <> 'SELECT'),
    '5.0f: katalog tablolarında yazmaya izin veren politika olmamalı';

  -- check_drug_risk: tek sürüm, yalnızca GTIN alır (hasta kimliği istemciden
  -- verilemez), security definer ve search_path sabit.
  assert (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'check_drug_risk') = 1,
    '5.0g: check_drug_risk tek bir sürüm olmalı';
  assert (select pg_get_function_identity_arguments(p.oid) from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'check_drug_risk') = 'p_gtin text',
    '5.0h: check_drug_risk yalnızca p_gtin almalı';
  assert (select p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')
          from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'check_drug_risk'),
    '5.0i: check_drug_risk security definer ve search_path sabit olmalı';
end $$;

-- ---------------------------------------------------------------------------
-- 5.1) Hasta A — katalogu okur, yazamaz/silemez
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000033a1","role":"authenticated"}', true);

do $$ begin
  assert (select count(*) from public.products where gtin like '9997%') = 4,
    '5.1a: hasta A test ürünlerini okuyabilmeli';
  assert (select count(*) from public.ingredients where normalized_name like 'test_k_%') = 3,
    '5.1b: hasta A test etken maddelerini okuyabilmeli';
  assert (select count(*) from public.product_ingredients where product_gtin like '9997%') = 4,
    '5.1c: hasta A ürün-etken madde bağlantılarını okuyabilmeli';
end $$;

do $$
declare
  stmt text;
  stmts text[] := array[
    $s$insert into public.products (gtin, display_name, is_demo) values ('99970000000099', 'HACK', false)$s$,
    $s$update public.products set display_name = 'HACK' where gtin = '99970000000011'$s$,
    $s$delete from public.products where gtin = '99970000000011'$s$,
    $s$truncate public.products cascade$s$,
    $s$insert into public.ingredients (normalized_name) values ('test_k_hack')$s$,
    $s$update public.ingredients set needs_review = true where normalized_name = 'test_k_etken_x'$s$,
    $s$delete from public.ingredients where normalized_name = 'test_k_etken_x'$s$,
    $s$truncate public.ingredients cascade$s$,
    $s$insert into public.product_ingredients values ('99970000000011', 'b0000000-0000-4000-8000-000000003302')$s$,
    $s$update public.product_ingredients set ingredient_id = 'b0000000-0000-4000-8000-000000003302' where product_gtin = '99970000000011'$s$,
    $s$delete from public.product_ingredients where product_gtin = '99970000000011'$s$,
    $s$truncate public.product_ingredients$s$,
    $s$insert into public.interaction_rules (ingredient_a_id, ingredient_b_id, severity, explanation, source_name, source_reference, verified_on, is_verified, is_demo) values ('b0000000-0000-4000-8000-000000003301', 'b0000000-0000-4000-8000-000000003302', 'minor', 'HACK', 'HACK', 'x', current_date, true, false)$s$,
    $s$update public.interaction_rules set is_verified = false$s$,
    $s$delete from public.interaction_rules$s$
  ];
begin
  foreach stmt in array stmts loop
    begin
      execute stmt;
      raise exception '5.1d BAŞARISIZ: istemci katalogu değiştirebildi: %', stmt;
    exception when insufficient_privilege then null;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 5.2) check_drug_risk başka hastanın verisini sızdırmıyor
-- ---------------------------------------------------------------------------
-- Hâlâ hasta A. B'nin listesindeki Z, A'nın sonucunu ETKİLEMEMELİ.
do $$ declare r jsonb; begin
  r := public.check_drug_risk('99970000000042');            -- Z başka marka
  assert r->>'status' = 'not_evaluated' and not (r->>'same_ingredient')::boolean,
    format('5.2a: A için Z, B''nin listesinden same_ingredient üretmemeli; gelen %s', r);
  assert position('TEST K Ürün Z (B listesinde)' in r::text) = 0
     and position('0000000033b1' in r::text) = 0,
    format('5.2b: yanıt B''nin ürün adını veya kimliğini içermemeli; gelen %s', r);

  r := public.check_drug_risk('99970000000028');            -- V: kural yalnızca B'nin Z'siyle
  assert r->>'status' = 'not_evaluated',
    format('5.2c: A için V, B''nin ilacıyla risk_found üretmemeli; gelen %s', r);

  assert (select count(*) from public.patient_medications
          where patient_id = '00000000-0000-4000-8000-0000000033b1') = 0,
    '5.2d: hasta A, hasta B''nin ilaç listesini görmemeli';
end $$;

-- Pozitif kontrol: aynı kontroller B için çalışıyor (test gerçekten bir şey ölçüyor).
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000033b1","role":"authenticated"}', true);
do $$ declare r jsonb; begin
  r := public.check_drug_risk('99970000000042');
  assert r->>'status' = 'same_ingredient',
    format('5.2e: B için Z başka marka same_ingredient olmalı; gelen %s', r);

  r := public.check_drug_risk('99970000000028');
  assert r->>'status' = 'risk_found' and r->>'severity' = 'major',
    format('5.2f: B için V risk_found/major olmalı; gelen %s', r);

  assert (select count(*) from public.patient_medications
          where patient_id = '00000000-0000-4000-8000-0000000033a1') = 0,
    '5.2g: hasta B, hasta A''nın ilaç listesini görmemeli';
end $$;

-- ---------------------------------------------------------------------------
-- 5.3) anon — katalogu okuyamaz
-- ---------------------------------------------------------------------------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare
  t text;
begin
  foreach t in array array['products','ingredients','product_ingredients'] loop
    begin
      execute format('select count(*) from public.%I', t);
      raise exception '5.3 BAŞARISIZ: anon %s tablosunu okuyabildi', t;
    exception when insufficient_privilege then null;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 5.4) Değiştirme denemelerinden sonra katalog aynı kaldı
-- ---------------------------------------------------------------------------
reset role;
do $$ begin
  assert (select display_name from public.products where gtin = '99970000000011') = 'TEST K Ürün X',
    '5.4a: ürün adı değişmemeli';
  assert (select count(*) from public.product_ingredients where product_gtin like '9997%') = 4,
    '5.4b: bağlantı sayısı değişmemeli';
  assert (select count(*) from public.interaction_rules
          where ingredient_a_id = 'b0000000-0000-4000-8000-000000003302' and is_verified) = 1,
    '5.4c: etkileşim kuralı değişmemeli';
end $$;

select 'KATALOG SENARYOLARI GEÇTİ' as sonuc;

rollback;
