-- =============================================================================
-- RLS + check_drug_risk() SENARYO TESTLERİ (Issue #5, #15, #16, #17, #23)
-- =============================================================================
-- * Yalnızca GELİŞTİRME Supabase projesinde, SQL Editor'de (postgres rolüyle)
--   001 ve 002 migration'ları uygulandıktan SONRA çalıştırılır.
-- * Her şey tek transaction içinde yapılır ve sonda ROLLBACK edilir:
--   veritabanında hiçbir test kullanıcısı / veri KALMAZ.
-- * Bir assert başarısız olursa betik o noktada hata mesajıyla durur.
--   Sonda "TÜM SENARYOLAR GEÇTİ" görünüyorsa hepsi geçmiştir.
-- * Tüm adlar/UUID'ler kurgusaldır; gerçek hasta veya ilaç verisi yoktur.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0) Kurulum (postgres olarak, RLS'e takılmadan)
-- ---------------------------------------------------------------------------
-- Kullanıcılar: A = hasta, B = başka hasta, Y = aktif yakın, R = revoked yakın, P = pending yakın
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'test-hasta-a@example.invalid'),
  ('00000000-0000-4000-8000-0000000000b1', 'test-hasta-b@example.invalid'),
  ('00000000-0000-4000-8000-0000000000c1', 'test-yakin-aktif@example.invalid'),
  ('00000000-0000-4000-8000-0000000000d1', 'test-yakin-revoked@example.invalid'),
  ('00000000-0000-4000-8000-0000000000e1', 'test-yakin-pending@example.invalid');

insert into public.profiles (id, display_name) values
  ('00000000-0000-4000-8000-0000000000a1', 'TEST Hasta A'),
  ('00000000-0000-4000-8000-0000000000b1', 'TEST Hasta B'),
  ('00000000-0000-4000-8000-0000000000c1', 'TEST Yakın aktif'),
  ('00000000-0000-4000-8000-0000000000d1', 'TEST Yakın revoked'),
  ('00000000-0000-4000-8000-0000000000e1', 'TEST Yakın pending');

insert into public.caregiver_links (patient_id, caregiver_id, status) values
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000c1', 'active'),
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000d1', 'revoked'),
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000e1', 'pending');

-- Kurgusal, demo OLMAYAN mini katalog (check_drug_risk'in gerçek yolu için)
insert into public.ingredients (id, normalized_name, display_name) values
  ('b0000000-0000-4000-8000-000000000001', 'test_etken_x', 'TEST Etken X'),
  ('b0000000-0000-4000-8000-000000000002', 'test_etken_w', 'TEST Etken W'),
  ('b0000000-0000-4000-8000-000000000003', 'test_etken_z', 'TEST Etken Z');
insert into public.ingredients (id, normalized_name, needs_review, review_reason) values
  ('b0000000-0000-4000-8000-000000000004', 'test_etken_q', true, 'TEST: ad eşlemesi şüpheli');

insert into public.products (gtin, display_name, is_demo, data_source) values
  ('99980000000009', 'TEST Ürün X (listede)',        false, 'TEST'),
  ('99980000000016', 'TEST Ürün X (başka marka)',    false, 'TEST'),
  ('99980000000023', 'TEST Ürün W (etkileşimli)',    false, 'TEST'),
  ('99980000000030', 'TEST Ürün X+W (kombine)',      false, 'TEST'),
  ('99980000000047', 'TEST Ürün Z (kural yok)',      false, 'TEST'),
  ('99980000000054', 'TEST Ürün Q (inceleme gerek)', false, 'TEST'),
  ('99980000000061', 'TEST Ürün (etken maddesiz)',   false, 'TEST'),
  ('99980000000078', 'TEST DEMO ürün',               true,  'TEST');

insert into public.product_ingredients (product_gtin, ingredient_id) values
  ('99980000000009', 'b0000000-0000-4000-8000-000000000001'),
  ('99980000000016', 'b0000000-0000-4000-8000-000000000001'),
  ('99980000000023', 'b0000000-0000-4000-8000-000000000002'),
  ('99980000000030', 'b0000000-0000-4000-8000-000000000001'),
  ('99980000000030', 'b0000000-0000-4000-8000-000000000002'),
  ('99980000000047', 'b0000000-0000-4000-8000-000000000003'),
  ('99980000000054', 'b0000000-0000-4000-8000-000000000004'),
  ('99980000000078', 'b0000000-0000-4000-8000-000000000003');

-- Doğrulanmış (is_verified) ve demo olmayan tek kural: X × W = major
insert into public.interaction_rules
  (ingredient_a_id, ingredient_b_id, severity, explanation, source_name,
   source_reference, verified_on, is_verified, is_demo)
values
  ('b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'major',
   'TEST: X ve W temsili ciddi etkileşim.', 'TEST', 'test', current_date, true, false);

-- Hasta A: listede Ürün X; B: kendi ilacı
insert into public.patient_medications (id, patient_id, product_gtin, dose_label, scheduled_time) values
  ('c0000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000a1', '99980000000009', '1 tablet', '08:00'),
  ('c0000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000b1', '99980000000047', '1 tablet', '09:00');

-- A'nın dün ve bugün (Türkiye saati) doz onayları
insert into public.dose_events (id, patient_id, patient_medication_id, scheduled_date, status) values
  ('d0000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000a1',
   'c0000000-0000-4000-8000-000000000001', (now() at time zone 'Europe/Istanbul')::date - 1, 'taken'),
  ('d0000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000a1',
   'c0000000-0000-4000-8000-000000000001', (now() at time zone 'Europe/Istanbul')::date, 'taken');

insert into public.alerts (patient_id, caregiver_id, kind, safe_message) values
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000c1', 'unconfirmed_dose', 'TEST'),
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000d1', 'unconfirmed_dose', 'TEST');

-- ---------------------------------------------------------------------------
-- 1) Hasta A — kendi verisini görüyor, başkasınınkini görmüyor
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);

