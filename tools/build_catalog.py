"""
Gerçek ürün kataloğu ETL'i: TİTCK Ruhsatlı Beşeri Tıbbi Ürünler Listesi → Supabase'e yüklenecek CSV'ler.

Girdi : TİTCK "Ruhsatlı Beşeri Tıbbi Ürünler Listesi" XLSX — https://www.titck.gov.tr/dinamikmodul/85
        Dosya adındaki tarih (ör. ...Listesi16.10.2026...) kaynak tarihi olarak kaydedilir.
Gerek : Yalnızca Python 3. Ek paket gerekmez (XLSX, standart kütüphaneyle okunur).
Çıktı : data/build/ (Git'e girmez: .gitignore'daki `build/` kuralı)
  İlk üç dosyanın sütunları 002_sprint2_rls_and_catalog.sql tablolarıyla birebir aynıdır; Supabase
  Table Editor → Import data ile dönüşümsüz yüklenir (sıra: ingredients → products → product_ingredients).
  ingredients.csv            id, normalized_name, display_name, atc_codes ({A,B} dizi biçimi), needs_review, review_reason
  products.csv               gtin, display_name, atc_code, license_status, is_demo, data_source
  product_ingredients.csv    product_gtin, ingredient_id
  review_ingredients.csv     needs_review=true kayıtlar (kategori adı) + kaç üründe geçtiği, elle düzeltilecek
  review_spelling_merges.csv aynı madde sayılıp birleştirilen yazımlar (göz gezdirilecek)
  rejected.csv               barkodu geçersiz/tekrar eden ya da etkin maddesi boş satırlar
  rapor.md                   Issue #2'ye yapıştırılacak özet

Yöntem:
  1. Barkod → GTIN-14: 13 hanenin başına 0, 12 hanenin başına 00; GS1 kontrol basamağı denetlenir.
  2. Etkin madde metni ürün bazında TİTCK'den alınır ve parçalara ayrılır: + , / ; "ve"
     (66,5 gibi ondalıklar bölünmez). Her parça bir etken maddedir; kombine ürünler böyle bağlanır.
     Tek başına madde olamayan kırıntılar ("l", "hcl") atılır; metnin çoğu kırıntıysa (aşı
     serotipleri, "vitamin B1, B6 ve B12") metin bölünmez, tek madde sayılır.
  3. Okunabilir anahtar: Türkçe harfler sadeleştirilir, parantez içi, sondaki hidrat ve tuz ekleri
     atılır ("naproksen sodyum" = naproksen, "morfin sülfat" = morfin); kısa bir açık listeyle tuz
     ve asit adları eşlenir ("potasyum klavulanat" = klavulanik asit).
  4. Yazım farkları birleştirilir: eşleştirme anahtarı (match_key) sondaki t/d, z/s, y/i, x/ks,
     ph/f, th/t ve çift harf farklarını aynılaştırır ("hidroklorotiyazit" = "hidroklorotiyazid");
     ayrıca aynı tek maddeli ATC kodu altında benzerliği >= 0,85 olan anahtarlar aynı madde
     sayılır ("morphine" = "morfin"). Birleşenler review_spelling_merges.csv'de listelenir.
  5. Her etken maddenin atc_codes alanı, o maddenin TEK BAŞINA bulunduğu ürünlerin 7 haneli ATC
     kodlarıdır. Etkileşim kuralları INN → ATC → etken madde yoluyla eşlenebilir; ATC'si olmayan
     maddeler (ör. klavulanik asit yalnız kombinasyonda geçer) adla eşlenmelidir.
  6. Etken madde id'si uuid5(NAMESPACE, "name:<anahtar>"): aynı girdiyle her çalıştırmada aynı id.

Tarihçe: İlk sürüm ilaclardb (CC0) kullanıyordu. O kaynakta etkin madde adları ATC koduna göre
yazılmış ve bazı gruplarda yanlıştı (Morfia → "Eslikarbazepin", Concor → "Mometazon"); TİTCK
listesi bu ürünlerin hepsinde doğru adı veriyor. Bu yüzden kaynak TİTCK'ye çevrildi (Issue #2).

Bu çıktı klinik doğrulama DEĞİLDİR. Etkileşim kuralları ayrıca kaynaklı ve doğrulanmış olmalıdır.
Taslak şemaya doğrudan yüklenemez; gereken migration değişiklikleri rapor.md'de yazar.

Kullanım:
  python tools/build_catalog.py <TİTCK xlsx yolu> [--out data/build]
Çıkış kodu 0 = tutarlılık kontrolleri geçti, 1 = hata var.
"""
from __future__ import annotations

