"""
Gerçek ürün kataloğu ETL'i: ilaclardb (CC0) → Supabase'e yüklenecek CSV'ler (Issue #2).

Girdi : mdaedalus/ilaclardb deposundaki data/cvs/ilac.csv.zip (veya açılmış ilac.csv)
        https://github.com/mdaedalus/ilaclardb — CC0 1.0, TİTCK/SGK listelerinden türetilmiş,
        resmî kaynak DEĞİL (bkz. docs/12).
Çıktı : data/build/ (Git'e girmez: .gitignore'daki `build/` kuralı)
  ingredients.csv             id, atc_code, normalized_name, display_name, needs_review, review_reason, product_count
  products.csv                gtin, display_name, atc_code, is_demo, data_source, ingredient_source
  product_ingredients.csv     product_gtin, ingredient_id
  review_suspicious_names.csv aynı etken madde adının ilgisiz ATC gruplarında geçtiği durumlar
  review_unresolved.csv       etken maddesi hiçbir yoldan bulunamayan ürünler
  rejected.csv                barkodu geçersiz satırlar
  rapor.md                    Issue #2'ye yapıştırılacak özet

NEDEN ATC: ilaclardb'deki etken madde ADI ürüne göre değil ATC koduna göre yazılmış ve bazı ATC
gruplarında yanlış (ör. Morfia/morfin N02AA01 → "Eslikarbazepin", Concor/bisoprolol C07AB07 →
"Mometazon"). ATC kodları ise markalarla tutarlı. Bu yüzden:
  * Tek maddeli ürünlerde etken madde kimliği = 7 haneli ATC kodu. Ad yalnızca görüntü bilgisidir;
    etkileşim mantığı ada değil bu kimliğe dayanır. Adlar TİTCK listesiyle doğrulanmadan
    kullanıcıya gösterilmemelidir.
  * Kombine ürünlerde (ör. Amoksisilin + Klavulanik Asit) ve 4-5 haneli grup kodlu ürünlerde madde
    kimliği ATC'den çıkmaz. Bunlar için ada dayalı, "elle bakılacak" kayıt açılır ve ATC'ye
    BAĞLANMAZ: adla bağlamak denendi, A10BK01 (dapagliflozin) "flurbiprofen" yazıldığı için
    Majezik gargarayı dapagliflozine bağladı.
  * Etken madde id'si uuid5 ile üretilir: ATC'li kayıtta "atc:<KOD>", adla açılanda "name:<ad>".
    Kural üreten script'ler id'yi ATC kodundan aynı yolla hesaplayabilir.

Barkod → GTIN-14: 13 hanenin başına 0, 12 hanenin başına 00; GS1 kontrol basamağı denetlenir.

Bu çıktı klinik doğrulama DEĞİLDİR. Taslak şemaya doğrudan yüklenemez; gereken migration
değişiklikleri rapor.md'de yazar.

Kullanım:
  python tools/build_catalog.py <ilac.csv.zip veya ilac.csv yolu> [--out data/build]
Çıkış kodu 0 = tutarlılık kontrolleri geçti, 1 = hata var.
"""
from __future__ import annotations

import argparse
import csv
import io
import re
import sys
import uuid
import zipfile
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "data" / "build"
DATA_SOURCE = "ilaclardb v2.0.0 (CC0) — TİTCK/SGK türevi, resmî değil"

# ilaclardb sütun adları. Kaynak değişirse script açık bir hatayla durur (sessiz kayma olmasın).
COL_NAME = "İlaç Bilgisi_İlaç Adı"
COL_BARCODE = "İlaç Bilgisi_Barkod"
COL_ATC = "İlaç Bilgisi_ATC Kodu"
COL_INGREDIENT = "İlaç Bilgisi_Active_Ingredient"
COL_STATUS = "Satıcı Bilgisi_Durumu"
REQUIRED = [COL_NAME, COL_BARCODE, COL_ATC, COL_INGREDIENT]

# Sabit ad alanı: id'ler buna bağlı. Değiştirmeyin, yoksa tüm etken madde id'leri değişir.
NAMESPACE = uuid.UUID("6f1c2b7e-3a4d-5e8f-9a0b-1c2d3e4f5a6b")

TR_FOLD = str.maketrans({
    "ı": "i", "İ": "i", "I": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g",
    "ü": "u", "Ü": "u", "ö": "o", "Ö": "o", "ç": "c", "Ç": "c",
    "â": "a", "Â": "a", "î": "i", "Î": "i", "û": "u", "Û": "u",
})

