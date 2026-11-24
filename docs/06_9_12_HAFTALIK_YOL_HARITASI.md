# 9–13 haftalık yol haritası

**Güncelleme (Sprint 1 başı):** Hafta 1 büyük ölçüde proje tanıtımı/ortam kurulumu oldu, gerçek bir
geliştirme sprinti sayılmıyor. Bu yüzden Melike Sprint 0'ın devamı olarak Sprint 1'i de yönetiyor
(projenin "kemiğinin" oluşturulduğu ilk gerçek sprint). Rotasyon Sprint 2'den itibaren (Metehan ile)
normal sırasında devam ediyor; bu da planı bir hafta uzatıyor (12 yerine 13 hafta).

| Sprint | Hafta | Lider | Ekip kabul kriteri |
|---|---|---|---|
| 0 | 1 | Melike | Proje tanıtımı/kurulum: Flutter teknik denemesi + mobil açılış + cihazda GTIN ve test bildirimi |
| 1 | 2 | Melike | Proje kemiği: repo/CI/Issue akışı oturdu, demo veri + RLS ön incelemesi tamam, cihaz testleri netleşti |
| 2 | 3 | Metehan | Auth + RLS kullanıcı testleri + mobil giriş |
| 3 | 4 | Gizem | DataMatrix → GTIN → demo katalog eşleştirme |
| 4 | 5 | Ali | Etken madde şeması + örnek SQL kural sorgusu, eksik veri durumu |
| 5 | 6 | Afra | Hasta dashboard + kalıcı doz onayı + yerel zamanlı hatırlatma |
| 6 | 7 | Ahmet | Hasta-yakın izinli bağlantı + güvenlik testleri |
| 7 | 8 | Merve | Ciddi etkileşim / geciken doz için idempotent sunucu olayı + FCM |
| 8 | 9 | Eray | Uçtan uca entegrasyon + Android gerçek cihaz testleri |
| 9 | 10 | Melike | MVP demo + kritik hata giderme |
| 10 | 11 | Metehan | Tampon / eksik işler / RLS regresyon |
| 11 | 12 | Gizem | Tampon / erişilebilirlik ve cihaz testi |
| 12 | 13 | Ali | Tampon / belge, tekrarlanabilir demo, son kalite |

Çıktılar bağımlılık koşullarına bağlıdır; gelecek sprintte kayma olursa lider kalan işleri
öncelik sırasına göre dağıtır. Aile izni ve medikal veri doğrulaması çıkarılmaz.
