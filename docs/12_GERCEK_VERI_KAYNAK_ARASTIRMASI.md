# Gerçek ilaç verisi — kaynak araştırması (26 Ekim 2026)

Demo seed'in yerini alacak gerçek veri için ön araştırma. Linkler araştırma gününde açılıp doğrulandı;
"belirsiz" yazan lisans maddeleri **kullanmadan önce yazılı teyit** gerektirir. Bu bir hukuki görüş değildir.

## 1. Katman bazında kaynaklar

| Kaynak | Katman | Türkiye kapsamı | Erişim | Lisans | Uygulanabilirlik |
|---|---|---|---|---|---|
| **TİTCK Ruhsatlı Beşeri Tıbbi Ürünler Listesi** — https://www.titck.gov.tr/dinamikmodul/85 | GTIN(barkod) → ürün adı → etkin madde → ATC → ruhsat sahibi | Tam, Türkçe, resmi | XLSX, haftalık | Sayfada lisans notu yok → **belirsiz** (kamu verisi varsayımı, TİTCK'ye sorulmalı) | **Kolay** |
| **TİTCK SKRS E-Reçete İlaç Listesi** — https://www.titck.gov.tr/dinamikmodul/43 | Barkod, reçete türü, askı durumu | Tam | XLSX, haftalık | Belirsiz | **Kolay** (ruhsatlı listeyle barkod üzerinden birleşir) |
| TİTCK Fiyat Listesi — https://www.titck.gov.tr/dinamikmodul/100 | Fiyat (+barkod, dosya içi doğrulanmalı) | Tam | XLSX | Belirsiz | Projeye şart değil |
| TİTCK KÜB/KT — https://www.titck.gov.tr/kubkt | Prospektüs PDF'leri | Tam | Yalnızca web + tekil PDF | Belirsiz | Orta (toplu veri yok) |
| **İTS** — https://www.its.gov.tr/its/entegrasyon | GTIN/seri doğrulama | Tam | REST API, **paydaş hesabı şart** | Paydaş sözleşmesi | **Zor — kullanma** (TİTCK listesi yeter) |
| GS1 Verified by GS1 / GS1 Türkiye | GTIN → marka (klinik bilgi yok) | Var | Web ~30 sorgu/gün; API ücretli | Sınırlı | Gereksiz |
| **mdaedalus/ilaclardb** — https://github.com/mdaedalus/ilaclardb | GTIN, ATC, etkin madde, SGK (CSV/JSON/SQLite) | Tam | GitHub | **CC0 1.0** (topluluk; TİTCK+SGK'dan türetilmiş, resmi değil) | **Kolay** — şema örneği |
| dckaratas/ilac-mcp — https://github.com/dckaratas/ilac-mcp | TİTCK XLSX birleştirme kodu (veri dağıtmıyor) | Tam | GitHub | MIT | Kolay — parser referansı |
| batuhanilgarr/turkiye-ilac-katalogu (Hugging Face) | 6.080 ilaç + KÜB/KT linkleri, ATC | Tam | Parquet | Belirsiz (dataset card) | Orta |
| SGK Bedeli Ödenecek İlaçlar (EK-4/A) — https://sgk.gov.tr | Barkod, ticari ad, eşdeğer grup | Tam | XLSX, düzensiz | Belirsiz | Gerekli değil |
| **WHO ATC/DDD** — https://atcddd.fhi.no/ | Etkin madde normalizasyonu | Evrensel (İng.) | Web ücretsiz; tam dosya ~200 € | Atıf zorunlu; değiştirme/ticari dağıtım yasak | Orta — yalnızca ATC düzey adları için |
| RxNorm/RxNav (NLM) — https://lhncbc.nlm.nih.gov/RxNav/ | Etkin madde (İng.) | Yok | REST, ücretsiz | ABD kamu | Orta — **etkileşim API'si Ocak 2024'te kapandı** |
| **ONC High Priority DDI + CredibleMeds** — https://github.com/dbmi-pitt/public-PDDI-analysis/tree/master/PDDI-Datasets/ONC-High-Priority | Etkileşim: uzman seçimi kritik çiftler (CSV/XLS) | Yok (INN İng.; ATC'ye eşlenir) | GitHub | Repo'da lisans yok → **belirsiz**; kaynak: Phansalkar 2012 (JAMIA) | **Orta — en gerçekçi başlangıç** |
| DDInter 1.0/2.0 — https://ddinter.scbdd.com/download/ | Etkileşim: 236–302 bin çift, risk düzeyi | Yok | CSV (1.0) | "open-access" + "All Rights Reserved"; üçüncü taraflar CC BY-NC-SA diyor → **belirsiz, yazarlara sor** | Orta |
| DrugBank — https://go.drugbank.com/releases/latest | Etkileşim + sözlük | Yok | Akademik XML (şu an duraklatılmış); ücretsiz web checker Mart 2026'da kapandı | Akademik CC BY-NC: **uygulama yayınlamak yasak** | Zor |
| openFDA / NHS dm+d / EMA | ABD-UK-AB ürün verisi | Yok | API/XLSX | Kamu / OGL (doğrulanmalı) | Zor — Türkiye'yi kapsamaz |
| Drugs.com, Medscape, Lexicomp, Vademecum Online | Etkileşim | Vademecum Türkçe | Açık API yok; ticari | Ticari | Zor — bütçe yok |