# Sondan atılan tuz/hidrat/ester ekleri (sadeleştirilmiş yazımla). Yalnızca geriye tuz OLMAYAN
# bir kelime kalıyorsa atılır: "sodyum klorür" ve "kalsiyum asetat" olduğu gibi kalır.
SALTS = {
    "hidroklorur", "hcl", "hidrobromur", "hbr", "hidrat", "monohidrat", "dihidrat", "trihidrat",
    "tetrahidrat", "pentahidrat", "hemihidrat", "seskihidrat", "anhidr", "anhidrus", "anhidroz",
    "sodyum", "disodyum", "potasyum", "dipotasyum", "kalsiyum", "magnezyum", "besilat", "maleat",
    "mesilat", "dimesilat", "fumarat", "hemifumarat", "tartarat", "bitartarat", "suksinat",
    "sitrat", "sulfat", "asetat", "fosfat", "bromur", "klorur", "trometamol", "olamin", "aksetil",
    "sileksetil", "medoksomil", "propandiol", "arjinin", "erbumin", "tosilat", "tozilat",
    "dipropiyonat", "propiyonat", "valerat", "furoat", "laktat", "glukonat", "diglukonat",
    "nitrat", "oksalat", "pamoat", "palmitat", "dekanoat", "enantat", "stearat", "hiklat",
    "esilat", "kamsilat", "malat", "hidrojen", "tuzu", "esteri", "inn",
}

MISSING_MARKERS = ("bulunamad",)
SPLIT_RE = re.compile(r"\s*(?:\+|;|/|\n|(?<!\d),(?!\d)|\s+ve\s+|\s+and\s+)\s*", re.IGNORECASE)
PAREN_RE = re.compile(r"\([^)]*\)|\[[^\]]*\]")
DOSE_RE = re.compile(r"^\d+(?:[.,]\d+)?\s*(?:mg|g|mcg|µg|iu|ui|ml)\b\s*", re.IGNORECASE)
ATC7_RE = re.compile(r"^[A-Z]\d\d[A-Z][A-Z]\d\d$")


def fold(text: str) -> str:
    return text.translate(TR_FOLD).lower()


def gs1_ok(gtin14: str) -> bool:
    if not re.fullmatch(r"\d{14}", gtin14):
        return False
    digits = [int(c) for c in gtin14]
    total = sum(d * (3 if i % 2 == 0 else 1) for i, d in enumerate(digits[:13]))
    return (10 - total % 10) % 10 == digits[13]


def to_gtin14(raw: str) -> str | None:
    digits = re.sub(r"\D", "", raw or "")
    if len(digits) in (12, 13, 14):
        gtin = digits.zfill(14)
        return gtin if gs1_ok(gtin) else None
    return None


def clean_text(raw: str) -> str:
    text = (raw or "").replace("_x000D_", " ").replace("\r", " ").strip().strip(".").strip()
    if not text or any(m in fold(text) for m in MISSING_MARKERS):
        return ""
    return text


def split_parts(text: str) -> list[str]:
    return [p.strip(" .") for p in SPLIT_RE.split(text) if p and p.strip(" .")]


def part_key(part: str) -> str:
    """Okunabilir anahtar: 'Metformin HCl (500 mg)' -> 'metformin'."""
    text = fold(PAREN_RE.sub(" ", part)).strip()
    text = DOSE_RE.sub("", text)
    tokens = re.sub(r"[^a-z0-9 ]+", " ", text).split()
    while len(tokens) > 1 and tokens[-1] in SALTS and any(t not in SALTS for t in tokens[:-1]):
        tokens.pop()
    return " ".join(tokens)


def match_key(key: str) -> str:
    """Boşluksuz eşleştirme anahtarı: 'asetil salisilik asit' = 'asetilsalisilik asit'."""
    return key.replace(" ", "")


def keyed_parts(text: str) -> list[tuple[str, str]]:
    out = []
    for part in split_parts(text) if text else []:
        key = part_key(part)
        if key:
            out.append((key, part))
    return out


