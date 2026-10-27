# Metehan — RLS taslağı teknik görüşü (Issue #6, 27 Ekim 2026)

> Şema sahibi olarak Eray'ın `docs/10_RLS_INCELEME_ERAY.md` notuna verilen görüş. GitHub Issue #6 yorumundan alınmıştır.

Teknik görüş: docs/10_RLS_INCELEME_ERAY.md (şema sahibi Metehan) — Karar: Onay. Notu migration ile satır satır karşılaştırdım (20261021_001_initial_draft.sql, dev); a/b/c senaryolarının sonuçları ve 5 risk maddesi doğru. Aşağıdakiler nota ek olarak düşülmeli.

Doğrulananlar:

(a) Hasta kendi kayıtlarını görüyor: profiles (s.139), patient_medications (s.151), dose_events (s.161), alerts (s.173) → doğru.
(b) Aktif yakın okuyabiliyor ama yazamıyor: insert/update policy'leri patient_id = auth.uid() arıyor (s.153–167) → doğru.
(c) pending/revoked yakın hasta verisini göremiyor; yalnızca bağlantı satırını görüyor (s.169) → doğru.
Risk 1 (bağlantı istemciden değiştirilemiyor) ve risk 2 (hasta yakınının profilini göremiyor) şemayla birebir uyumlu.
Notta olmayan ekler:

patient_medications güncellemesi sütun bazında kısıtlı değil (s.155, grant s.186): Hasta mevcut bir kaydın product_gtin değerini değiştirebilir. Böylece yeni ilaç, tarama/etkileşim akışından geçmeden listeye girer. Öneri: grant update (active, dose_label, scheduled_time) gibi sütun bazlı yetki.
dose_events geriye dönük değiştirilebiliyor (s.165): Hasta geçmiş bir dozu taken ↔ skipped yapabilir ve yakın değiştirilmiş geçmişi görür. Uyum geçmişinin güvenilirliği için update yetkisini kaldırmak ya da yalnızca aynı gün içinde izin vermek tartışılmalı.
interaction_rules'a istemci erişimi hiç yok (RLS açık, policy ve grant yok): Bu doğru bir tercih. Kurallar yalnızca security definer olan check_drug_risk() üzerinden okunuyor. Notta açıkça yazılırsa ileride biri "okuma policy'si unutulmuş" diye ekleyip kataloğu açmaz.
can_view_patient() security definer (s.116): caregiver_links üzerindeki RLS'yi atlayarak okuyor. Bu, policy'lerin birbirini çağırıp döngüye girmesini önlüyor, doğru. Ancak fonksiyonun sahibi canlıda postgres olmalı; migration uygulanırken kontrol edilmeli.
check_drug_risk() yalnızca auth.uid() ile çalışıyor (s.222): Yakın, hasta adına tarama yapamaz. Bu bir eksik değil, ama "yakın ilaç ekler" senaryosu düşünülüyorsa ayrı karar gerekir.
Performans (küçük): Supabase, policy'lerde auth.uid() yerine (select auth.uid()) yazılmasını öneriyor; satır başına tekrar hesaplamayı önler. Sprint 2'de düzeltilebilir.
Canlı doğrulama için önerim: Riskler 1–2 ve ekler 1–2 için Sprint 2'de geliştirme projesinde 3 test kullanıcısıyla (hasta, aktif yakın, revoked yakın) yetki testleri yazalım; sonuçlar Issue #6'ya eklensin.
