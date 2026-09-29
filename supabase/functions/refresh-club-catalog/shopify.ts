import {
  type Catalog,
  type Category,
  type Family,
  key,
  validateCatalog,
} from "./catalog.ts";

export interface ShopifySource {
  id: string;
  brand: string;
  origin: string;
  path: string;
  pageSize: number;
  maxPages: number;
  minModels: number;
}
export const SHOPIFY_SOURCES: ShopifySource[] = [
  {
    id: "cobra",
    brand: "Cobra",
    origin: "https://www.cobragolf.com",
    path: "/collections/golf-clubs/products.json",
    pageSize: 50,
    maxPages: 6,
    minModels: 25,
  },
  {
    id: "touredge",
    brand: "Tour Edge",
    origin: "https://www.touredge.com",
    path: "/products.json",
    pageSize: 100,
    maxPages: 8,
    minModels: 30,
  },
  {
    id: "miura",
    brand: "Miura",
    origin: "https://miuragolf.com",
    path: "/products.json",
    pageSize: 100,
    maxPages: 5,
    minModels: 5,
  },
  {
    id: "honma",
    brand: "Honma",
    origin: "https://us.honmagolf.com",
    path: "/products.json",
    pageSize: 100,
    maxPages: 5,
    minModels: 15,
  },
  {
    id: "takomo",
    brand: "Takomo",
    origin: "https://takomogolf.com",
    path: "/collections/golf-clubs/products.json",
    pageSize: 50,
    maxPages: 4,
    minModels: 5,
  },
  {
    id: "bettinardi",
    brand: "Bettinardi",
    origin: "https://bettinardi.com",
    path: "/collections/putters/products.json",
    pageSize: 100,
    maxPages: 4,
    minModels: 15,
  },
  {
    id: "evnroll",
    brand: "Evnroll",
    origin: "https://www.evnroll.com",
    path: "/products.json",
    pageSize: 100,
    maxPages: 4,
    minModels: 10,
  },
  {
    id: "newlevel",
    brand: "New Level",
    origin: "https://newlevelgolf.com",
    path: "/products.json",
    pageSize: 100,
    maxPages: 6,
    minModels: 10,
  },
];
interface Product {
  title: string;
  handle: string;
  vendor: string;
  product_type: string;
  body_html?: string;
  options: { name: string; values: string[] }[];
}
const numeric = (a: string, b: string) =>
  a.localeCompare(b, "en", { numeric: true });
