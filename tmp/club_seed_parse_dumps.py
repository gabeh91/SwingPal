import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Seed:
    brand: str
    name: str
    category: str


CATEGORY_MAP = {
    "Driver": "driver",
    "Drivers": "driver",
    "Fairway": "fairwayWood",
    "Fairways": "fairwayWood",
    "Fairway Wood": "fairwayWood",
    "Fairway Woods": "fairwayWood",
    "Hybrid": "hybrid",
    "Hybrids": "hybrid",
    "Utility Iron": "utilityIron",
    "Utility Irons": "utilityIron",
    "Iron": "iron",
    "Irons": "iron",
    "Wedge": "wedge",
    "Wedges": "wedge",
    "Putter": "putter",
    "Putters": "putter",
}


def normalize_brand(brand: str) -> str:
    return brand.strip()


def normalize_name(name: str) -> str:
    s = re.sub(r"\s+", " ", name).strip()
    # collapse common shop suffixes
    s = re.sub(r"\s*-\s*Titleist\s*$", "", s, flags=re.I).strip()
    return s


def parse_markdown_shop_dump(text: str, brand: str) -> list[Seed]:
    lines = [ln.strip() for ln in text.splitlines()]
    seeds: list[Seed] = []
    stop_names = {
        "New",
        "Limited Edition",
        "Limited Edition T-Series Oil Can Irons Now Available",
        "Shop Now",
        "Sign In or Join to Access",
        "Hide Filters",
        "Show Filters",
        "Sort",
        "Featured",
        "Best Sellers",
        "New Arrivals",
        "Price (High to Low)",
        "Price (Low to High)",
        "Apply ( 0 )",
        "Clear All",
    }
    i = 0
    while i < len(lines):
        ln = lines[i]
        m = re.match(r"^\[(.+?)\]\((https?://.+?)\)$", ln)
        if not m:
            i += 1
            continue
        name = normalize_name(m.group(1))
        if not name or name in stop_names:
            i += 1
            continue
        # avoid obviously non-product tokens
        if len(name) <= 3 and not re.search(r"[A-Za-z0-9]", name):
            i += 1
            continue

        # look ahead for a category line within next few lines
        category = None
        for j in range(i + 1, min(i + 8, len(lines))):
            cand = lines[j]
            if not cand:
                continue
            if cand in CATEGORY_MAP:
                category = CATEGORY_MAP[cand]
                break
            # sometimes dumps include "Driver" on same line as other tokens
            if cand.lower() in (k.lower() for k in CATEGORY_MAP.keys()):
                for k, v in CATEGORY_MAP.items():
                    if cand.lower() == k.lower():
                        category = v
                        break
                if category:
                    break

        if category:
            seeds.append(Seed(brand=normalize_brand(brand), name=name, category=category))
        i += 1

    return seeds


def unique(seeds: list[Seed]) -> list[Seed]:
    seen = set()
    out: list[Seed] = []
    for s in seeds:
        key = (s.brand.lower(), s.name.lower(), s.category)
        if key in seen:
            continue
        seen.add(key)
        out.append(s)
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: club_seed_parse_dumps.py --brand \"Titleist\" dump1.txt [dump2.txt ...]", file=sys.stderr)
        return 2

    brand = None
    paths: list[str] = []
    i = 1
    while i < len(argv):
        if argv[i] == "--brand" and i + 1 < len(argv):
            brand = argv[i + 1]
            i += 2
            continue
        paths.append(argv[i])
        i += 1

    if not brand:
        print("missing --brand", file=sys.stderr)
        return 2
    if not paths:
        print("missing dump paths", file=sys.stderr)
        return 2

    all_seeds: list[Seed] = []
    for p in paths:
        text = Path(p).read_text(encoding="utf-8", errors="replace")
        all_seeds.extend(parse_markdown_shop_dump(text, brand=brand))

    deduped = unique(all_seeds)
    out_path = Path("tmp/club_seeds_from_dumps.json")
    out_path.write_text(
        json.dumps({"seeds": [s.__dict__ for s in deduped]}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {len(deduped)} seeds -> {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

