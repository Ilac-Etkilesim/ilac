-- SPRINT 2 / TASLAK. 20261021_001_initial_draft.sql'den SONRA uygulanır.
-- Canlı ortamda çalıştırmadan önce Metehan + Eray incelemeli; ekip onayı gerekir.
-- Kapsam: #15 (patient_medications sütun yetkisi), #16 (dose_events aynı gün kuralı,
--         hem update hem insert tarafı — Melike incelemesinde insert açığı bulundu),
--         #23 (gerçek katalog: product_ingredients, atc, needs_review),
--         #17 (check_drug_risk: same_ingredient + çok etken maddeli ürünler).

-- ---------------------------------------------------------------------------
-- #15 — patient_medications: güncelleme yalnızca belirli sütunlarda
-- product_gtin yalnızca insert ile belirlenir; mevcut kayıtta başka ilaca
-- çevrilemez (aksi hâlde yeni ilaç tarama/etkileşim akışını atlardı).
-- ---------------------------------------------------------------------------
revoke update on public.patient_medications from authenticated;
grant update (active, dose_label, scheduled_time)
  on public.patient_medications to authenticated;

-- ---------------------------------------------------------------------------
-- #16 — dose_events: yalnızca bugünün (Türkiye saati) dozu değiştirilebilir
-- Ekip kararı: "aynı gün izin" (yanlış basışı düzeltme imkânı kalır).
-- Değişiklik updated_at ile işaretlenir; yakın tarafı "sonradan değiştirildi"
-- bilgisini bu sütundan gösterebilir.
-- ---------------------------------------------------------------------------
alter table public.dose_events
  add column if not exists updated_at timestamptz;

create or replace function public.mark_dose_event_change()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if new.status is distinct from old.status then
    new.updated_at := now();
  end if;
  return new;
end;
$$;
drop trigger if exists trg_mark_dose_event_change on public.dose_events;
create trigger trg_mark_dose_event_change
before update on public.dose_events
for each row execute function public.mark_dose_event_change();

drop policy if exists dose_events_update_own on public.dose_events;
create policy dose_events_update_own on public.dose_events
  for update to authenticated
  using (
    patient_id = auth.uid()
    and scheduled_date = (now() at time zone 'Europe/Istanbul')::date
  )
  with check (
    patient_id = auth.uid()
    and scheduled_date = (now() at time zone 'Europe/Istanbul')::date
  );

-- Yalnızca durum değiştirilebilir; tarih, ilaç ve hasta sütunları sabit.
revoke update on public.dose_events from authenticated;
grant update (status) on public.dose_events to authenticated;

-- #16 devamı — update kısıtı tek başına yetmiyor: client aynı kısıtı aşıp
-- geçmiş bir tarih için YENİ bir doz kaydı (insert) açarak sahte geçmiş
-- oluşturabilirdi. Insert'i de bugüne kısıtlıyoruz, update ile tutarlı.
drop policy if exists dose_events_write_own on public.dose_events;
create policy dose_events_write_own on public.dose_events
  for insert to authenticated
  with check (
    patient_id = auth.uid()
    and scheduled_date = (now() at time zone 'Europe/Istanbul')::date
  );

-- ---------------------------------------------------------------------------
-- #23 — Gerçek katalog şeması (Ali'nin TİTCK ETL çıktısıyla uyumlu, PR #22)
-- Yükleme sırası: ingredients.csv → products.csv → product_ingredients.csv
-- ---------------------------------------------------------------------------
alter table public.ingredients
  add column if not exists display_name text,
  add column if not exists atc_codes text[] not null default '{}',
  add column if not exists needs_review boolean not null default false,
  add column if not exists review_reason text;
-- normalized_name üzerindeki unique kısıtı bilinçli olarak korunuyor.

alter table public.products
  alter column ingredient_id drop not null,
  add column if not exists atc_code text,
  add column if not exists license_status text;
-- products.ingredient_id artık eski (tek etken maddeli) alan; check_drug_risk()
-- yalnızca product_ingredients'ı kullanır. İleride kaldırılabilir.

create table if not exists public.product_ingredients (
  product_gtin text not null references public.products(gtin) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id),
  primary key (product_gtin, ingredient_id)
);
create index if not exists product_ingredients_ingredient_idx
  on public.product_ingredients(ingredient_id);

