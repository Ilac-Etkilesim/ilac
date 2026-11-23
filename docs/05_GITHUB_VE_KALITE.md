# GitHub ve kalite standartları

- `main`: kararlı demo sürümü; doğrudan push kapalı.
- `dev`: ekip incelemesinden geçen entegrasyon dalı.
- `feature/S0-03-datamatrix` vb.: küçük ve geçici görev dalları.
- 1 Issue → 1 PR → 1 teknik reviewer → liderin süreç onayı → `dev`.
- Test + en az 1 başka kişi tarafından review olmadan merge yok.
- Haftalık lider teknik incelemeyi yönetir, her uzmanlık kodunu tek başına onaylamaz.
- `main`'e yalnız `dev`'den haftalık kabul sonrası PR ile geçilir.
- Her PR: ne değişti, nasıl test edildi, ekran kanıtı, risk ve ilgili Issue.
- Kullanılmayan işlevler çalışıyormuş gibi anlatılmaz.
- Gizli anahtarlar, test kişisi verileri ve gerçek sağlık verileri commit edilmez.
- Claude Code önerileri insan incelemesi olmadan birleştirilmez.


## Kararlı sürüm akışı (`dev` → `main`)

- `main`, haftalık kabulden geçmiş son kararlı sürümü gösterir; demo ve teslimler `main`'den yapılır.
- **Ne zaman:** Her sprint sonunda, haftalık toplantıdaki kabulden sonra.
- **Nasıl:**
  1. `dev` üzerinde CI'ın (`analyze-and-test`, `build-apk`) yeşil olduğu kontrol edilir.
  2. `dev → main` PR'ı açılır. Başlık: `release: Sprint N`. Açıklamada o sprintte birleşen PR'lar listelenir.
  3. Haftalık lider süreç onayını verir.
  4. PR **"Create a merge commit"** ile birleştirilir (squash yapılmaz); böylece `main` geçmişinde her sürüm ayrı bir merge kaydı olarak görünür.
- `main`'e doğrudan push yapılmaz. `main`'de bir düzeltme gerekirse önce `dev`'e PR açılır, düzeltme bir sonraki sürümle `main`'e geçer.
- `analyze-and-test` ve `build-apk` kontrolleri yeşil olmadan `dev` ve `main`'e merge yapılmaz.