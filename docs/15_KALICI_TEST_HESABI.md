# Kalıcı test hesabı — PR #27 (mobil giriş) canlı doğrulaması için

## Neden gerekli
`supabase/tests/rls_scenarios.sql` (Metehan, PR #25) her şeyi tek bir transaction
içinde yapıp sonunda `ROLLBACK` ediyor — bu bilinçli bir tasarım, veritabanında
hiçbir test kullanıcısı bırakmıyor. Ama bu yüzden Afra'nın giriş ekranını (#24,
PR #27) **gerçek bir hesapla** deneyebileceği, kalıcı duran tek bir test
kullanıcısı şu an dev Supabase projesinde yok.

Bu dosya, o kalıcı hesabı **bir kere** oluşturmak için gereken adımları
içerir. SQL ile doğrudan `auth.users`'a satır eklemek güvenli değildir —
Supabase Auth (GoTrue) şifreyi kendi iç formatında tutar; elle INSERT ile
oluşturulan bir hesap görünüşte var ama giriş yapılamaz hale gelebilir.
Bu yüzden hesabı **Supabase panelinden veya Admin API'den** oluşturmak gerekir.

## Kim yapabilir
Yalnızca dev Supabase projesine erişimi olan **Metehan** (veya Ahmet, ikinci
destek). Bu depodan veya Claude Code oturumundan doğrudan yapılamaz — proje
anahtarları hiçbir yerde paylaşılmadı (bkz. Issue #5 güvenlik notu), bu
bilinçli bir sınır.

## Adımlar

1. **Supabase panelinde** (dev projesi) → Authentication → Users → **Add user**
   - E-posta: `test-hasta-afra@example.invalid`
   - Şifre: elle belirlenen, yalnızca ekip içinde paylaşılan bir test şifresi
     (gerçek bir şifre değil, yalnızca bu dev ortamı için)
   - "Auto Confirm User" işaretli olsun (e-posta onayı beklemesin)
   - Panelden eklenen kullanıcının `id`'sini (UUID) not edin.

2. **SQL Editor'de**, panelden alınan `id` ile profil ve örnek ilaç kaydı ekleyin
   (bu kısım normal bir INSERT'tir, auth ile ilgisi yok, güvenlidir):

   ```sql
   insert into public.profiles (id, display_name) values
     ('<panelden-alinan-uuid>', 'TEST Afra Giriş Hesabı')
   on conflict (id) do nothing;

   -- İsteğe bağlı: giriş sonrası boş bir ekran yerine içerik görünsün diye
   -- gerçek kataloğundan bir ürünle örnek bir ilaç kaydı (opsiyonel).
   ```

3. Afra'ya (veya kim test ediyorsa) **yalnızca** e-posta/şifreyi paylaşın —
   `service_role` anahtarı veya başka bir gizli anahtar paylaşılmaz.

4. Test bitince hesabı silmeye gerek yok (dev ortamı, gerçek veri değil) ama
   isterseniz panelden "Delete user" ile kaldırabilirsiniz.

## Kabul kriteri (bu dosyanın tamamlandığı an)
- [ ] Panelde bir kullanıcı oluşturuldu, e-posta/şifre ekip içinde (yalnızca
      gerekenlerle) paylaşıldı
- [ ] Afra, PR #27'deki `LoginPage`'den bu hesapla giriş yapıp
      `HomeShell(isDemoMode: false)` ekranını gerçekten gördü
- [ ] PR #27'nin "Test kanıtı" bölümündeki işaretlenmemiş kutu
      ("Görsel/video/log eklendi") bu denemeyle işaretlendi
