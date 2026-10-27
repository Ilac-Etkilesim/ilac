# RLS Taslağı Masaüstü İncelemesi (Eray)

**İncelenen dosya:** `supabase/migrations/20261021_001_initial_draft.sql` (değiştirilmedi)
**İlgili Issue:** #6 · **Çapraz kontrol:** Ahmet (#3)
**Yöntem:** Statik inceleme. SQL yalnızca okundu, hiçbir sorgu çalıştırılmadı. Sonuçların canlı ortamda en az üç test kullanıcısıyla (hasta, aktif yakın, revoked yakın) ayrıca doğrulanması gerekiyor.

## Temel kural: `can_view_patient(target_patient_id)`
`true` döner ⇔ `auth.uid() is not null` **ve** (`auth.uid() = target_patient_id` **veya** `caregiver_links` tablosunda `patient_id = target_patient_id`, `caregiver_id = auth.uid()`, `status = 'active'` olan bir satır var).
8 tablonun hepsinde RLS açık; policy tanımlanmamış işlemler varsayılan olarak reddediliyor.

## Senaryolar (örnek: hasta A, yakın Y)

### (a) Hasta kendi kayıtlarını görebiliyor mu? → Geçer
| Tablo | Policy | Koşul | Sonuç |
|---|---|---|---|
| profiles | `profiles_read_own_or_linked` | `can_view_patient(id)` → `auth.uid() = id` | Geçer |
| patient_medications | `patient_medications_read` | `can_view_patient(patient_id)` → `auth.uid() = patient_id` | Geçer |
| dose_events | `dose_events_read` | `can_view_patient(patient_id)` → `auth.uid() = patient_id` | Geçer |
| alerts | `alerts_read` | `patient_id = auth.uid()` (fonksiyon kullanılmıyor) | Geçer |

### (b) `status = 'active'` olan yakın görebiliyor mu? → Geçer
| Tablo | Policy | Koşul | Sonuç |
|---|---|---|---|
| profiles | `profiles_read_own_or_linked` | `can_view_patient(A)` → aktif bağlantı var | Geçer |
| patient_medications | `patient_medications_read` | `can_view_patient(A)` → aktif bağlantı var | Geçer |
| dose_events | `dose_events_read` | `can_view_patient(A)` → aktif bağlantı var | Geçer |
| alerts | `alerts_read` | `caregiver_id = auth.uid()` **ve** `can_view_patient(A)` | Geçer (yalnızca kendisine gelen uyarılar) |

Yakının bu tablolara yazma yetkisi yok; insert/update policy'leri `patient_id = auth.uid()` şartını arıyor.

### (c) `pending` / `revoked` yakın görememeli → Geçer (erişim kapalı)
`can_view_patient(A)`: `auth.uid() = A` yanlış; `status = 'active'` sağlanmadığı için `exists` de yanlış → `false`.
- `profiles`, `patient_medications`, `dose_events`: satırlar gizli.
- `alerts`: `can_view_patient` şartı da arandığı için bağlantı `revoked` olunca yakın geçmişte kendisine gönderilmiş uyarıları da göremiyor.
- İstisna: `caregiver_links_read` (`patient_id = auth.uid() or caregiver_id = auth.uid()`) sayesinde yakın, bağlantı satırının kendisini (hasta UUID'si ve durum) görebiliyor; hasta verisini göremiyor.

## Riskler ve belirsizlikler
1. **Bağlantı durumu istemciden değiştirilemiyor:** `caregiver_links` için insert/update policy'si ve grant yok. Hasta bir yakının erişimini uygulamadan kaldıramıyor (`revoked` yapamıyor); bu şu an yalnızca sunucu/yönetici tarafında mümkün. Davet ve iptal akışı tasarlanırken ele alınmalı.
2. **Hasta, yakınının profilini göremiyor:** `profiles_read_own_or_linked` yalnızca yakın → hasta yönünde çalışıyor. "Yakınlarım" listesinde yakının `display_name` bilgisi gösterilemez. Güvenlik açığı değil, işlevsel eksik.
3. **Bekleyen yakın hastanın adını göremiyor:** `pending` durumunda yakın yalnızca hastanın UUID'sini görüyor. Davet ekranında isim gerekirse sunucu tarafında bir çözüm gerekir.
4. **Revoked yakının geçmiş uyarıları gizleniyor:** Gizlilik açısından doğru görünüyor; bilinçli bir tasarım kararı olarak ekipçe onaylanmalı.
5. **Canlı doğrulama yapılmadı:** Bu notlar yalnızca okumaya dayanıyor. Ahmet'in bağımsız incelemesiyle karşılaştırılacak; farklar Issue #6'ya yazılacak.