import argparse
import csv
import difflib
import re
import sys
import uuid
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter, defaultdict
from decimal import Decimal, InvalidOperation
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "data" / "build"

# Sabit ad alanı: id'ler buna bağlı. Değiştirmeyin, yoksa tüm etken madde id'leri değişir.
NAMESPACE = uuid.UUID("6f1c2b7e-3a4d-5e8f-9a0b-1c2d3e4f5a6b")
SIMILARITY = 0.85  # aynı ATC altındaki iki yazım bu benzerliğin üstündeyse aynı madde sayılır

# Sütunlar başlık adıyla bulunur (sıra değişse de çalışır). Başlık değişirse script açık hatayla durur.
HEADERS = {"barcode": "barkod", "name": "urun adi", "ingredient": "etkin madde", "atc": "atc kodu"}
SUSPENSION_PREFIX = "ruhsati askida"
LICENSE_STATUS = {"0": "aktif", "1": "askida_madde23", "2": "askida_farmakovijilans", "3": "askida_madde22"}

TR_FOLD = str.maketrans({
    "ı": "i", "İ": "i", "I": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g",
    "ü": "u", "Ü": "u", "ö": "o", "Ö": "o", "ç": "c", "Ç": "c",
    "â": "a", "Â": "a", "î": "i", "Î": "i", "û": "u", "Û": "u",
})

# Sondan atılan tuz/hidrat/ester ekleri (sadeleştirilmiş yazımla). Yalnızca geriye tuz OLMAYAN
# bir kelime kalıyorsa atılır: "sodyum klorür" ve "kalsiyum asetat" olduğu gibi kalır.
SALTS = {
    "hidroklorur", "hcl", "hci", "hidrobromur", "hbr", "hidrat", "monohidrat", "dihidrat", "trihidrat",
    "tetrahidrat", "pentahidrat", "hemihidrat", "seskihidrat", "anhidr", "anhidrus", "anhidroz",
    "sodyum", "disodyum", "potasyum", "dipotasyum", "kalsiyum", "magnezyum", "besilat", "maleat",
    "mesilat", "dimesilat", "fumarat", "hemifumarat", "tartarat", "bitartarat", "suksinat",
    "sitrat", "sulfat", "asetat", "fosfat", "bromur", "klorur", "trometamol", "olamin", "aksetil",
    "sileksetil", "medoksomil", "propandiol", "arjinin", "erbumin", "tosilat", "tozilat",
    "dipropiyonat", "propiyonat", "valerat", "furoat", "laktat", "glukonat", "diglukonat",
    "nitrat", "oksalat", "pamoat", "palmitat", "dekanoat", "enantat", "stearat", "hiklat",
    "esilat", "kamsilat", "malat", "hidrojen", "tuzu", "esteri", "inn",
    "dibazik", "monobazik", "tribazik", "karbonat", "bikarbonat",
}
# Kristal suyu ekleri: geriye en az bir kelime kalıyorsa her zaman atılır
# ("magnezyum klorür hekzahidrat" = "magnezyum klorür").
HYDRATES = {"hidrat", "monohidrat", "dihidrat", "trihidrat", "tetrahidrat", "pentahidrat", "hekzahidrat",
            "heksahidrat", "heptahidrat", "oktahidrat", "dekahidrat", "dodekahidrat", "hemihidrat",
            "seskihidrat", "anhidr", "anhidrus", "anhidroz", "susuz"}