do $$ begin
  assert (select count(*) from public.patient_medications) = 1,
    '1a: hasta A yalnızca kendi 1 ilacını görmeli';
  assert (select count(*) from public.dose_events) = 2,
    '1b: hasta A kendi 2 doz kaydını görmeli';
  assert (select count(*) from public.profiles
          where id = '00000000-0000-4000-8000-0000000000b1') = 0,
    '1c: hasta A, hasta B''nin profilini görmemeli';
  assert (select count(*) from public.alerts) = 2,
    '1d: hasta A kendisiyle ilgili uyarıları görmeli';
end $$;

-- #15: product_gtin değiştirilemez, active/dose_label değiştirilebilir
do $$ begin
  begin
    update public.patient_medications set product_gtin = '99980000000023'
    where id = 'c0000000-0000-4000-8000-000000000001';
    raise exception '#15 BAŞARISIZ: product_gtin güncellenebildi';
  exception when insufficient_privilege then null;
  end;
end $$;
update public.patient_medications set dose_label = '1 tablet (tok)'
  where id = 'c0000000-0000-4000-8000-000000000001';
do $$ begin
  assert (select dose_label from public.patient_medications
          where id = 'c0000000-0000-4000-8000-000000000001') = '1 tablet (tok)',
    '#15: dose_label güncellenebilmeli';
end $$;

-- #16: dünün dozu değişmez (RLS satırı gizler → 0 satır), bugünün dozu değişir
update public.dose_events set status = 'skipped'
  where id = 'd0000000-0000-4000-8000-000000000001';
update public.dose_events set status = 'skipped'
  where id = 'd0000000-0000-4000-8000-000000000002';
do $$ begin
  assert (select status from public.dose_events
          where id = 'd0000000-0000-4000-8000-000000000001') = 'taken',
    '#16: dünün dozu değiştirilememeli';
  assert (select status from public.dose_events
          where id = 'd0000000-0000-4000-8000-000000000002') = 'skipped',
    '#16: bugünün dozu değiştirilebilmeli';
  assert (select updated_at from public.dose_events
          where id = 'd0000000-0000-4000-8000-000000000002') is not null,
    '#16: değişiklik updated_at ile işaretlenmeli';
end $$;
do $$ begin
  begin
    update public.dose_events set scheduled_date = scheduled_date - 1
    where id = 'd0000000-0000-4000-8000-000000000002';
    raise exception '#16 BAŞARISIZ: scheduled_date güncellenebildi';
  exception when insufficient_privilege then null;
  end;
end $$;

