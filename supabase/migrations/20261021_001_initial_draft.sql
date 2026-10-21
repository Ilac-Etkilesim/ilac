-- SPRINT 0 / TASLAK. Canlı ortamda çalıştırmadan önce Metehan + Ahmet incelemeli.
-- Gerçek ilaç verisi, tıbbi onay veya çalışan aile daveti içermez.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.ingredients (
  id uuid primary key default gen_random_uuid(),
  normalized_name text not null unique
);

create table if not exists public.products (
  gtin text primary key check (gtin ~ '^[0-9]{14}$'),
  display_name text not null,
  ingredient_id uuid not null references public.ingredients(id),
  is_demo boolean not null default true,
  data_source text,
  created_at timestamptz not null default now()
);

create table if not exists public.patient_medications (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  product_gtin text not null references public.products(gtin),
  dose_label text not null,
  scheduled_time time not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists patient_medications_patient_idx
  on public.patient_medications(patient_id, active);

create table if not exists public.dose_events (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  patient_medication_id uuid not null references public.patient_medications(id) on delete cascade,
  scheduled_date date not null,
  status text not null check (status in ('taken', 'skipped')),
  confirmed_at timestamptz not null default now(),
  unique (patient_medication_id, scheduled_date)
);
create index if not exists dose_events_patient_date_idx
  on public.dose_events(patient_id, scheduled_date desc);

create or replace function public.validate_dose_owner()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not exists (
    select 1 from public.patient_medications m
    where m.id = new.patient_medication_id
      and m.patient_id = new.patient_id
  ) then
    raise exception 'Dose medication and patient mismatch';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_validate_dose_owner on public.dose_events;
create trigger trg_validate_dose_owner
before insert or update of patient_id, patient_medication_id
on public.dose_events
for each row execute function public.validate_dose_owner();

-- Davet/bağlama akışı henüz geliştirilmiyor:
-- Bu tablonun client INSERT yetkisi YOK; gelecekte güvenli server akışı gerekli.
create table if not exists public.caregiver_links (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  caregiver_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'revoked')),
  created_at timestamptz not null default now(),
  unique (patient_id, caregiver_id),
  check (patient_id <> caregiver_id)
);

create table if not exists public.interaction_rules (
  id uuid primary key default gen_random_uuid(),
  ingredient_a_id uuid not null references public.ingredients(id),
  ingredient_b_id uuid not null references public.ingredients(id),
  severity text not null check (severity in ('major', 'moderate', 'minor')),
  explanation text not null,
  source_name text not null,
  source_reference text,
  verified_on date,
  is_verified boolean not null default false,
  is_demo boolean not null default true,
  check (ingredient_a_id <> ingredient_b_id)
);
create index if not exists rules_pair_idx
  on public.interaction_rules(ingredient_a_id, ingredient_b_id);

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  caregiver_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('major_interaction', 'unconfirmed_dose')),
  safe_message text not null,
  created_at timestamptz not null default now()
);
create index if not exists alerts_caregiver_date_idx
  on public.alerts(caregiver_id, created_at desc);

-- RLS helper: sadece hastanın kendisi veya bağlantısı aktif yakın okuyabilir.
create or replace function public.can_view_patient(target_patient_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp as $$
  select auth.uid() is not null
    and (
      auth.uid() = target_patient_id
      or exists (
        select 1 from public.caregiver_links cl
        where cl.patient_id = target_patient_id
          and cl.caregiver_id = auth.uid()
          and cl.status = 'active'
      )
    );
$$;

alter table public.profiles enable row level security;
alter table public.ingredients enable row level security;
alter table public.products enable row level security;
alter table public.patient_medications enable row level security;
alter table public.dose_events enable row level security;
alter table public.caregiver_links enable row level security;
alter table public.interaction_rules enable row level security;
alter table public.alerts enable row level security;

create policy profiles_read_own_or_linked on public.profiles
  for select to authenticated using (public.can_view_patient(id));
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy ingredients_read on public.ingredients
  for select to authenticated using (true);
create policy products_read on public.products
  for select to authenticated using (true);

create policy patient_medications_read on public.patient_medications
  for select to authenticated using (public.can_view_patient(patient_id));
create policy patient_medications_insert_own on public.patient_medications
  for insert to authenticated with check (patient_id = auth.uid());
create policy patient_medications_update_own on public.patient_medications
  for update to authenticated using (patient_id = auth.uid())
  with check (patient_id = auth.uid());
create policy patient_medications_delete_own on public.patient_medications
  for delete to authenticated using (patient_id = auth.uid());

create policy dose_events_read on public.dose_events
  for select to authenticated using (public.can_view_patient(patient_id));
create policy dose_events_write_own on public.dose_events
  for insert to authenticated with check (patient_id = auth.uid());
create policy dose_events_update_own on public.dose_events
  for update to authenticated using (patient_id = auth.uid())
  with check (patient_id = auth.uid());

create policy caregiver_links_read on public.caregiver_links
  for select to authenticated using (
    patient_id = auth.uid() or caregiver_id = auth.uid()
  );
create policy alerts_read on public.alerts
  for select to authenticated using (
    patient_id = auth.uid()
    or (caregiver_id = auth.uid() and public.can_view_patient(patient_id))
  );

-- Yetki sınırları: Client katalogu / kuralları / olayları değiştiremez.
revoke all on public.profiles, public.ingredients, public.products,
  public.patient_medications, public.dose_events, public.caregiver_links,
  public.interaction_rules, public.alerts from anon, authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select on public.ingredients, public.products to authenticated;
grant select, insert, update, delete on public.patient_medications to authenticated;
grant select, insert, update on public.dose_events to authenticated;
grant select on public.caregiver_links, public.alerts to authenticated;

-- Taslak sorgu: hiçbir eşleşmenin bulunmaması "güvenli" değildir.
-- Yalnızca giriş yapan hastanın kendisi tarama yapabilir.
create or replace function public.check_drug_risk(p_gtin text)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  v_candidate public.products%rowtype;
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

  select r.severity, r.explanation, r.source_name
  into v_risk
  from public.patient_medications pm
  join public.products p on p.gtin = pm.product_gtin
  join public.interaction_rules r
    on (
      (r.ingredient_a_id = p.ingredient_id and r.ingredient_b_id = v_candidate.ingredient_id)
      or (r.ingredient_b_id = p.ingredient_id and r.ingredient_a_id = v_candidate.ingredient_id)
    )
  where pm.patient_id = auth.uid()
    and pm.active and not p.is_demo
    and r.is_verified and not r.is_demo
  order by case r.severity when 'major' then 1
                           when 'moderate' then 2 else 3 end
  limit 1;

  if found then
    return jsonb_build_object(
      'status', 'risk_found',
      'severity', v_risk.severity,
      'explanation', v_risk.explanation,
      'source', v_risk.source_name
    );
  end if;

  return jsonb_build_object('status','not_evaluated',
    'reason','Kayıt yokluğu güvenlik kanıtı değildir');
end;
$$;

revoke all on function public.can_view_patient(uuid) from public, anon;
grant execute on function public.can_view_patient(uuid) to authenticated;
revoke all on function public.check_drug_risk(text) from public, anon;
grant execute on function public.check_drug_risk(text) to authenticated;

-- TODO: Yetki penetrasyon testleri, iki taraflı davet onayı, veri lisansı,
-- güvenli FCM sunucu fonksiyonu, içerik doğrulaması, log retansiyonu.
