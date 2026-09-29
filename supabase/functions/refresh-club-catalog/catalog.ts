export type Category =
  | "driver"
  | "fairwayWood"
  | "hybrid"
  | "utilityIron"
  | "iron"
  | "wedge"
  | "putter";
export interface Source {
  id: string;
  url: string;
  checkedAt: string;
}
export interface Family {
  brand: string;
  name: string;
  category: Category;
  sourceIDs: string[];
  variants: { code: string; displayName: string }[];
}
export interface Catalog {
  schemaVersion: number;
  sources: Source[];
  families: Family[];
  brands?: string[];
}
const categories = new Set([
  "driver",
  "fairwayWood",
  "hybrid",
  "utilityIron",
  "iron",
  "wedge",
  "putter",
]);
const hosts = new Set([
  "www.callawaygolf.com",
  "us.dunlopsports.com",
  "www.cobragolf.com",
  "honmagolf.com",
  "us.honmagolf.com",
  "labgolf.com",
  "miuragolf.com",
  "mizunogolf.com",
  "odyssey.callawaygolf.com",
  "ping.com",
  "ca.ping.com",
  "eu.ping.com",
  "www.pxg.com",
  "www.scottycameron.com",
  "takomogolf.com",
  "www.taylormadegolf.com",
  "www.titleist.com",
  "www.touredge.com",
  "www.wilson.com",
  "bettinardi.com",
  "www.evnroll.com",
  "newlevelgolf.com",
  "www.pxg.com.au",
  "www.haywoodgolf.com",
]);
function text(value: unknown): string {
  // deno-lint-ignore no-control-regex -- labels must reject control characters
  if (typeof value !== "string" || /[\u0000-\u001f\u007f]/.test(value)) {
    throw new Error("Invalid catalog text");
  }
  const result = value.trim().replace(/\s+/g, " ");
  if (!result || result.length > 160) {
    throw new Error("Invalid catalog text length");
  }
  return result;
}
export const key = (value: string) =>
  value.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();
const familyKey = (f: Family) =>
  JSON.stringify([key(f.brand), key(f.name), f.category]);
function unique(set: Set<string>, value: string, context: string) {
  if (set.has(value)) throw new Error(`Duplicate ${context}`);
  set.add(value);
}

/** Only well-formed, sourced facts enter the public catalog; no club ranges are inferred. */
export function validateCatalog(value: unknown): Catalog {
  const input = value as Catalog;
  if (
    input?.schemaVersion !== 1 || !Array.isArray(input.sources) ||
    !Array.isArray(input.families) ||
    !input.families.length || input.families.length > 10_000 ||
    input.sources.length > 10_000
  ) throw new Error("Invalid catalog schema");
  const sourceIDs = new Set<string>();
  const sources = input.sources.map((s) => {
    const id = text(s.id), url = new URL(s.url);
    unique(sourceIDs, id, "source");
    if (
      url.protocol !== "https:" || url.username || url.password || url.port ||
      !hosts.has(url.hostname)
    ) throw new Error("Unapproved source URL");
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(s.checkedAt) ||
      !Number.isFinite(Date.parse(s.checkedAt)) ||
      new Date(s.checkedAt).toISOString().slice(0, 10) !== s.checkedAt
    ) throw new Error("Invalid source date");
    return { id, url: url.href, checkedAt: s.checkedAt };
  });
  const identities = new Set<string>(),
    savedClubs = new Set<string>(),
    used = new Set<string>();
  const brands = new Map<string, string>();
  const families = input.families.map((f) => {
    const brand = text(f.brand), name = text(f.name);
    if (
      !categories.has(f.category) || !Array.isArray(f.variants) ||
      !f.variants.length || f.variants.length > 100 ||
      !Array.isArray(f.sourceIDs) || !f.sourceIDs.length
    ) throw new Error("Invalid model structure");
    if (brands.has(key(brand)) && brands.get(key(brand)) !== brand) {
      throw new Error("Inconsistent brand spelling");
    }
    brands.set(key(brand), brand);
    unique(identities, familyKey({ ...f, brand, name }), "model");
    const codes = new Set<string>();
    const variants = f.variants.map((v) => {
      const code = text(v.code), displayName = text(v.displayName);
      unique(codes, key(code), "club code");
      unique(
        savedClubs,
        JSON.stringify([key(brand), key(name), key(displayName)]),
        "saved club identity",
      );
      return { code, displayName };
    });
    const refs = [...new Set(f.sourceIDs.map(text))].sort();
    for (const ref of refs) {
      if (!sourceIDs.has(ref)) throw new Error("Unknown model source");
      used.add(ref);
    }
    return { brand, name, category: f.category, sourceIDs: refs, variants };
  }).sort((a, b) => familyKey(a).localeCompare(familyKey(b), "en"));
  const output = {
    schemaVersion: 1,
    brands: [...brands.values()].sort(),
    sources: sources.filter((s) => used.has(s.id)).sort((a, b) =>
      a.id.localeCompare(b.id, "en")
    ),
    families,
  };
  if (new TextEncoder().encode(JSON.stringify(output)).length > 2_000_000) {
    throw new Error("Catalog exceeds app size limit");
  }
  return output;
}

/** Missing products are retained: discontinued models still belong in golfers' bags. */
export function mergeCatalog(base: Catalog, updates: Catalog): Catalog {
  const current = validateCatalog(base), incoming = validateCatalog(updates);
  const families = new Map(current.families.map((f) => [familyKey(f), f]));
  for (const family of incoming.families) {
    const previous = families.get(familyKey(family));
    if (!previous) {
      families.set(familyKey(family), family);
      continue;
    }
    // Stock availability is not the historical specification. Retain known club
    // identities and provenance; deleting/correcting one requires a reviewed migration.
    const variants = [...previous.variants];
    const codes = new Set(variants.map((v) => key(v.code)));
    const labels = new Set(variants.map((v) => key(v.displayName)));
    for (const variant of family.variants) {
      if (
        codes.has(key(variant.code)) || labels.has(key(variant.displayName))
      ) continue;
      variants.push(variant);
      codes.add(key(variant.code));
      labels.add(key(variant.displayName));
    }
    families.set(familyKey(family), {
      ...previous,
      variants,
      sourceIDs: [...new Set([...previous.sourceIDs, ...family.sourceIDs])],
    });
  }
  const sources = new Map(current.sources.map((s) => [s.id, s]));
  for (const source of incoming.sources) sources.set(source.id, source);
  return validateCatalog({
    schemaVersion: 1,
    families: [...families.values()],
    sources: [...sources.values()],
  });
}