# Aynı etkin kısmın tuz ve asit adları (yalnızca bu açık liste; genel kural yanlış eşleştirir).
ANION_TO_ACID = {
    "klavulanat": "klavulanik asit", "valproat": "valproik asit", "fusidat": "fusidik asit",
    "mikofenolat": "mikofenolik asit", "alendronat": "alendronik asit", "risedronat": "risedronik asit",
    "ibandronat": "ibandronik asit", "zoledronat": "zoledronik asit",
}

# Madde değil, kategori adı olan yazımlar (TİTCK'de bazı ürünlerde ATC grup adı yazılmış:
# "ramipril and diuretics", "amoxicillin and enzyme inhibitor").
GENERIC_WORDS = {"various", "combinations", "products", "carbohydrates", "electrolytes",
                 "elektrolitler", "karbonhidratlar", "anesthetics", "vitamins", "other",
                 "diuretics", "inhibitor", "inhibitors", "agents"}

SPLIT_RE = re.compile(r"\s*(?:\+|;|/|\n|(?<!\d),(?!\d)|\s+ve\s+|\s+and\s+)\s*", re.IGNORECASE)
PAREN_RE = re.compile(r"\([^)]*\)|\[[^\]]*\]")
DOSE_RE = re.compile(r"^\d+(?:[.,]\d+)?\s*(?:mg|g|mcg|µg|iu|ui|ml)\b\s*", re.IGNORECASE)
ATC7_RE = re.compile(r"^[A-Z]\d\d[A-Z][A-Z]\d\d$")
DATE_RE = re.compile(r"(\d{2})\.(\d{2})\.(\d{4})")


def fold(text: str) -> str:
    return text.translate(TR_FOLD).lower()


def clean(value) -> str:
    return " ".join(str(value if value is not None else "").replace("\xa0", " ").split())


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


def split_parts(text: str) -> list[str]:
    return [p.strip(" .") for p in SPLIT_RE.split(text) if p and p.strip(" .")]


def part_key(part: str) -> str:
    """Okunabilir anahtar: 'Naproksen Sodyum (275 mg)' -> 'naproksen'."""
    text = fold(PAREN_RE.sub(" ", part)).strip()
    text = DOSE_RE.sub("", text)
    tokens = re.sub(r"[^a-z0-9 ]+", " ", text).split()
    while len(tokens) > 1 and tokens[-1] in HYDRATES:
        tokens.pop()
    while len(tokens) > 1 and tokens[-1] in SALTS and any(t not in SALTS for t in tokens[:-1]):
        tokens.pop()
    if tokens and tokens[-1] in ANION_TO_ACID and all(t in SALTS for t in tokens[:-1]):
        return ANION_TO_ACID[tokens[-1]]  # "potasyum klavulanat" -> "klavulanik asit"
    return " ".join(tokens)


def match_key(key: str) -> str:
    """Boşluksuz, yazım farklarını aynılaştıran eşleştirme anahtarı.

    'asetil salisilik asit' = 'asetilsalisilik asit', 'hidroklorotiyazit' = 'hidroklorotiyazid',
    'dekzametazon' = 'deksametazon'. Kurallar her anahtara aynı biçimde uygulanır; yalnızca sondaki
    t/d, z/s, y/i, x/ks, ph/f, th/t ve çift harf farkıyla ayrılan iki gerçek madde birleşebilir.
    """
    k = key.replace(" ", "").replace("ph", "f").replace("th", "t").replace("x", "ks")
    k = k.replace("y", "i").replace("z", "s")
    if k.endswith("t"):
        k = k[:-1] + "d"
    return re.sub(r"(.)\1+", r"\1", k)


def is_fragment(key: str) -> bool:
    """Tek başına madde olamayacak parça: 'l', '6b', '19a', 'b12'."""
    k = key.replace(" ", "")
    if key in SALTS or key in HYDRATES:  # "metformin, hcl" bölününce kalan "hcl"
        return True
    return len(k) <= 2 or k.isdigit() or (len(k) <= 4 and any(c.isdigit() for c in k))


