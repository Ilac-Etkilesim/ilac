# Haftalık Liderlik Raporu — Sprint 1

**Dönem:** 21–27 Ekim 2026 · **Sprint:** 1 ("projenin kemiği") · **Lider:** Melike
**Depo:** https://github.com/Ilac-Etkilesim/ilac · **Rapor tarihi:** 27 Ekim 2026

---

## 1. Yönetici özeti

Bu hafta proje, "ZIP içinde test edilmemiş kod" halinden **çalışan, sürekli denetlenen bir yazılım projesine** geçti. GitHub deposu kuruldu ve korumaya alındı, her PR'da otomatik analiz+test devreye girdi, dört PR `dev` dalına birleşti. Uygulama **ilk kez gerçekten çalıştırıldı** (Android emülatörü) ve bu denemede, testlerin yakalayamadığı bir derleme engeli bulunup düzeltildi.

Sekiz üyeden üçü (Eray, Afra, Metehan) görevlerini tamamladı. İki üyenin görevi (Ali, Gizem) müsaitlik/erişim sorunları nedeniyle istisnai olarak lider tarafından üstlenildi. İki üye (Merve, Ahmet) bu hafta hiç başlamadı; Ahmet GitHub davetini kabul etmediği için teknik olarak bloke.

**Sprint 1'in altyapı hedefleri tamamlandı; ekip katılımı hedefin gerisinde kaldı.**

---

## 2. Hedef ve gerçekleşme

Sprint 1 hedefi (`docs/06`): *"Repo/CI/Issue akışı oturdu, demo veri + RLS ön incelemesi tamam, cihaz testleri netleşti."*

