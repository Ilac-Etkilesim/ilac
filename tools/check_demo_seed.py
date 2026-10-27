"""
Demo seed tutarlılık kontrolü (DB gerektirmez).

Kontroller:
  1. data/demo_products.csv içindeki her GTIN 14 haneli ve GS1 kontrol basamağı doğru.
  2. supabase/seed/demo_seed.sql içindeki her ürün GTIN'i CSV ile birebir aynı küme.
  3. Seed'deki her ürün, seed'de tanımlı bir ingredient id'sine referans veriyor (FK).
  4. interaction_rules: a_id ve b_id tanımlı, a_id < b_id (kanonik sıra), severity geçerli,
     aynı çift iki kez yok, is_verified=false ve is_demo=true.

Kullanım: python3 tools/check_demo_seed.py   (çıkış kodu 0 = temiz)
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data" / "demo_products.csv"
SEED_PATH = ROOT / "supabase" / "seed" / "demo_seed.sql"
UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
SEVERITIES = {"major", "moderate", "minor"}
# Beklenen sayılar — seed değişirse burası da güncellenir (bilinçli: sessiz atlama olmasın).
EXPECTED_INGREDIENTS = 8
EXPECTED_PRODUCTS = 10
EXPECTED_RULES = 4


def gtin_ok(gtin: str) -> bool:
    if not re.fullmatch(r"\d{14}", gtin):
        return False
    digits = [int(c) for c in gtin]
    total = sum(d * (3 if i % 2 == 0 else 1) for i, d in enumerate(digits[:13]))
    return (10 - total % 10) % 10 == digits[13]


def main() -> int:
    errors: list[str] = []

    csv_gtins: set[str] = set()
    with CSV_PATH.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            g = row["gtin"].strip()
            csv_gtins.add(g)
            if not gtin_ok(g):
                errors.append(f"CSV: geçersiz GTIN kontrol basamağı: {g}")
            if row["is_demo"].strip().lower() != "true":
                errors.append(f"CSV: is_demo true olmalı: {g}")

    sql = SEED_PATH.read_text(encoding="utf-8")

    ingredient_ids = set(re.findall(rf"\('({UUID})',\s*'demo_etken_[a-z]+'\)", sql))
    # Tam eşitlik (Metehan, PR #11): regex'e takılmayan bir satır sessizce atlanmasın.
    if len(ingredient_ids) != EXPECTED_INGREDIENTS:
        errors.append(f"SEED: {EXPECTED_INGREDIENTS} etken madde bekleniyordu, {len(ingredient_ids)} bulundu")

    products = re.findall(rf"\('(\d{{14}})',\s*'[^']*',\s*'({UUID})',\s*(true|false)", sql)
    seed_gtins = {g for g, _, _ in products}
    if len(products) != EXPECTED_PRODUCTS:
        errors.append(f"SEED: {EXPECTED_PRODUCTS} ürün bekleniyordu, {len(products)} bulundu")
    if seed_gtins != csv_gtins:
        errors.append(f"SEED/CSV GTIN kümeleri farklı: sadece seed={sorted(seed_gtins - csv_gtins)} "
                      f"sadece csv={sorted(csv_gtins - seed_gtins)}")
    for g, ing, is_demo in products:
        if not gtin_ok(g):
            errors.append(f"SEED: geçersiz GTIN kontrol basamağı: {g}")
        if ing not in ingredient_ids:
            errors.append(f"SEED: ürün {g} tanımsız ingredient_id'ye referans veriyor: {ing}")
        if is_demo != "true":
            errors.append(f"SEED: ürün {g} is_demo=true olmalı")

    rules = re.findall(
        rf"\('({UUID})',\s*'({UUID})',\s*'(\w+)',\s*'[^']*',\s*'[^']*',\s*(?:null|'[^']*'),\s*(?:null|'[^']*'),\s*(true|false),\s*(true|false)\)",
        sql,
    )
    if len(rules) != EXPECTED_RULES:
        errors.append(f"SEED: {EXPECTED_RULES} etkileşim kuralı bekleniyordu, {len(rules)} bulundu")
    seen_pairs: set[tuple[str, str]] = set()
    for a, b, sev, verified, is_demo in rules:
        if a not in ingredient_ids or b not in ingredient_ids:
            errors.append(f"SEED: kural tanımsız etken maddeye referans veriyor: {a} / {b}")
        if not a < b:
            errors.append(f"SEED: kanonik sıra bozuk (a < b olmalı): {a} / {b}")
        if sev not in SEVERITIES:
            errors.append(f"SEED: geçersiz severity: {sev}")
        if (a, b) in seen_pairs:
            errors.append(f"SEED: aynı çift iki kez: {a} / {b}")
        seen_pairs.add((a, b))
        if verified != "false" or is_demo != "true":
            errors.append(f"SEED: kural is_verified=false ve is_demo=true olmalı: {a} / {b}")

    if errors:
        print("HATA:")
        for e in errors:
            print(" -", e)
        return 1
    print(f"TEMİZ: {len(csv_gtins)} ürün, {len(ingredient_ids)} etken madde, {len(rules)} kural doğrulandı.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