def keyed_parts(text: str) -> list[tuple[str, str]]:
    parts = [(part_key(p), p) for p in split_parts(text)] if text else []
    parts = [(k, p) for k, p in parts if k]
    fragments = [kp for kp in parts if is_fragment(kp[0])]
    if fragments and len(fragments) * 4 > len(parts):
        # Metnin önemli kısmı parça: aşı serotipleri, "vitamin B1, B6 ve B12". Bölme, tek madde say.
        whole = part_key(text.replace(",", " ").replace("/", " ").replace("+", " "))
        return [(whole, text)] if whole else []
    return [kp for kp in parts if kp not in fragments]  # azınlıktaki kırıntıları ("l") at


def most_common(counter: Counter):
    # Eşitlikte sıralamada ilk: çıktı her çalıştırmada aynı olsun.
    return sorted(counter.items(), key=lambda kv: (-kv[1], str(kv[0])))[0][0]


XLSX_NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
DOC_REL_NS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
PKG_REL_NS = "{http://schemas.openxmlformats.org/package/2006/relationships}"


def _col_index(ref: str) -> int | None:
    letters = re.match(r"[A-Z]+", ref or "")
    if not letters:
        return None
    n = 0
    for ch in letters.group(0):
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def _cell_value(cell: ET.Element, shared: list[str]) -> str | None:
    kind = cell.get("t")
    if kind == "inlineStr":
        return "".join(t.text or "" for t in cell.iter(XLSX_NS + "t"))
    v = cell.find(XLSX_NS + "v")
    if v is None or v.text is None:
        return None
    if kind == "s":
        return shared[int(v.text)]
    if kind in ("str", "e", "b"):
        return v.text
    try:  # sayı: 8699508010752 ya da 8.699508010752E+12 -> tam sayı yazımı
        num = Decimal(v.text)
        return str(int(num)) if num == num.to_integral_value() else v.text
    except InvalidOperation:
        return v.text


def xlsx_rows(path: Path, sheet_hint: str) -> tuple[str, "iter"]:
    """Ek paket gerektirmeyen XLSX okuyucu. Adında sheet_hint geçen sayfayı (yoksa ilkini) okur."""
    zf = zipfile.ZipFile(path)
    workbook = ET.fromstring(zf.read("xl/workbook.xml"))
    sheets = [(s.get("name") or "", s.get(DOC_REL_NS + "id")) for s in workbook.iter(XLSX_NS + "sheet")]
    rels = {r.get("Id"): r.get("Target") or ""
            for r in ET.fromstring(zf.read("xl/_rels/workbook.xml.rels")).iter(PKG_REL_NS + "Relationship")}
    name, rel_id = next(((n, r) for n, r in sheets if sheet_hint in fold(n)), sheets[0])
    target = rels[rel_id].lstrip("/")
    target = target if target.startswith("xl/") else "xl/" + target

    shared: list[str] = []
    if "xl/sharedStrings.xml" in zf.namelist():
        for si in ET.fromstring(zf.read("xl/sharedStrings.xml")).iter(XLSX_NS + "si"):
            parts = []
            for child in si:  # okunuş (rPh) metinleri hariç: yalnızca t ve r/t
                if child.tag == XLSX_NS + "t":
                    parts.append(child.text or "")
                elif child.tag == XLSX_NS + "r":
                    t = child.find(XLSX_NS + "t")
                    parts.append((t.text or "") if t is not None else "")
            shared.append("".join(parts))

    def rows():
        with zf.open(target) as fh:
            for _, el in ET.iterparse(fh, events=("end",)):
                if el.tag != XLSX_NS + "row":
                    continue
                cells: dict[int, str | None] = {}
                last = -1
                for c in el.iter(XLSX_NS + "c"):
                    col = _col_index(c.get("r", ""))
                    last = col if col is not None else last + 1
                    cells[last] = _cell_value(c, shared)
                yield [cells.get(i) for i in range(max(cells) + 1)] if cells else []
                el.clear()

    return name, rows()