| Hedef | Durum | Kanıt |
|---|---|---|
| Repo / dal yapısı / koruma | ✅ Tamamlandı | `main` korumalı (PR zorunlu, force-push kapalı) |
| CI (her PR'da analyze+test) | ✅ Tamamlandı | 8 CI çalışması, 8'i de başarılı |
| Issue akışı | ✅ Tamamlandı | 17 Issue açıldı, 2'si kapandı |
| Demo veri (seed) | ✅ Tamamlandı | PR #11, 10 ürün / 8 etken madde / 4 kural |
| RLS ön incelemesi | 🟡 Kısmi | Eray + Metehan yaptı; **Ahmet'in çapraz kontrolü eksik** |
| Cihaz testleri netleşti | 🟡 Kısmi | Emülatörde doğrulandı; **gerçek telefonda kamera testi yapılmadı** |

---

## 3. Ölçülebilir çıktılar

| Gösterge | Hafta başı | Hafta sonu |
|---|---|---|
| `dev` dalındaki dosya | 1 (yalnızca README) | 100 |
| Otomatik test | 0 (çalıştırılmamış) | 12 (hepsi geçiyor) |
| Birleşen PR | 0 | 4 |
| Açık/kapalı Issue | 0 | 17 açıldı, 2 kapandı |
| CI | yok | devrede, 8/8 başarılı |
| Kod satırı (lib+test+supabase+tools) | — | ~1.150 |
| Uygulamanın cihazda çalışması | denenmemiş | ✅ Android 35 emülatöründe uçtan uca |

---

## 4. Kişi bazında durum

| Kişi | Görev | Durum | Kanıt |
|---|---|---|---|
| **Eray** | #6 CI otomasyonu + RLS masaüstü incelemesi | ✅ Tamamlandı | PR #13 (+73), `docs/10`, CI yeşil |
| **Afra** | #8 Doz onaylarının cihazda kalıcı hale getirilmesi | ✅ Tamamlandı | PR #12 (+108/−4), 2 yeni test |
| **Metehan** | #4 PR #11 incelemesi + Eray'ın RLS notuna teknik görüş | ✅ Tamamlandı | PR #11 onayı (4 öneri), Issue #6 yorumu (6 ek bulgu) |
| **Ali** | #2 Demo veri + gerçek veri kaynağı | 🟡 Devralındı | Seed PR #11'de (lider yaptı); **lisans teyidi Ali'de** (`docs/12`, 5 adım) |
| **Gizem** | #7 Elle GTIN girişi / kamera testi | 🟡 Devralındı | Elle giriş PR #14'te (lider yaptı, onaylı); **kamera testi açık** |
| **Merve** | #9 Zamanlanmış demo bildirim | ❌ Başlamadı | PR yok, Issue yorumu yok |
| **Ahmet** | #3 RLS çapraz kontrolü | ❌ Başlamadı | GitHub daveti kabul edilmedi |
| **Melike** | #4 liderlik, #10 sonuç raporu | 🟡 Devam | 4 PR incelendi/birleştirildi, 2 görev devralındı, sunum; **#10 raporu bu belge** |

---

## 5. Bu hafta alınan kararlar

1. **Melike Sprint 1'i de yönetti (istisna).** Gerekçe: Hafta 1 tanıtım/ortam kurulumu olarak geçti, gerçek sprint sayılmadı. Rotasyon Sprint 2'den Metehan ile devam edecek; plan 12 → 13 haftaya uzadı (`docs/02`, `docs/06` güncellendi).
2. **Ali ve Gizem'in görevlerinin kritik kısmı lider tarafından üstlenildi (istisna).** Gerekçe: veri seed'i Sprint 2 ve 3'ü bloke ediyordu; Gizem'in GitHub erişimi yok. Kalan kısımlar (lisans araştırması, kamera testi) sahiplerinde bırakıldı.
3. **Cihaz testi emülatöre taşındı, kamera testi hariç.** Emülatörün kamerası gerçek olmadığı için DataMatrix okuma testi "doğrulanamadı" olarak kaldı; bu ayrım Issue #7'ye yazıldı.
4. **Demo veriyle etkileşim uyarısı gösterilmeyecek.** `check_drug_risk()` doğrulanmamış veride `demo_only` döner; bu bilinçli güvenlik tasarımı korunuyor. "Demo modu" ayrı bir ekip kararı olarak bekletiliyor (Metehan artı/eksi görüşünü PR #11'e yazdı).
5. **Gerçek veri için ön araştırma yapıldı.** Önerilen yol: TİTCK ruhsatlı ürünler + e-reçete listeleri (GTIN/etken madde), ATC kodu (normalizasyon), ONC High Priority listesi (etkileşim). Lisans teyidi alınmadan hiçbiri kullanılmayacak (`docs/12`).

---

## 6. Bu hafta bulunan riskler

| # | Bulgu | Önem | Durum |
|---|---|---|---|
| 1 | **Uygulama Android için hiç derlenmiyormuş** — `flutter_local_notifications` core library desugaring istiyor; `analyze`/`test` bunu yakalamadığı için CI da yeşil görünüyordu | 🔴 Yüksek | Düzeltildi, PR #18 incelemede |
| 2 | Hasta, mevcut ilaç kaydının `product_gtin`'ini değiştirebiliyor → tarama/etkileşim akışı atlanabilir | 🟠 Orta | Issue #15 (Sprint 2 adayı) |
| 3 | Doz geçmişi geriye dönük değiştirilebiliyor → yakının gördüğü uyum geçmişi güvenilmez | 🟠 Orta | Issue #16 (Sprint 2 adayı) |
| 4 | Aynı etken maddenin iki farklı ürünle tekrarı (çift doz riski) hiçbir kuralla yakalanmıyor | 🟠 Orta | Issue #17 (Sprint 2 adayı) |
| 5 | Hasta, yakınının erişimini uygulamadan iptal edemiyor (`caregiver_links` istemciye kapalı) | 🟠 Orta | Eray'ın notu, `docs/10`; davet akışı tasarımında ele alınacak |
| 6 | Gerçek ilaç verisinin lisans durumu belirsiz (TİTCK dosyalarında kullanım notu yok) | 🟠 Orta | `docs/12`; Ali yazılı izin isteyecek |

*Önceki 8 risk (branch koruması, bildirim izni, GTIN sınır hatası, SQL cascade vb.) bu hafta giderildi.*

---

## 7. Engeller

| Engel | Etkilediği | Çözüm sorumlusu |
|---|---|---|
| Fiziksel Android telefon yok | Gizem (kamera/DataMatrix testi) | Ekip — tek oturum planlanmalı |
| Gizem'in GitHub kullanıcı adı alınamadı | Gizem'in tüm katkısı | Melike (bilgi geldiğinde davet) |
| Ali ve Ahmet davetleri kabul edilmedi | Ahmet bloke, Ali kısmen | Ali, Ahmet (kabul etmeleri yeterli) |
| Merve'den geri dönüş yok | #9 | Melike (iletişim) |
| PR #18 incelenmedi | Herkesin cihazda derlemesi | Eray |

---

## 8. Sonraki hafta (Sprint 2) planı ve devir

**Devralan lider:** Metehan. Devir notları:

1. **Önce PR #18 birleşsin** — bu olmadan kimse uygulamayı cihazda derleyemez.
2. PR #14 (elle GTIN girişi) onaylı, birleştirilmeye hazır.
3. Sprint 2 hedefi (`docs/06`): Auth + RLS kullanıcı testleri + mobil giriş. Dev Supabase kurulumu Issue #5'te tanımlı, plan Metehan'da.
4. Devralınan görevlerin kalan kısmı sahiplerine iade: Ali → veri lisansı (`docs/12`), Gizem → kamera testi.
5. Açık Sprint 2 adayı bulgular: #15, #16, #17 — Metehan ve Ahmet önceliklendirecek.
6. Ahmet'in RLS çapraz kontrolü (#3) hâlâ açık; Eray'ın notuyla karşılaştırma yapılmadı.
7. Öneri: CI'a `flutter build apk --debug` adımı eklenerek 1 numaralı riskin tekrarı önlensin.

---

## 9. Ekler (doğrulanabilir kanıtlar)

- Birleşen PR'lar: #1, #11, #12, #13 · Açık PR'lar: #14 (onaylı), #18 (inceleme bekliyor)
- Teknik dokümanlar: `docs/10` (Eray RLS), `docs/11` (demo veri sınırları), `docs/12` (gerçek veri kaynakları)
- Veri: `supabase/seed/demo_seed.sql`, `data/demo_products.csv`, `tools/check_demo_seed.py`
- Cihaz kanıtı: Android 35 emülatöründe ana ekran, doz onayı (`taken_2026-10-27`), kamera izni, elle GTIN girişi (`99990000000008`), bildirim — ekran görüntüleri sunumda
- Sunum: Sprint 0+1 durum sunumu (17 slayt)

**Tıbbi sınır hatırlatması:** Bu haftaki tüm veriler DEMO/kurgusaldır. Uygulama hiçbir aşamada "kesin güvenli" veya "ilaç alınmadı" ifadesi kullanmamaktadır; onaylanmamış dozlar "onay bekliyor" olarak gösterilir.