## 2. Önerilen yol (öğrenci projesi için en gerçekçi)

1. **GTIN → ürün → etkin madde:** TİTCK Ruhsatlı Ürünler XLSX (ana) + E-Reçete listesi (askı/reçete), barkod üzerinden birleştirme. ilac-mcp'nin birleştirme mantığı ve ilaclardb şeması referans. Resmi, haftalık, Türkçe, ücretsiz.
2. **Etkin madde normalizasyonu:** TİTCK listesindeki **ATC kodu** birincil anahtar; WHO'dan yalnızca düzey adları, atıfla.
   - Karekod notu: GS1 DataMatrix `(01)` → 14 hane; TİTCK barkodu 13 hane → baştaki `0` düşürülerek eşlenir (**doğrulanmalı**).
3. **Etkileşim:** ONC High Priority + CredibleMeds TdP listesi → INN'leri ATC/etkin maddeye eşle, Türkçeleştir, `source_name/source_reference/verified_on` doldur. Kapsam genişletme: DDInter 1.0, **yalnızca yazılı lisans teyidi sonrası**.

## 3. Riskler ve uyarılar

- TİTCK dosyalarında lisans metni yok; başlık/sütun adları haftadan haftaya değişebilir → parser sütun adına değil, doğrulanmış eşlemeye dayanmalı.
- Etkileşim verileri İngilizce INN bazlı; çeviri ve ATC eşleme ekibin sorumluluğu, hata riski var.
- ONC listesi dar (yalnızca kritik çiftler) → uygulamada **"etkileşim bulunamadı = güvenli" asla denmez**; kaynak + tarih gösterilir; "eczacınıza/hekiminize danışın" uyarısı zorunlu (CLAUDE.md kuralı).
- DrugBank akademik lisansı yayınlanan uygulamaya izin vermez; RxNav/DrugBank ücretsiz etkileşim servisleri kapandı → hazır ücretsiz API beklemeyin.
- Şemadaki `check_drug_risk()` yalnızca `is_verified=true, is_demo=false` kuralları değerlendirir: gerçek veri yüklenirken `is_verified` yalnızca kaynak+tarih dolu kayıtlar için `true` yapılmalı (kimin yetkili olduğu ekip kararı).

## 4. Ali için 5 somut adım

1. https://www.titck.gov.tr/dinamikmodul/85 ve /43 → en güncel iki XLSX'i indir; sütunları (Barkod, Ürün Adı, Etkin Madde, ATC Kodu, Ruhsat Sahibi, Durum) doğrula; pandas ile barkod üzerinden birleştir; sonucu `data/` altına **koymadan önce** boyut ve lisans durumunu Issue #2'ye yaz.
2. https://github.com/dckaratas/ilac-mcp README'sini oku (birleştirme/parsing notları); https://github.com/mdaedalus/ilaclardb şemasını `supabase/migrations` tablolarına eşle, eksik sütunları listele.
3. TİTCK'ye (iletişim/CİMER) listelerin öğrenci projesi ve kamuya açık uygulamada kullanımı/yeniden dağıtımı için yazılı izin iste; cevabı `docs/` altına kaydet.
4. ONC klasöründen `ONC_High_Priority_Mapped.csv` ve CredibleMeds XLS'yi indir; Phansalkar 2012 (JAMIA) künyesini `source_reference` olarak hazırla; ilaç adlarını ATC'ye eşle (ilk 20 çift yeterli).
5. DDInter yazarlarına lisans/yeniden dağıtım iznini e-postayla sor; cevap gelene kadar yalnızca ONC listesiyle ilerle. WHO ATC için https://atcddd.fhi.no/copyright_disclaimer/ sayfasındaki atıf ve "değiştirme yasak" maddelerini oku.