def read_titck(path: Path) -> tuple[list[dict], str]:
    try:
        sheet_name, rows = xlsx_rows(path, "ruhsatli")
    except (zipfile.BadZipFile, KeyError, ET.ParseError) as exc:
        raise SystemExit(f"HATA: {path.name} okunamadı ({exc}). Dosya TİTCK'nin .xlsx listesi mi?")
    columns: dict[str, int] = {}
    for _ in range(15):  # başlık satırı ilk satırlardan birinde
        header = [fold(clean(c)) for c in next(rows, ())]
        found = {k: header.index(h) for k, h in HEADERS.items() if h in header}
        if len(found) == len(HEADERS):
            columns = found
            susp = [i for i, h in enumerate(header) if h.startswith(SUSPENSION_PREFIX)]
            if susp:
                columns["suspension"] = susp[0]
            break
    if not columns:
        raise SystemExit(
            f"HATA: '{sheet_name}' sayfasında başlık satırı bulunamadı. Beklenen sütunlar: "
            + ", ".join(HEADERS.values()) + ". TİTCK dosya biçimi değişmiş olabilir; HEADERS'ı güncelleyin."
        )
    records = []
    for row in rows:
        if not any(c not in (None, "") for c in row):
            continue
        get = lambda k: clean(row[columns[k]]) if k in columns and columns[k] < len(row) else ""
        records.append({k: get(k) for k in list(HEADERS) + ["suspension"]})
    m = DATE_RE.search(path.name)
    list_date = f"{m.group(3)}-{m.group(2)}-{m.group(1)}" if m else "tarih belirtilmedi"
    return records, list_date


