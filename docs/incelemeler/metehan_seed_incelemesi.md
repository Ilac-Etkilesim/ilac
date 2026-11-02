# Metehan — Demo seed incelemesi (PR #11, 27 Ekim 2026)

> Şema sahibi incelemesi. GitHub PR #11 inceleme yorumundan alınmıştır.

İnceleme: PR #11 (demo seed), şema sahibi Metehan. Karar: Onay, bloklamayan 4 öneriyle.

Şemayla uyum (20261021_001_initial_draft.sql):

Tablo ve sütun adları birebir aynı: ingredients(id, normalized_name) (seed s.20), products(gtin, display_name, ingredient_id, is_demo, data_source) (s.33), interaction_rules'ın 9 sütunu (s.47–48).
Kanonik sıra: PostgreSQL uuid değerlerini bayt bayt karşılaştırır. Seed'deki sabit UUID'ler yalnızca son baytta farklı (…01 < …02 < … < …08). 4 kuralın hepsi check (ingredient_a_id < ingredient_b_id) kısıtını sağlıyor (migration s.97).
GTIN: 10 değerin hepsi ^[0-9]{14}$ regex'ine uyuyor (migration s.17) ve GS1 kontrol basamakları doğru (betik ile doğrulandı).
on conflict: products → (gtin) birincil anahtar, doğru. interaction_rules → hedefsiz do nothing (s.58). id rastgele üretildiği için tekrar çalıştırmada çakışmayı rules_pair_unique_idx yakalıyor, doğru.
begin/commit (s.17, 60): sorun yok. Herhangi bir insert hata verirse seed'in tamamı geri alınıyor, yarım seed kalmıyor.
check_drug_risk() ile tutarlılık: ürünler is_demo=true olduğu için fonksiyon demo_only ile erken dönüyor (migration s.209). Ayrıca kurallar is_verified=false, is_demo=true olduğu için s.223–224 filtresinden de geçmezlerdi. Seed başlığındaki yorum (s.8–11) doğru.
Öneriler (bloklamaz):

s.29 on conflict (id) do nothing: normalized_name da unique (migration s.13). Aynı adla farklı id taşıyan bir satır varsa seed hata verip tümden geri alınır. Hedefsiz on conflict do nothing daha dayanıklı olur.
tools/check_demo_seed.py s.71: len(rules) < 3 kontrolü gevşek. Açıklama metnine bir kesme işareti ('') girerse kural regex'e takılmaz ve betik o kuralı sessizce atlar. Beklenen sayıları tam eşitlikle kontrol etmeyi öneririm (10 / 8 / 4).
Demo GTIN'leri 9999… ile başlıyor. Gerçek barkodlarla çakışmaması açısından iyi. Ama docs/12 s.32'deki "baştaki 0 düşürülerek 13 haneli TİTCK barkoduna eşleme" senaryosu bu verilerle test edilemiyor. İleride 0/0869… biçiminde 1–2 kurgusal ürün eklenebilir.
Ürün I/J, A/B ile aynı etken maddeyi taşıyor (s.32, 42–43): "aynı etken madde iki kez" (mükerrer tedavi) durumu şu an hiçbir kuralla yakalanmıyor. Bu PR'ın kapsamı dışında; ayrı bir issue olarak not düşmeyi öneririm.
Test (Flutter 3.38.1, PR dalında):

python tools/check_demo_seed.py → TEMİZ: 10 ürün, 8 etken madde, 4 kural doğrulandı.
flutter test → All tests passed! (10 test; yeni test/demo_products_test.dart dahil)
flutter analyze → No issues found!
"Demo modu" hakkında görüş (karar değil):

Artı: Sunumda etkileşim uyarısını uçtan uca, gerçek veri beklemeden ve DEMO etiketiyle gösterebiliriz. Arayüz ekibi kırmızı/sarı/yeşil ekranlarını gerçek bir RPC yanıtıyla test edebilir.
Artı: Bayrak yalnızca is_demo=true ürün ve kurallara uygulanırsa gerçek veri yolu (is_verified and not is_demo) aynen korunur.
Eksi: Bu, security definer bir fonksiyona ikinci bir dal ekler. Bayrağın yanlışlıkla gerçek kullanıcıya açılması veya demo sonucunun gerçek sanılması, klinik açıdan en riskli hata türü.
Eksi: Şu anki "doğrulanmamış veriyle hiçbir şey söyleme" ilkesi basit ve denetlenebilir. Demo modu bu ilkeyi istisnalı hâle getiriyor ve her RLS incelemesinde ayrıca kontrol edilmesi gerekiyor.
