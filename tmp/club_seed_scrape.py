import json
import re
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from html import unescape
from typing import Iterable, Optional


@dataclass(frozen=True)
class Seed:
    brand: str
    name: str
    category: str  # matches ImportCategory raw values


DEFAULT_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"


def _decode_bytes(data: bytes) -> str:
    # best-effort decode
    for enc in ("utf-8", "utf-8-sig", "iso-8859-1"):
        try:
            return data.decode(enc)
        except Exception:
            pass
    return data.decode("utf-8", errors="replace")


def _jina_mirror(url: str) -> str:
    # r.jina.ai mirrors webpages as readable text and often bypasses bot blocks.
    # https://r.jina.ai/http(s)://example.com
    if url.startswith("https://"):
        return "https://r.jina.ai/https://" + url.removeprefix("https://")
    if url.startswith("http://"):
        return "https://r.jina.ai/http://" + url.removeprefix("http://")
    return "https://r.jina.ai/https://" + url


def fetch(url: str, user_agent: str = DEFAULT_UA) -> str:
    opener = urllib.request.build_opener()
    headers = {
        "User-Agent": user_agent,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
    }

    last_err: Optional[Exception] = None
    for attempt in range(1, 5):
        try:
            req = urllib.request.Request(url, headers=headers)
            with opener.open(req, timeout=30) as resp:
                return _decode_bytes(resp.read())
        except urllib.error.HTTPError as e:
            last_err = e
            # Backoff on rate limit / transient.
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(1.25 * attempt)
                continue
            # If blocked, try jina mirror immediately.
            if e.code in (401, 403):
                break
            raise
        except urllib.error.URLError as e:
            last_err = e
            time.sleep(0.8 * attempt)
            continue

    # Fallback to mirror (often succeeds when direct fetch is blocked).
    mirror = _jina_mirror(url)
    for attempt in range(1, 4):
        try:
            req = urllib.request.Request(mirror, headers=headers)
            with opener.open(req, timeout=30) as resp:
                return _decode_bytes(resp.read())
        except Exception as e:
            last_err = e
            time.sleep(0.8 * attempt)
            continue

    raise last_err if last_err else RuntimeError(f"Failed fetching {url}")


