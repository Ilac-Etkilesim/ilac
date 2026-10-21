# Önerilen mimari ve ilk doğrulama

```
Android / Flutter
├─ Hasta dashboard ve doz onayı (demo → Supabase)
├─ GS1 DataMatrix kamera → GTIN → ürün eşleştirme
├─ Yakın paneli (demo → yalnız izinli veri)
└─ Yerel planlanmış hatırlatıcı (Sprint 0 yalnız anlık TEST)
       │
       ▼
Supabase (Auth + PostgreSQL + RLS + SQL etkileşim sorgusu)
       ▲
       │ doğrulanmış sürümlü veri
Python / pandas (veri temizleme, GTIN→etken madde eşleştirme)
       │
       └── Ciddi risk / geciken doz olayı → güvenli sunucu işlemi
                                         → FCM → izinli hasta yakını
```

## Yakın bildiriminde kritik teknik gereksinimler
- FCM Admin SDK / service account **yalnız sunucuda**.
- Yakın bildirimi için bağlantı aktif ve izin verilmiş olmalı.
- Geciken doz tetiklemesi cihaz kapalıyken de çalışmalıdır; sunucuda idempotent görev gerekir.
- Aynı geciken doz için yinelenen bildirim üretilmemeli.
- Bildirim ekranında gereksiz sağlık bilgisi açığa çıkarılmamalıdır.
- Yakın bildirimleri için yeniden deneme, hata kaydı ve yetki iptali testleri gerekir.

## Bir sonraki sprintte uygulanacak düzen
- Auth ekranı, kayıt/giriş ve çıkış.
- Kimlikten gelen patient_id ile veri sorgulama; istemciden rastgele user_id'ye güvenmeme.
- Gerçek uygulama doz kayıtlarını Supabase'e kaydeder.
- İlaç tarama GTIN çıkarır, katalogla eşleştirir.
- Ciddi etkileşim bulunduğu bilgisi ancak doğrulanmış veriyle oluşur.
- İzin verilmiş yakına görüntüleme RLS ile doğrulanır.

## Kaynak verinin sınırı
Katalog eksikse 'bilinen etkileşim yok' yerine 'değerlendirilmedi' gösterin.
Demo verileri gerçek hastalara yönelik kullanım dışıdır.