-- #17 + #23: check_drug_risk() sonuçları (hasta A'nın listesinde Ürün X var)
do $$ declare r jsonb; begin
  r := public.check_drug_risk('99980000000023');            -- W: X ile major
  assert r->>'status' = 'risk_found' and r->>'severity' = 'major',
    format('check_drug_risk W: risk_found/major beklendi, gelen %s', r);
  assert (r->>'same_ingredient')::boolean = false, 'W: same_ingredient false olmalı';

  r := public.check_drug_risk('99980000000016');            -- X başka marka
  assert r->>'status' = 'same_ingredient',
    format('check_drug_risk X(başka marka): same_ingredient beklendi, gelen %s', r);

  r := public.check_drug_risk('99980000000030');            -- X+W kombine
  assert r->>'status' = 'risk_found' and (r->>'same_ingredient')::boolean,
    format('check_drug_risk X+W: risk_found + same_ingredient beklendi, gelen %s', r);

  r := public.check_drug_risk('99980000000047');            -- Z: kural yok
  assert r->>'status' = 'not_evaluated',
    format('check_drug_risk Z: not_evaluated beklendi, gelen %s', r);

  r := public.check_drug_risk('99980000000054');            -- Q: inceleme gerekli
  assert r->>'status' = 'not_evaluated' and (r->>'needs_review')::boolean,
    format('check_drug_risk Q: needs_review=true beklendi, gelen %s', r);

  r := public.check_drug_risk('99980000000061');            -- etken maddesiz
  assert r->>'status' = 'not_evaluated' and r->>'reason' like '%kontrol tamamlanamadı%',
    format('check_drug_risk etken maddesiz: kontrol tamamlanamadı beklendi, gelen %s', r);

  r := public.check_drug_risk('99980000000078');            -- demo ürün
  assert r->>'status' = 'demo_only', format('demo ürün: demo_only beklendi, gelen %s', r);

  r := public.check_drug_risk('00000000000000');            -- olmayan ürün
  assert r->>'status' = 'product_not_found', format('product_not_found beklendi, gelen %s', r);
end $$;

-- ---------------------------------------------------------------------------
-- 2) Aktif yakın Y — okur, yazamaz
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);
do $$ begin
  assert (select count(*) from public.patient_medications) = 1,
    '2a: aktif yakın, hasta A''nın ilacını görmeli';
  assert (select count(*) from public.dose_events) = 2,
    '2b: aktif yakın, hasta A''nın doz kayıtlarını görmeli';
  assert (select count(*) from public.alerts) = 1,
    '2c: aktif yakın yalnızca kendisine gelen uyarıyı görmeli';
end $$;
update public.dose_events set status = 'taken'
  where id = 'd0000000-0000-4000-8000-000000000002';
do $$ begin
  assert (select status from public.dose_events
          where id = 'd0000000-0000-4000-8000-000000000002') = 'skipped',
    '2d: aktif yakın hastanın dozunu değiştirememeli';
end $$;

-- ---------------------------------------------------------------------------
-- 3) Revoked ve pending yakın — hasta verisini göremez
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
do $$ begin
  assert (select count(*) from public.patient_medications) = 0, '3a: revoked yakın ilaç görmemeli';
  assert (select count(*) from public.dose_events) = 0, '3b: revoked yakın doz görmemeli';
  assert (select count(*) from public.alerts) = 0, '3c: revoked yakın eski uyarıları görmemeli';
  assert (select count(*) from public.caregiver_links) = 1, '3d: revoked yakın yalnızca kendi bağlantı satırını görür';
end $$;

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000e1","role":"authenticated"}', true);
do $$ begin
  assert (select count(*) from public.patient_medications) = 0, '3e: pending yakın ilaç görmemeli';
  assert (select count(*) from public.profiles
          where id = '00000000-0000-4000-8000-0000000000a1') = 0, '3f: pending yakın hasta profilini görmemeli';
end $$;

-- ---------------------------------------------------------------------------
-- 4) Katalog: okunur, yazılamaz; kurallar istemciye kapalı; anon fonksiyonu çağıramaz
-- ---------------------------------------------------------------------------
do $$ begin
  assert (select count(*) from public.product_ingredients) >= 8, '4a: product_ingredients okunabilmeli';
  begin
    insert into public.product_ingredients values ('99980000000047', 'b0000000-0000-4000-8000-000000000001');
    raise exception '4b BAŞARISIZ: istemci product_ingredients''a yazabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    perform count(*) from public.interaction_rules;
    raise exception '4c BAŞARISIZ: istemci interaction_rules''ı okuyabildi';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  begin
    perform public.check_drug_risk('99980000000023');
    raise exception '4d BAŞARISIZ: anon check_drug_risk çağırabildi';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
select 'TÜM SENARYOLAR GEÇTİ' as sonuc;

rollback;