def ingredient_id(kind: str, value: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{kind}:{value}"))


def most_common(counter: Counter):
    # Eşitlikte sıralamada ilk: çıktı her çalıştırmada aynı olsun.
    return sorted(counter.items(), key=lambda kv: (-kv[1], str(kv[0])))[0][0]


def read_rows(path: Path) -> list[dict[str, str]]:
    if path.suffix == ".zip":
        with zipfile.ZipFile(path) as zf:
            names = [n for n in zf.namelist() if n.lower().endswith(".csv")]
            if not names:
                raise SystemExit(f"HATA: {path} içinde CSV yok.")
            text = zf.read(names[0]).decode("utf-8-sig")
    else:
        text = path.read_text(encoding="utf-8-sig")
    reader = csv.DictReader(io.StringIO(text))
    missing = [c for c in REQUIRED if c not in (reader.fieldnames or [])]
    if missing:
        raise SystemExit(
            "HATA: ilaclardb sütun adları değişmiş, eksik: " + ", ".join(missing)
            + "\nSütunları kontrol edip script başındaki COL_* sabitlerini güncelleyin."
        )
    return list(reader)


def write_csv(path: Path, header: list[str], rows: list[list]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        writer.writerows(rows)


class Ingredients:
    def __init__(self) -> None:
        self.rows: dict[str, dict] = {}  # id -> kayıt

    def by_atc(self, atc: str, key: str, display: str, reason: str = "") -> str:
        iid = ingredient_id("atc", atc)
        row = self.rows.setdefault(iid, {
            "atc": atc, "name": key, "display": display, "reasons": [], "products": 0})
        if reason and reason not in row["reasons"]:
            row["reasons"].append(reason)
        return iid

    def by_name(self, key: str, display: str, reason: str) -> str:
        iid = ingredient_id("name", match_key(key))
        row = self.rows.setdefault(iid, {
            "atc": "", "name": key, "display": display, "reasons": [], "products": 0})
        if reason not in row["reasons"]:
            row["reasons"].append(reason)
        return iid


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="ilaclardb data/cvs/ilac.csv.zip veya ilac.csv")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    if not args.source.exists():
        print(f"HATA: dosya bulunamadı: {args.source}", file=sys.stderr)
        return 1
    args.out.mkdir(parents=True, exist_ok=True)

    raw_rows = read_rows(args.source)

    # 1) Barkod ve metin temizliği
    products: list[dict] = []
    rejected: list[list] = []
    seen: set[str] = set()
    for r in raw_rows:
        name = " ".join((r.get(COL_NAME) or "").split())  # satır sonları CSV içe aktarımını bozar
        gtin = to_gtin14(r.get(COL_BARCODE, ""))
        if gtin is None:
            rejected.append([r.get(COL_BARCODE, ""), name, "GTIN-14'e çevrilemedi / kontrol basamağı hatalı"])
            continue
        if gtin in seen:
            rejected.append([r.get(COL_BARCODE, ""), name, "tekrar eden barkod"])
            continue
        status = (r.get(COL_STATUS) or "").strip()
        if status and fold(status) != "aktif":
            rejected.append([r.get(COL_BARCODE, ""), name, f"durum: {status}"])
            continue
        seen.add(gtin)
        text = clean_text(r.get(COL_INGREDIENT, ""))
        products.append({"gtin": gtin, "name": name, "atc": (r.get(COL_ATC) or "").strip().upper(),
                         "text": text, "parts": keyed_parts(text)})

    # 2) ATC başına çoğunluk metni (metni olan ürünlerden)
    votes: dict[str, Counter] = defaultdict(Counter)
    examples: dict[tuple, list] = {}
    for p in products:
        if p["atc"] and p["parts"]:
            sig = tuple(sorted(match_key(k) for k, _ in p["parts"]))
            votes[p["atc"]][sig] += 1
            examples.setdefault((p["atc"], sig), p["parts"])
    atc_parts = {atc: examples[(atc, most_common(v))] for atc, v in votes.items()}

    # 3) Ad → tek maddeli 7 haneli ATC adayları; ilgisiz gruplarda geçen adlar şüpheli
    name_atcs: dict[str, set[str]] = defaultdict(set)
    for atc, parts in atc_parts.items():
        if ATC7_RE.match(atc) and len(parts) == 1:
            name_atcs[match_key(parts[0][0])].add(atc)
    suspicious = {mk: atcs for mk, atcs in name_atcs.items() if len({a[0] for a in atcs}) > 1}
    suspicious_atcs = {a for atcs in suspicious.values() for a in atcs}

    def resolve(key: str, display: str) -> str:
        """Kombine ürün parçası / grup kodlu ürün: ada dayalı kayıt, ATC'ye BAĞLANMAZ.

        ilaclardb adları ATC'ye bağlamak için güvenilir değil (ör. A10BK01 dapagliflozin
        "flurbiprofen" diye yazılmış; adla bağlanınca Majezik gargara dapagliflozine gidiyordu).
        Yanlış bir maddenin kurallarıyla kontrol etmektense "kontrol tamamlanamadı" daha güvenli.
        Adlar TİTCK listesinden doğrulandıktan sonra bu kayıtlar ATC'ye elle/yeni script'le bağlanır.
        """
        return ing.by_name(key, display, "adla açıldı, ATC'ye bağlanmadı: TİTCK ile doğrula")

    # 4) Ürün → etken madde
    ing = Ingredients()
    out_products: list[list] = []
    links: list[tuple[str, str]] = []
    unresolved: list[list] = []
    source_count: Counter = Counter()

    def link(p: dict, iids: list[str], source: str) -> None:
        source_count[source] += 1
        out_products.append([p["gtin"], p["name"], p["atc"], "false", DATA_SOURCE, source])
        for iid in dict.fromkeys(iids):
            links.append((p["gtin"], iid))
            ing.rows[iid]["products"] += 1

    for p in products:
        atc = p["atc"]
        group = atc_parts.get(atc, [])
        parts = p["parts"] or group
        if ATC7_RE.match(atc) and len(parts) <= 1:
            if parts:
                key, display = group[0] if len(group) == 1 else parts[0]
                reason = "ad başka anatomik grupta da geçiyor, TİTCK ile doğrula" if atc in suspicious_atcs else ""
                link(p, [ing.by_atc(atc, key, display, reason)], "atc")
            else:
                link(p, [ing.by_atc(atc, "", "", "kaynakta ad yok, TİTCK'den doldur")], "atc_name_missing")
        elif len(parts) > 1:
            link(p, [resolve(k, d) for k, d in parts], "combo_text" if p["parts"] else "combo_atc_group")
        elif parts:  # 4–5 haneli grup kodu: madde kimliği koddan çıkmaz, adla kayıt açılır
            link(p, [resolve(parts[0][0], parts[0][1])], "group_code_by_name")
        else:
            unresolved.append([p["gtin"], p["name"], atc, p["text"]])

    # 5) Yaz
    ing_rows = []
    for iid, row in sorted(ing.rows.items(), key=lambda kv: (kv[1]["atc"] == "", kv[1]["atc"], kv[1]["name"])):
        if row["products"]:
            ing_rows.append([iid, row["atc"], row["name"], row["display"],
                             "true" if row["reasons"] else "false", "; ".join(row["reasons"]), row["products"]])
    write_csv(args.out / "ingredients.csv",
              ["id", "atc_code", "normalized_name", "display_name", "needs_review", "review_reason", "product_count"],
              ing_rows)
    write_csv(args.out / "products.csv",
              ["gtin", "display_name", "atc_code", "is_demo", "data_source", "ingredient_source"], out_products)
    write_csv(args.out / "product_ingredients.csv", ["product_gtin", "ingredient_id"], [list(x) for x in links])
    sample = defaultdict(list)
    for p in products:
        if p["atc"] in suspicious_atcs and len(sample[p["atc"]]) < 2:
            sample[p["atc"]].append(p["name"])
    write_csv(args.out / "review_suspicious_names.csv", ["name", "atc_code", "sample_products"],
              [[mk, a, " | ".join(sample[a])] for mk, atcs in sorted(suspicious.items()) for a in sorted(atcs)])
    write_csv(args.out / "review_unresolved.csv", ["gtin", "display_name", "atc_code", "raw_text"], unresolved)
    write_csv(args.out / "rejected.csv", ["raw_barcode", "display_name", "reason"], rejected)

    # 6) Tutarlılık kontrolleri (hata = çıkış kodu 1)
    errors: list[str] = []
    ids = [r[0] for r in ing_rows]
    atcs = [r[1] for r in ing_rows if r[1]]
    if len(ids) != len(set(ids)):
        errors.append("ingredients.id tekrar ediyor")
    if len(atcs) != len(set(atcs)):
        errors.append("ingredients.atc_code tekrar ediyor")
    if not all(gs1_ok(r[0]) for r in out_products):
        errors.append("products içinde geçersiz GTIN var")
    if {g for g, _ in links} != {r[0] for r in out_products}:
        errors.append("etken maddesi olmayan ürün products.csv'ye girmiş")
    if set(ids) != {i for _, i in links}:
        errors.append("product_ingredients ile ingredients uyuşmuyor")
    if len(set(links)) != len(links):
        errors.append("product_ingredients'ta tekrar eden satır var")

    per_product = Counter(g for g, _ in links)
    combo = sum(1 for c in per_product.values() if c > 1)
    no_name = sum(1 for r in ing_rows if not r[2])
    name_only = sum(1 for r in ing_rows if not r[1])
    lines = [
        f"# Gerçek katalog ETL raporu ({date.today().isoformat()})",
        "",
        f"Kaynak: `{args.source.name}` — {DATA_SOURCE}. Klinik doğrulama değildir.",
        "",
        "| Gösterge | Sayı |",
        "|---|---|",
        f"| Kaynaktaki satır | {len(raw_rows)} |",
        f"| Reddedilen (barkod/durum) | {len(rejected)} |",
        f"| Kataloğa giren ürün | {len(out_products)} |",
        f"| — tek maddeli, ATC ile bağlandı | {source_count['atc']} |",
        f"| — tek maddeli, ATC ile bağlandı ama kaynakta ad yok | {source_count['atc_name_missing']} |",
        f"| — kombine (2+ etken madde) | {combo} |",
        f"| — 4-5 haneli grup kodlu, adla kayıt açıldı | {source_count['group_code_by_name']} |",
        f"| Etken maddesi bulunamayan ürün (kataloğa girmedi) | {len(unresolved)} |",
        f"| Etken madde kaydı | {len(ing_rows)} |",
        f"| — adı boş (TİTCK'den doldurulacak) | {no_name} |",
        f"| — ATC'siz, adla açıldı (elle bakılacak) | {name_only} |",
        f"| — adı şüpheli ATC kaydı | {len(suspicious_atcs)} |",
        f"| Ürün–etken madde bağlantısı | {len(links)} |",
        "",
        "## Veri kalitesi uyarısı",
        "",
        "ilaclardb'de etken madde adı ATC koduna göre yazılmış ve bazı gruplarda yanlış. Örnekler:"
        " Morfia (morfin, N02AA01) → \"Eslikarbazepin\"; Concor (bisoprolol, C07AB07) → \"Mometazon\";"
        " Tivicay (dolutegravir, J05AJ03) → \"Denosumab\"; Apranax (naproksen, M01AE02) → \"Rasajilin\";"
        " Daprenza (dapagliflozin, A10BK01) → \"Flurbiprofen\"."
        " Son örnek otomatik şüpheli listesine düşmüyor; yani işaretsiz adlar da doğrulanmış değildir."
        " Bu yüzden etken madde kimliği ATC kodudur, kombine ürünler adla ATC'ye bağlanmaz ve hiçbir ad"
        " TİTCK listesiyle doğrulanmadan kullanıcıya gösterilmemelidir."
        " Kesin hatalı adaylar: `review_suspicious_names.csv`.",
        "",
        "## Şemaya yüklemeden önce gereken migration",
        "",
        "1. `product_ingredients(product_gtin text references products(gtin), ingredient_id uuid references ingredients(id), primary key (product_gtin, ingredient_id))`; RLS açık, `authenticated` için yalnızca `select`.",
        "2. `products.ingredient_id` kaldırılmalı ya da `null` olabilmeli (kombine ürünler tek sütuna sığmıyor); `products.atc_code text` eklenmeli.",
        "3. `ingredients`: `atc_code text unique` (null olabilir), `display_name text`, `needs_review boolean`, `review_reason text`; `normalized_name` üzerindeki `unique` kaldırılmalı (aynı madde farklı ATC'lerde: ibuprofen ağızdan M01AE01, haricen M02AA13).",
        "4. `check_drug_risk()` ürünlerin tüm etken maddelerini `product_ingredients` üzerinden karşılaştırmalı.",
        "",
        "Etken madde id'si: ATC'li kayıtta `uuid5(NAMESPACE, 'atc:<KOD>')`. Etkileşim kuralı üreten script"
        " aynı NAMESPACE ile id'yi ATC kodundan hesaplayabilir (bkz. `tools/build_catalog.py`).",
        "",
        "Yükleme sırası: `ingredients.csv` → `products.csv` → `product_ingredients.csv`.",
        "",
        "## Kontroller",
        "",
    ]
    lines += [f"- HATA: {e}" for e in errors] or ["- Tüm tutarlılık kontrolleri geçti."]
    (args.out / "rapor.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print("\n".join(lines[4:19]))
    print(f"\nÇıktılar: {args.out}")
    if errors:
        print("\n".join("HATA: " + e for e in errors), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