const wedgeOrder = ["PW", "AW", "UW", "GW", "SW", "LW"];
function sorted(codes: string[]): string[] {
  return [...new Set(codes)].sort((a, b) => {
    const ai = wedgeOrder.indexOf(a), bi = wedgeOrder.indexOf(b);
    if (ai >= 0 || bi >= 0) return ai < 0 ? -1 : bi < 0 ? 1 : ai - bi;
    const an = Number.parseInt(a), bn = Number.parseInt(b);
    if (
      Number.isFinite(an) && an === bn &&
      /^[1-9][WHU]$/.test(a) !== /^[1-9][WHU]$/.test(b)
    ) return /^[1-9][WHU]$/.test(a) ? -1 : 1;
    return numeric(a, b);
  });
}
function classify(p: Product): Category | undefined {
  const title = p.title;
  if (
    /headcover|\bcovers?\b|grips?|shafts?|weights|gift|\btest\b|\bdemo\b|pre-owned|complete set|wedge pack|combo|club heads only|customized/i
      .test(title) ||
    /mws_apo_generated|dropdown|custom-base|hidden|shaft|accessor|apparel|headcover/i
      .test(p.product_type)
  ) return;
  if (/\b(driving iron|utility|ti-utility)\b/i.test(title)) {
    return "utilityIron";
  }
  if (/\bfairway(?:s| woods?)?\b/i.test(title)) return "fairwayWood";
  if (/\bhybrids?\b/i.test(title)) return "hybrid";
  if (
    /\birons?\b/i.test(title) ||
    /^(?:Irons|Stock Iron Set|Iron Head)$/.test(p.product_type)
  ) return "iron";
  if (
    /\bwedges?\b/i.test(title) ||
    /^(?:Wedges|Stock Wedge)$/.test(p.product_type)
  ) return "wedge";
  if (/\bputters?\b/i.test(title) || /^Putters?$/.test(p.product_type)) {
    return "putter";
  }
  if (/\bdriver\b/i.test(title)) return "driver";
}
function nameFor(
  source: ShopifySource,
  p: Product,
  category: Category,
): string {
  let name = p.title.trim().replace(/\s*\((?:Left|Right) Hand\)\s*/gi, "")
    .replace(/^Tour Edge\s+/i, "");
  // Cosmetic finishes and shaft length are not new head models.
  name = name.replace(/\s+Tour Length(?= Driver)/i, "");
  if (source.id === "bettinardi") {
    name = name.replace(/\s+Left[- ]Handed/gi, "").replace(
      /\s*\((?:Pink\/Purple|Black\/Yellow)\)/g,
      "",
    );
  }
  if (source.id === "evnroll") {
    name = name.replace(/\s*[-–—]\s*(?:Satin|Triple Black|Black)$/i, "");
  }
  if (source.id === "newlevel") {
    name = name.replace(
      /\s*\((?:HEAD ONLY|SOLD OUT|CLOSEOUT|FINAL STOCK)\)/gi,
      "",
    ).replace(/^(?:Chrome|RAW|LH RAW|Desert Eclipse)\s+/i, "")
      .replace(/\s+(?:LEFT|RIGHT)\s+HAND(?:ED)?/gi, "").replace(
        /\s+Desert Copper Edition$/i,
        "",
      ).replace(/\s+Forged/gi, "").trim();
    if (category === "iron" && !/\birons?$/i.test(name)) name += " Irons";
  }
  if (source.id === "miura") {
    name = name.replace(/ (?:QPQ|White Chrome|Copper|Raw|Black IP)$/i, "");
  }
  if (source.id === "takomo") {
    name = name.replace(/^Iron (.+?)(?: Driving Iron)?$/, "$1");
  }
  if (source.id === "honma") {
    const beres = name.match(
      /^(\d)-STAR (DRIVER|FAIRWAY(?: WOOD)?|HYBRID|IRON), (BERES \d+)( LADIES)?$/,
    );
    if (beres) {
      name = `${beres[3]}${beres[4] ? " Ladies" : ""} ${beres[1]}-Star ${
        beres[2].toLowerCase().replace(/^./, (c) => c.toUpperCase())
      }`;
    }
    name = name.replace(/^T\/\/WORLD IRON /, "T//WORLD ");
  }
  name = name.replace(/\s+Irons Womens$/i, " Women's Irons").replace(
    /\s+- Single Irons$/i,
    " Irons",
  ).replace(/\s+Irons Set$/i, " Irons");
  if (category === "iron") name = name.replace(/\s+Irons?$/i, "") + " Irons";
  if (category === "fairwayWood") {
    name = name.replace(/\s+Fairway(?:s| Woods?)?$/i, "") + " Fairway Woods";
  }
  if (category === "hybrid") {
    name = name.replace(/\s+Hybrids?$/i, "") + " Hybrids";
  }
  if (category === "putter") name = name.replace(/\s+Putters?$/i, "");
  if (category === "wedge") name = name.replace(/\s+Wedges?$/i, " Wedges");
  return name;
}