def extract_json_ld(html: str) -> list[dict]:
    # crude but works across many sites: pull <script type="application/ld+json"> blocks
    blocks = re.findall(r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>', html, flags=re.I | re.S)
    out: list[dict] = []
    for raw in blocks:
        raw = unescape(raw).strip()
        if not raw:
            continue
        try:
            parsed = json.loads(raw)
        except Exception:
            continue
        if isinstance(parsed, dict):
            out.append(parsed)
        elif isinstance(parsed, list):
            out.extend([x for x in parsed if isinstance(x, dict)])
    return out


def walk_names(obj) -> Iterable[str]:
    # recursively find "name" fields in arbitrary JSON
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "name" and isinstance(v, str):
                yield v
            else:
                yield from walk_names(v)
    elif isinstance(obj, list):
        for it in obj:
            yield from walk_names(it)


def normalize_name(raw: str) -> str:
    s = re.sub(r"\s+", " ", raw).strip()
    # remove marketing suffixes that tend to explode the family list
    s = re.sub(r"\b(RH|LH|Right Hand|Left Hand)\b", "", s, flags=re.I).strip()
    s = re.sub(r"\b(Driver|Drivers|Fairway|Fairway Wood|Fairway Woods|Hybrid|Hybrids|Iron|Irons|Wedge|Wedges|Putter|Putters)\b\s*$", "", s, flags=re.I).strip()
    s = s.strip(" -–|")
    return s


def looks_like_product_family(name: str) -> bool:
    stop = {
        "New",
        "Limited Edition",
        "Admin",
        "Comment",
        "Home",
        "Mizuno Golf Official Website",
        "Miura Golf",
        "PXG Australia",
        "COBRA Golf",
        "Kalles",
        "JPX925 Series - Mizuno Golf Official Website",
        "Layer 1",
        "Layer 2",
        "Layer 3",
        "Embrace the Darkness",
        "Shop",
        "Search",
        "Golf Clubs",
        "Drivers",
        "Irons",
        "Wedges",
        "Putters",
        "Hybrids",
        "Fairways",
        "Fairway Woods",
    }
    if not name or name in stop:
        return False
    # Reject cases where the extracted "name" is just the brand itself.
    if name.strip().lower() in {
        "titleist",
        "taylormade",
        "callaway",
        "odyssey",
        "cobra",
        "mizuno",
        "miura",
        "pxg",
        "srixon",
        "tour edge",
        "lab golf",
        "honma",
    }:
        return False
    if len(name) < 3:
        return False
    if re.search(r"\b(cookie|privacy|terms|account|sign in|join|login)\b", name, flags=re.I):
        return False
    if re.search(r"\b(alphabetically|best selling|most relevant|featured|price,|date,)\b", name, flags=re.I):
        return False
    if name in {"Date, new to old", "Date, old to new", "Price, high to low", "Price, low to high"}:
        return False
    if name.startswith("filter-"):
        return False
    if name in {"btn-close", "Horizon", "Woodstock", "Miura Custom"}:
        return False
    # avoid obvious marketing headers
    if name.count(" ") >= 8:
        return False
    return True


def fetch_titleist_from_dump() -> list[Seed]:
    # We already have a reliably fetched Titleist club listing dump from WebSearch.
    # Parse that to avoid 403 blocks on direct requests.
    dump_path = "/Users/gabeh/.cursor/projects/Users-gabeh-Desktop-SwingPal/agent-tools/1a540ece-1f17-4f50-9cbc-b71386afc3d7.txt"
    try:
        with open(dump_path, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except Exception:
        return []

    seeds: list[Seed] = []
    lines = [ln.strip() for ln in text.splitlines()]
    # pattern: [Name](url) then a category line like "Driver"
    for idx, ln in enumerate(lines):
        m = re.match(r"^\[(.+?)\]\(https?://", ln)
        if not m:
            continue
        name = normalize_name(m.group(1))
        if not looks_like_product_family(name):
            continue
        category = None
        for j in range(idx + 1, min(idx + 8, len(lines))):
            cat = lines[j].strip()
            if cat in ("Driver", "Fairway", "Hybrid", "Utility Iron", "Iron", "Wedge", "Putter"):
                category = {
                    "Driver": "driver",
                    "Fairway": "fairwayWood",
                    "Hybrid": "hybrid",
                    "Utility Iron": "utilityIron",
                    "Iron": "iron",
                    "Wedge": "wedge",
                    "Putter": "putter",
                }[cat]
                break
        if category:
            seeds.append(Seed(brand="Titleist", name=name, category=category))
    return unique_preserve(seeds)


def unique_preserve(items: Iterable[Seed]) -> list[Seed]:
    seen: set[tuple[str, str, str]] = set()
    out: list[Seed] = []
    for it in items:
        key = (it.brand.lower(), it.name.lower(), it.category)
        if key in seen:
            continue
        seen.add(key)
        out.append(it)
    return out


def passes_quality_gate(seed: Seed) -> bool:
    """High-confidence filter for scraped PLP rows (not Titleist dump).

    Prefer names that look like model families: digits, mixed case, or
    substantive multi-word titles — drop vague single tokens and junk.
    """
    if seed.brand == "Titleist":
        return True

    name = seed.name.strip()
    if len(name) < 4:
        return False
    lower = name.lower()
    vague_one_word = {
        "collection",
        "featured",
        "custom",
        "stock",
        "mens",
        "women",
        "junior",
        "clearance",
    }
    if name.lower() in vague_one_word:
        return False

    # Strong signals
    if re.search(r"\d", name):
        return True
    if re.search(r"[A-Z]", name) and len(name) >= 5:
        return True

    parts = name.split()
    if len(parts) >= 2 and len(name) >= 10:
        return True

    if len(parts) == 1 and len(name) >= 6 and not name.islower():
        return True

    return False


def enrich_short_names(seeds: list[Seed]) -> list[Seed]:
    """Convert very short model tokens into a readable family name using category.

    Example: Titleist "GT2" + category driver => "GT2 Driver"
    """
    suffix = {
        "driver": "Driver",
        "fairwayWood": "Fairway Wood",
        "hybrid": "Hybrid",
        "utilityIron": "Utility Iron",
        "iron": "Irons",
        "wedge": "Wedges",
        "putter": "Putters",
    }
    out: list[Seed] = []
    for s in seeds:
        name = s.name.strip()
        # Only enrich when it's basically a token (no spaces) and short.
        if " " not in name and len(name) <= 5 and s.category in suffix:
            out.append(Seed(brand=s.brand, name=f"{name} {suffix[s.category]}", category=s.category))
        else:
            out.append(s)
    return out


def scrape_page_as_families(brand: str, url: str, category: str) -> list[Seed]:
    html = fetch(url)
    docs = extract_json_ld(html)
    names: set[str] = set()

    for doc in docs:
        for n in walk_names(doc):
            n = normalize_name(n)
            if not looks_like_product_family(n):
                continue
            # avoid generic schema.org entities
            if n.lower() in ("titleist", "taylormade", "callaway", "golf clubs", "golf club"):
                continue
            # keep names that look like products (heuristic)
            if len(n) < 3:
                continue
            names.add(n)

    # fallback: sometimes product grids embed "product-name" attributes
    if not names:
        for m in re.findall(r'data-?[a-z0-9_-]*name=["\']([^"\']{3,120})["\']', html, flags=re.I):
            n = normalize_name(unescape(m))
            if looks_like_product_family(n):
                names.add(n)

    # fallback: capture markdown-like headings from jina mirror output
    if not names:
        for m in re.findall(r"^#{1,3}\s+(.{3,120})\s*$", html, flags=re.M):
            n = normalize_name(m)
            if looks_like_product_family(n) and n.lower() not in ("golf clubs", "drivers", "irons", "wedges", "putters", "hybrids", "fairways"):
                names.add(n)

    # convert into "families" by prefixing with a category hint when needed
    seeds: list[Seed] = []
    for n in sorted(names):
        seeds.append(Seed(brand=brand, name=n, category=category))
    return seeds


def targets_quality() -> list[tuple[str, str, str]]:
    """Official category PLPs with reliable structured product data.

    Titleist comes only from ``fetch_titleist_from_dump()`` (live Titleist often 403).
    Hybrid URL omitted — TaylorMade's hybrids listing 404s; add manually when URL is known.
    """
    return [
        ("TaylorMade", "https://www.taylormadegolf.com/drivers/?lang=default", "driver"),
        ("TaylorMade", "https://www.taylormadegolf.com/fairways/?lang=default", "fairwayWood"),
        ("TaylorMade", "https://www.taylormadegolf.com/irons/?lang=default", "iron"),
        ("TaylorMade", "https://www.taylormadegolf.com/wedges/?lang=default", "wedge"),
        ("TaylorMade", "https://www.taylormadegolf.com/putters/?lang=default", "putter"),
        ("Callaway", "https://www.callawaygolf.com/golf-clubs/drivers/", "driver"),
        ("Callaway", "https://www.callawaygolf.com/golf-clubs/fairway-woods/", "fairwayWood"),
        ("Callaway", "https://www.callawaygolf.com/golf-clubs/hybrids/", "hybrid"),
        ("Callaway", "https://www.callawaygolf.com/golf-clubs/iron-sets/", "iron"),
        ("Callaway", "https://www.callawaygolf.com/golf-clubs/wedges/", "wedge"),
        ("Odyssey", "https://odyssey.callawaygolf.com/putters", "putter"),
    ]


def targets_all_brands() -> list[tuple[str, str, str]]:
    """Extra sources — often noisy; use ``--all-brands`` only."""
    return targets_quality() + [
        ("TaylorMade", "https://www.taylormadegolf.com/hybrids-rescues/?lang=default", "hybrid"),
        ("Titleist", "https://www.titleist.com/golf-clubs/golf-drivers/", "driver"),
        ("Titleist", "https://www.titleist.com/golf-clubs/fairway-woods/", "fairwayWood"),
        ("Titleist", "https://www.titleist.com/golf-clubs/hybrid-golf-clubs/", "hybrid"),
        ("Titleist", "https://www.titleist.com/golf-clubs/irons/", "iron"),
        ("Titleist", "https://www.titleist.com/golf-clubs/golf-wedges/", "wedge"),
        ("Scotty Cameron", "https://www.titleist.com/golf-clubs/putters/phantom/", "putter"),
        ("Cobra", "https://www.cobragolf.com/collections/ds-adapt", "driver"),
        ("Mizuno", "https://mizunogolf.com/us/jpx925-series/", "iron"),
        ("Takomo", "https://takomogolf.com/pages/iron-sets", "iron"),
        ("Miura", "https://miuragolf.com/collections/types?q=irons", "iron"),
        ("PXG", "https://www.pxg.com/products/black-ops-drivers", "driver"),
        ("PXG", "https://www.pxg.com/products/gen8-irons", "iron"),
        ("Srixon", "https://srixonn.com/srixon-irons/", "iron"),
        ("Tour Edge", "https://www.touredge.com/collections/hot-launch-max-series", "iron"),
        ("LAB Golf", "https://labgolf.com/collections/all-products", "putter"),
        ("Honma", "https://us.honmagolf.com/collections/drivers", "driver"),
    ]


def main() -> int:
    quality_mode = "--all-brands" not in sys.argv
    seeds_direct: list[Seed] = []
    seeds_direct.extend(fetch_titleist_from_dump())

    targets = targets_quality() if quality_mode else targets_all_brands()

    all_seeds: list[Seed] = []
    all_seeds.extend(seeds_direct)
    for brand, url, category in targets:
        try:
            seeds = scrape_page_as_families(brand=brand, url=url, category=category)
            all_seeds.extend(seeds)
            print(f"{brand} {category}: {len(seeds)} candidates from {url}")
        except Exception as e:
            print(f"{brand} {category}: FAILED {url} ({e})", file=sys.stderr)

    deduped = unique_preserve(all_seeds)
    deduped = enrich_short_names(deduped)
    deduped = unique_preserve(deduped)

    if quality_mode:
        deduped = [s for s in deduped if passes_quality_gate(s)]
        deduped = unique_preserve(deduped)

    out_path = "tmp/club_seeds_quality.json" if quality_mode else "tmp/club_seeds_scraped.json"
    payload = {"seeds": [s.__dict__ for s in deduped]}
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, sort_keys=True)
        f.write("\n")

    mode = "quality" if quality_mode else "all-brands"
    print(f"\nwrote {len(deduped)} seeds to {out_path} ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

