-- SPRINT 3 / TASLAK. 20261102_002_sprint2_rls_and_catalog.sql'den SONRA uygulanır.
-- Canlı ortamda çalıştırmadan önce Metehan + Eray incelemeli; ekip onayı gerekir.
--
-- NEDEN GEREKLİ
-- -----------------------------------------------------------------------------
-- 001'de public.profiles tablosu auth.users'a bağlı, ancak bu tabloyu dolduran
-- hiçbir şey yok: ne bir trigger var, ne de Flutter tarafı profiles'a yazıyor
-- (lib/ içinde profiles'a hiç dokunulmuyor — 23 Kasım 2026 incelemesi).
--
-- Sonuç: Afra'nın giriş ekranından (#24, PR #27) kayıt olan gerçek bir kullanıcı
-- auth.users'ta var ama public.profiles'ta YOK. Bu durumda:
--   * patient_medications insert'i foreign key'den patlar,
--   * dose_events yazılamaz (doz onayı sunucuya taşınamaz),
--   * can_view_patient() üzerinden kurulan tüm RLS zinciri boşta kalır.
--
-- Bu dosya eksik halkayı kapatır: her yeni auth kullanıcısı için profiles
-- satırı otomatik oluşturulur.
--
-- GÜVENLİK NOTU
-- -----------------------------------------------------------------------------
-- Trigger security definer'dır (auth şemasına yazamayan rol adına çalışır),
-- ancak search_path sabitlenmiştir ve yalnızca kendi satırını ekler.
-- İstemci tarafı profiles_insert_own politikası (001) korunur; bu trigger onun
-- yerine geçmez, yalnızca kullanıcı hiçbir şey yapmadan da kaydın oluşmasını
-- garanti eder.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    -- Kayıt sırasında ad verilmemişse e-postanın @ öncesi kısmı kullanılır.
    -- Gerçek ad değildir; kullanıcı sonradan güncelleyebilir (profiles_update_own).
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1),
      ''
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Trigger'dan ÖNCE oluşturulmuş kullanıcılar için telafi:
-- auth.users'ta olup profiles'ta olmayan herkese satır açılır.
-- Tekrar çalıştırılabilir (idempotent).
insert into public.profiles (id, display_name)
select u.id,
       coalesce(
         nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''),
         split_part(coalesce(u.email, ''), '@', 1),
         ''
       )
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;

-- Fonksiyon yalnızca trigger üzerinden çalışmalı; istemciye açılmaz.
revoke all on function public.handle_new_user() from public, anon, authenticated;
