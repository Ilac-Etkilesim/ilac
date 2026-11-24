# Mevcut GitHub deposuna güvenli kurulum

Repo: https://github.com/Ilac-Etkilesim/ilac

1. Mevcut depoyu `git clone https://github.com/Ilac-Etkilesim/ilac.git` ile indir.
2. `git status`, `git branch -a`, `git remote -v` komutlarıyla durumu kontrol et.
3. Çalışan `dev` varsa onu temel alarak; yoksa ekiple kararlaştırılan varsayılan daldan `feature/sprint0-bootstrap` dalını aç.
4. ZIP'teki `ilac_yakinlik_sprint0/` klasörünün İÇERİĞİNİ klonun köküne kopyala; klasörün kendisini içeri atma.
5. `.git/` klasörüne dokunma. Çakışan dosyalara onaysız yazma: özellikle `lib/`, `pubspec.yaml`, `.gitignore`, `.github/`.
6. `git status --short` ve `git diff --check` ile değişiklikleri incele.
7. Flutter SDK/Android SDK kuruluysa, proje içinde ve `android/` henüz yoksa `python tools/bootstrap_native.py` komutunu çalıştır.
8. `flutter pub get`, `flutter analyze`, `flutter test`, `flutter devices`, `flutter run` komutlarını çalıştır.
9. Sonuçları not et. Yanlışlıkla sır veya gerçek hasta verisi eklenmediğini kontrol et.
10. `git add ...`, `git commit -m "chore: add sprint0 flutter prototype"`, `git push -u origin feature/sprint0-bootstrap` sonrası hedef `dev` için PR aç.

## Önemli
- Depo boş değilse önce içeriğiyle karşılaştırma yap.
- Gizli anahtarları ve gerçek hasta verilerini projeye taşımayın.
- GitHub erişimi yoksa organizasyon sahibinden ilgili depo için yetki istenmeli.
- `android/` klasörü varsa bootstrap betiği yazmadan çıkar; mevcut Flutter uygulamasında otomatik birleştirme yapılmamalıdır.
- `main` ve `dev` dallarını doğrudan değiştirmeyin.
