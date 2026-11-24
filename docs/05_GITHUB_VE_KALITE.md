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