alter table public.product_ingredients enable row level security;
create policy product_ingredients_read on public.product_ingredients
  for select to authenticated using (true);
revoke all on public.product_ingredients from anon, authenticated;
grant select on public.product_ingredients to authenticated;

-- Mevcut tek etken maddeli ürünleri (ör. demo seed) yeni tabloya taşı.
insert into public.product_ingredients (product_gtin, ingredient_id)
select gtin, ingredient_id from public.products
where ingredient_id is not null
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- #17 + #23 — check_drug_risk(): tüm etken maddeler + same_ingredient
-- Dönüş durumları:
--   product_not_found | demo_only | not_evaluated | same_ingredient | risk_found
-- Her yanıtta "same_ingredient" (bool) ve "needs_review" (bool) alanları var;
-- etkileşim bulunsa bile aynı etken madde uyarısı kaybolmaz.
-- ---------------------------------------------------------------------------
create or replace function public.check_drug_risk(p_gtin text)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  v_candidate public.products%rowtype;
  v_ingredients uuid[];
  v_needs_review boolean;
  v_same record;
  v_risk record;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_candidate from public.products where gtin = p_gtin;
  if not found then
    return jsonb_build_object('status','product_not_found');
  end if;

  if v_candidate.is_demo then
    return jsonb_build_object('status','demo_only', 'gtin',p_gtin);
  end if;

  select array_agg(pi.ingredient_id), coalesce(bool_or(i.needs_review), false)
  into v_ingredients, v_needs_review
  from public.product_ingredients pi
  join public.ingredients i on i.id = pi.ingredient_id
  where pi.product_gtin = p_gtin;

  if v_ingredients is null then
    return jsonb_build_object('status','not_evaluated',
      'reason','Ürünün etken maddesi kayıtlı değil; kontrol tamamlanamadı',
      'same_ingredient', false, 'needs_review', false);
  end if;

  -- #17: aynı etken madde hastanın aktif ilaçlarında zaten var mı?
  select i.display_name, i.normalized_name, p.display_name as product_name
  into v_same
  from public.patient_medications pm
  join public.products p on p.gtin = pm.product_gtin
  join public.product_ingredients pi on pi.product_gtin = pm.product_gtin
  join public.ingredients i on i.id = pi.ingredient_id
  where pm.patient_id = auth.uid()
    and pm.active and not p.is_demo
    and pi.ingredient_id = any(v_ingredients)
  limit 1;

  -- Etkileşim: aday ürünün HER etken maddesi × mevcut ilaçların HER etken maddesi
  select r.severity, r.explanation, r.source_name
  into v_risk
  from public.patient_medications pm
  join public.products p on p.gtin = pm.product_gtin
  join public.product_ingredients pi on pi.product_gtin = pm.product_gtin
  join public.interaction_rules r
    on (r.ingredient_a_id = pi.ingredient_id and r.ingredient_b_id = any(v_ingredients))
    or (r.ingredient_b_id = pi.ingredient_id and r.ingredient_a_id = any(v_ingredients))
  where pm.patient_id = auth.uid()
    and pm.active and not p.is_demo
    and r.is_verified and not r.is_demo
  order by case r.severity when 'major' then 1
                           when 'moderate' then 2 else 3 end
  limit 1;

  if v_risk.severity is not null then
    return jsonb_build_object(
      'status', 'risk_found',
      'severity', v_risk.severity,
      'explanation', v_risk.explanation,
      'source', v_risk.source_name,
      'same_ingredient', v_same.normalized_name is not null,
      'needs_review', v_needs_review
    );
  end if;

  if v_same.normalized_name is not null then
    return jsonb_build_object(
      'status', 'same_ingredient',
      'ingredient', coalesce(v_same.display_name, v_same.normalized_name),
      'existing_product', v_same.product_name,
      'message', 'Aynı etken madde zaten listenizde. Eczacınıza danışın.',
      'same_ingredient', true,
      'needs_review', v_needs_review
    );
  end if;

  return jsonb_build_object('status','not_evaluated',
    'reason','Kayıt yokluğu güvenlik kanıtı değildir',
    'same_ingredient', false, 'needs_review', v_needs_review);
end;
$$;

revoke all on function public.check_drug_risk(text) from public, anon;
grant execute on function public.check_drug_risk(text) to authenticated;