def write_csv(path: Path, header: list[str], rows: list[list]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        writer.writerows(rows)


class UnionFind:
    def __init__(self) -> None:
        self.parent: dict[str, str] = {}

    def find(self, x: str) -> str:
        self.parent.setdefault(x, x)
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, a: str, b: str) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[max(ra, rb)] = min(ra, rb)  # deterministik kök


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="TİTCK Ruhsatlı Beşeri Tıbbi Ürünler Listesi (.xlsx)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    if not args.source.exists():
        print(f"HATA: dosya bulunamadı: {args.source}", file=sys.stderr)
        return 1
    args.out.mkdir(parents=True, exist_ok=True)

    records, list_date = read_titck(args.source)
    data_source = f"TİTCK Ruhsatlı Beşeri Tıbbi Ürünler Listesi ({list_date})"

    # 1) Barkod ve metin temizliği
    products: list[dict] = []
    rejected: list[list] = []
    seen: set[str] = set()
    for r in records:
        gtin = to_gtin14(r["barcode"])
        if gtin is None:
            rejected.append([r["barcode"], r["name"], "GTIN-14'e çevrilemedi / kontrol basamağı hatalı"])
            continue
        if gtin in seen:
            rejected.append([r["barcode"], r["name"], "tekrar eden barkod (ilk satır kullanıldı)"])
            continue
        parts = keyed_parts(r["ingredient"])
        if not parts:
            rejected.append([r["barcode"], r["name"], "etkin madde boş"])
            continue
        seen.add(gtin)
        products.append({
            "gtin": gtin, "name": r["name"], "atc": r["atc"].replace(" ", "").upper(), "parts": parts,
            "status": LICENSE_STATUS.get(r["suspension"], "bilinmiyor"),
        })

    # 2) Yazım farklarını birleştir: aynı tek maddeli ATC altında, benzer anahtarlar
    uf = UnionFind()
    by_atc: dict[str, set[str]] = defaultdict(set)
    for p in products:
        for key, _ in p["parts"]:
            uf.find(match_key(key))
        if ATC7_RE.match(p["atc"]) and len(p["parts"]) == 1:
            by_atc[p["atc"]].add(match_key(p["parts"][0][0]))
    for atc in sorted(by_atc):
        keys = sorted(by_atc[atc])
        for i, a in enumerate(keys):
            for b in keys[i + 1:]:
                if difflib.SequenceMatcher(None, a, b).ratio() >= SIMILARITY:
                    uf.union(a, b)

    # 3) Küme → etken madde
    spaced: dict[str, Counter] = defaultdict(Counter)    # küme -> okunabilir anahtar sayıları
    displays: dict[str, Counter] = defaultdict(Counter)  # küme -> orijinal yazımlar
    atcs: dict[str, set[str]] = defaultdict(set)
    for p in products:
        for key, display in p["parts"]:
            root = uf.find(match_key(key))
            spaced[root][key] += 1
            displays[root][display.lower()] += 1
        if ATC7_RE.match(p["atc"]) and len(p["parts"]) == 1:
            atcs[uf.find(match_key(p["parts"][0][0]))].add(p["atc"])

    canon = {root: most_common(c) for root, c in spaced.items()}
    ids = {root: str(uuid.uuid5(NAMESPACE, "name:" + match_key(canon[root]))) for root in spaced}

    links: list[tuple[str, str]] = []
    product_count: Counter = Counter()
    samples: dict[str, list[str]] = defaultdict(list)
    for p in products:
        for root in dict.fromkeys(uf.find(match_key(k)) for k, _ in p["parts"]):
            links.append((p["gtin"], ids[root]))
            product_count[root] += 1
            if len(samples[root]) < 2:
                samples[root].append(p["name"])

    # needs_review yalnızca kaydın kendisi şüpheliyse true: check_drug_risk() bunu kullanıcıya
    # "inceleme gerekli" olarak yansıtır. ATC'nin olmaması bir şüphe değil (hidroklorotiyazid,
    # klavulanik asit Türkiye'de yalnız kombinasyonda var); bu bilgi atc_codes = {} ile görülür.
    ing_rows = []
    review_rows = []
    merges = []
    for root in sorted(spaced, key=lambda r: canon[r]):
        reason = "kategori adı, madde değil" if set(canon[root].split()) & GENERIC_WORDS else ""
        # PostgreSQL dizi biçimi: Supabase CSV içe aktarımı text[] sütununa doğrudan yükler.
        atc_literal = "{" + ",".join(sorted(atcs[root])) + "}"
        ing_rows.append([ids[root], canon[root], most_common(displays[root]), atc_literal,
                         "true" if reason else "false", reason])
        if reason:
            review_rows.append([canon[root], reason, product_count[root], " | ".join(samples[root])])
        if len(spaced[root]) > 1:
            merges.append([canon[root], " | ".join(sorted(spaced[root])), atc_literal])

    # 4) Yaz — sütunlar 002_sprint2_rls_and_catalog.sql tablolarıyla birebir aynı (dönüşümsüz yükleme)
    write_csv(args.out / "ingredients.csv",
              ["id", "normalized_name", "display_name", "atc_codes", "needs_review", "review_reason"],
              ing_rows)
    write_csv(args.out / "review_ingredients.csv",
              ["normalized_name", "review_reason", "product_count", "sample_products"], review_rows)
    write_csv(args.out / "products.csv",
              ["gtin", "display_name", "atc_code", "license_status", "is_demo", "data_source"],
              [[p["gtin"], p["name"], p["atc"], p["status"], "false", data_source] for p in products])
    write_csv(args.out / "product_ingredients.csv", ["product_gtin", "ingredient_id"], [list(x) for x in links])
    write_csv(args.out / "review_spelling_merges.csv", ["normalized_name", "merged_spellings", "atc_codes"], merges)
    write_csv(args.out / "rejected.csv", ["raw_barcode", "display_name", "reason"], rejected)

    # 5) Tutarlılık kontrolleri (hata = çıkış kodu 1)
    errors: list[str] = []
    id_list = [r[0] for r in ing_rows]
    names = [r[1] for r in ing_rows]
    if len(id_list) != len(set(id_list)):
        errors.append("ingredients.id tekrar ediyor")
    if len(names) != len(set(names)):
        errors.append("ingredients.normalized_name tekrar ediyor: "
                      + str([n for n, c in Counter(names).items() if c > 1][:5]))
    if not all(gs1_ok(p["gtin"]) for p in products):
        errors.append("products içinde geçersiz GTIN var")
    if {g for g, _ in links} != {p["gtin"] for p in products}:
        errors.append("etken maddesi olmayan ürün products.csv'ye girmiş")
    if set(id_list) != {i for _, i in links}:
        errors.append("product_ingredients ile ingredients uyuşmuyor")
    if len(set(links)) != len(links):
        errors.append("product_ingredients'ta tekrar eden satır var")

    per_product = Counter(g for g, _ in links)
    status = Counter(p["status"] for p in products)
    no_atc = sum(1 for r in ing_rows if r[3] == "{}")
    lines = [
        f"# Gerçek katalog ETL raporu ({date.today().isoformat()})",
        "",
        f"Kaynak: {data_source}, `{args.source.name}`. Klinik doğrulama değildir.",
        "",
        "| Gösterge | Sayı |",
        "|---|---|",
        f"| Kaynaktaki satır | {len(records)} |",
        f"| Reddedilen (barkod / tekrar / boş etkin madde) | {len(rejected)} |",
        f"| Kataloğa giren ürün | {len(products)} |",
        f"| — ruhsatı aktif | {status['aktif']} |",
        f"| — ruhsatı askıda | {len(products) - status['aktif'] - status['bilinmiyor']} |",
        f"| — kombine (2+ etken madde) | {sum(1 for c in per_product.values() if c > 1)} |",
        f"| Etken madde kaydı | {len(ing_rows)} |",
        f"| — ATC'si olmayan (adla eşlenecek) | {no_atc} |",
        f"| — kategori adı, madde değil | {sum(1 for r in ing_rows if 'kategori' in r[5])} |",
        f"| Yazım farkı birleştirilen madde | {len(merges)} |",
        f"| Ürün–etken madde bağlantısı | {len(links)} |",
        "",
        "## Supabase'e yükleme",
        "",
        "Şema: `supabase/migrations/20261102_002_sprint2_rls_and_catalog.sql` (PR #25). CSV sütunları"
        " tablolarla birebir aynıdır; `atc_codes` PostgreSQL dizi biçimindedir (`{M01AE01,M02AA13}`, boşsa `{}`)."
        " Bu yüzden Table Editor → Import data ile dönüşümsüz yüklenir.",
        "",
        f"`needs_review = true` yalnızca kaydın kendisi şüpheliyse (kategori adı) işaretlenir:"
        f" {len(review_rows)} kayıt, liste `review_ingredients.csv`'de.",
        "",
        "Etkileşim kuralı eşlemesi: INN → ATC kodu → `atc_codes` alanında o kodu taşıyan etken madde(ler)."
        " ATC'si olmayan maddeler (ör. klavulanik asit, hidroklorotiyazid: Türkiye'de yalnız kombinasyonda"
        " geçiyor) adla eşlenir. Etken madde id'si `uuid5(NAMESPACE, 'name:' + match_key(normalized_name))`"
        " (bkz. `tools/build_catalog.py`).",
        "",
        "Yükleme sırası: `ingredients.csv` → `products.csv` → `product_ingredients.csv`.",
        "",
        "## Bilinen sınırlar",
        "",
        "- TİTCK'de bazı ürünlerde etkin madde yerine ATC grup adı yazıyor (\"ramipril and diuretics\","
        " \"amoxicillin and enzyme inhibitor\"). Bu ürünlerin ikinci maddesi bilinmiyor; `needs_review`"
        " ile işaretli \"kategori adı\" kayıtları elle düzeltilmeli.",
        "- Yazım farkları birleştirildi (ör. morfin/morphine, hidroklorotiyazit/hidroklorotiyazid);"
        " liste `review_spelling_merges.csv`'de. Birleşmeyen Türkçe/İngilizce çiftler aynı ATC kodunu"
        " taşıdığı için kural eşlemesinde yine birlikte yakalanır.",
        "- Aşı ve vitamin karışımları (\"vitamin B1, B6 ve B12\") tek etken madde olarak tutuldu.",
        "- Ürün adı, etkin madde ve ATC TİTCK'nin yazdığı gibidir; klinik doğrulama yapılmadı.",
        "",
        "## Kontroller",
        "",
    ]
    lines += [f"- HATA: {e}" for e in errors] or ["- Tüm tutarlılık kontrolleri geçti."]
    (args.out / "rapor.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print("\n".join(lines[4:17]))
    print(f"\nÇıktılar: {args.out}")
    if errors:
        print("\n".join("HATA: " + e for e in errors), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