/** Expand only an explicitly published set range, never a category-wide default. */
function ironMarkings(input: string): string[] {
  let text = input.toUpperCase().replace(/#/g, "").replace(/[–—]/g, "-")
    .replace(/\s*\(SOLD OUT\)/g, "").replace(/\s+IRON$/, "").trim();
  // A loft suffix describes one head, not a range ("#4 - 23°" is a 4 iron).
  text = text.replace(/\s*-\s*\d+(?:\.\d+)?°/g, "");
  const range = text.match(/^(\d{1,2})\s*-\s*(\d{1,2}|PW|AW|GW|SW)\b(.*)$/);
  if (range) {
    const low = Number(range[1]),
      high = /^\d+$/.test(range[2]) ? Number(range[2]) : 9;
    if (low < 1 || high > 11 || high < low) return [];
    const result = Array.from(
      { length: high - low + 1 },
      (_, i) => `${low + i}I`,
    );
    if (!/^\d+$/.test(range[2])) {
      result.push("PW");
      if (range[2] !== "PW") result.push(range[2]);
    }
    return [...result, ...ironMarkings(range[3])];
  }
  const tokens = text.split(/\s*(?:&|\/|;|,)\s*/).filter(Boolean);
  if (tokens.length > 1) return tokens.flatMap(ironMarkings);
  if (/^(?:1[01]|[1-9])$/.test(text)) return [text + "I"];
  if (text === "P") return ["PW"];
  if (text === "G") return ["GW"];
  if (text === "S") return ["SW"];
  if (/^(?:PW|AW|GW|SW|UW|LW)$/.test(text)) return [text];
  return [];
}
function variantsFor(p: Product, category: Category): Family["variants"] {
  if (category === "driver") return [{ code: "1W", displayName: "Driver" }];
  if (category === "putter") return [{ code: "PT", displayName: "Putter" }];
  const values = p.options.filter((o) =>
    /^(?:club|loft(?: & grind)?|choose loft|set comp|set make ?up|full sets only|head|model)$/i
      .test(o.name)
  ).flatMap((o) => o.values);
  if (category === "iron" && !values.length) {
    const explicit = (p.body_html ?? "").replace(/<[^>]*>/g, " ").match(
      /(?:sets? come in a|set includes)\s+(\d{1,2}-(?:PW|AW|GW))\s+(?:configuration|set)/i,
    );
    if (explicit) values.push(explicit[1]);
  }
  const codes: string[] = [];
  for (const value of values) {
    const v = value.replace(/\s+(?:Right|Left) Handed(?: \(SOLD OUT\))?$/i, "")
      .trim();
    if (category === "iron") {
      codes.push(...ironMarkings(v));
      continue;
    }
    if (category === "wedge") {
      const loft = v.match(/^(\d{2}(?:\.\d+)?)(?:°|[A-Z]+|(?:\s*[-/].*))?$/i);
      if (loft && Number(loft[1]) >= 40 && Number(loft[1]) <= 70) {
        codes.push(Number(loft[1]) + "°");
      }
      continue;
    }
    const suffix = category === "fairwayWood"
      ? "W"
      : category === "utilityIron"
      ? "U"
      : "H";
    const marked = v.match(/^#?(\d{1,2})\s*-\s*(\d+(?:\.\d+)?)°$/);
    if (marked) {
      codes.push(`${marked[1]}${suffix}@${Number(marked[2])}°`);
      continue;
    }
    const number = v.match(/^(?:FW |IRON )?([1-9])(?:[WHU])?$/i);
    if (number) {
      codes.push(v.match(/[WHU]$/i) ? v.toUpperCase() : number[1] + suffix);
      continue;
    }
    if (/^[2-9](?:HF|HL|PL)$/.test(v)) {
      codes.push(v);
      continue;
    }
    const loft = v.match(/^(\d{2}(?:\.\d+)?)°?$/);
    if (loft && Number(loft[1]) >= 10 && Number(loft[1]) <= 40) {
      codes.push(Number(loft[1]) + "°");
    }
  }
  // Number + loft identifies the same head regardless of stock or new head releases.
  return sorted(codes).map((mark) => {
    const code = mark.replace("@", "-");
    return { code, displayName: code };
  });
}

export function parseShopifyCatalog(
  source: ShopifySource,
  value: unknown,
  checkedAt: string,
): Catalog {
  const products = (value as { products?: Product[] })?.products;
  if (!Array.isArray(products)) {
    throw new Error(`${source.brand} feed format changed`);
  }
  const families = new Map<string, Family>(), sources: Catalog["sources"] = [];
  const seenSources = new Set<string>();
  for (const p of products) {
    if (
      typeof p.title !== "string" || typeof p.product_type !== "string" ||
      !Array.isArray(p.options)
    ) throw new Error("Invalid product record");
    const category = classify(p);
    if (!category) continue;
    if (source.id === "evnroll" && p.product_type !== "Putters") continue;
    const acceptedVendor = typeof p.vendor === "string" &&
      (key(p.vendor).replace(/[^a-z]/g, "").includes(
        key(source.brand).replace(/[^a-z]/g, ""),
      ) || (source.id === "touredge" && p.vendor === "Exotics") ||
        (source.id === "bettinardi" && p.vendor === "Studio B") ||
        (source.id === "newlevel" && ["Sunmax", "Deson"].includes(p.vendor)));
    if (
      !acceptedVendor ||
      !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(p.handle)
    ) throw new Error(`Unexpected ${source.brand} product identity`);
    const variants = variantsFor(p, category);
    if (!variants.length) continue; // A future parser may support these specs; no generic range is invented.
    const baseName = nameFor(source, p, category),
      id = `${source.id}-${p.handle}`;
    const headModels = category === "putter"
      ? p.options.find((o) => o.name === "Model")?.values
      : undefined;
    const names = headModels?.length
      ? headModels.map((model) => {
        const head = model.replace(/\s*\((?:Left|Right|Red|Black)\)/gi, "")
          .replace(/^#0+(\d)/, "#$1").trim();
        return source.id === "newlevel" ? head : `${baseName} ${head}`;
      })
      : [baseName];
    if (!seenSources.has(id)) {
      sources.push({
        id,
        url: `${source.origin}/products/${p.handle}`,
        checkedAt,
      });
      seenSources.add(id);
    }
    for (const name of new Set(names)) {
      const identity = JSON.stringify([key(name), category]);
      const old = families.get(identity);
      const combined = new Map((old?.variants ?? []).map((v) => [v.code, v]));
      for (const v of variants) combined.set(v.code, v);
      families.set(identity, {
        brand: source.brand,
        name,
        category,
        sourceIDs: [...new Set([...(old?.sourceIDs ?? []), id])],
        variants: sorted([...combined.keys()]).map((c) => combined.get(c)!),
      });
    }
  }
  return validateCatalog({
    schemaVersion: 1,
    families: [...families.values()],
    sources,
  });
}

export async function fetchShopifyCatalog(
  source: ShopifySource,
  fetchJSON: (url: string) => Promise<unknown>,
  checkedAt: string,
): Promise<Catalog> {
  const products: Product[] = [];
  for (let page = 1; page <= source.maxPages; page++) {
    const body = await fetchJSON(
      `${source.origin}${source.path}?limit=${source.pageSize}&page=${page}`,
    ) as { products?: Product[] };
    if (!Array.isArray(body.products)) {
      throw new Error(`${source.brand} feed format changed`);
    }
    // Drop images, prices and generated custom-SKU records between pages.
    products.push(
      ...body.products.filter((p) =>
        !/mws_apo_generated|dropdown|hidden/i.test(p.product_type)
      ).map(({ title, handle, vendor, product_type, options, body_html }) => ({
        title,
        handle,
        vendor,
        product_type,
        options,
        body_html: body_html?.slice(0, 25_000),
      })),
    );
    if (body.products.length < source.pageSize) {
      const catalog = parseShopifyCatalog(source, { products }, checkedAt);
      if (
        catalog.families.length < source.minModels ||
        catalog.families.length > 600
      ) throw new Error(`${source.brand} feed count changed unexpectedly`);
      return catalog;
    }
  }
  throw new Error(`${source.brand} feed exceeded pagination limit`);
}
