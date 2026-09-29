import { type Catalog, validateCatalog } from "./catalog.ts";

/** Shopify's published stock-putter title + tag identify a model, not a shaft/length SKU. */
export function parseLabProducts(value: unknown, checkedAt: string): Catalog {
  const products = (value as { products?: unknown[] })?.products;
  if (!Array.isArray(products)) throw new Error("L.A.B. feed format changed");
  const catalog: Catalog = { schemaVersion: 1, families: [], sources: [] };
  for (const item of products) {
    const p = item as {
      title?: string;
      handle?: string;
      vendor?: string;
      tags?: string[];
      variants?: unknown[];
    };
    if (
      typeof p.title !== "string" || !p.title.endsWith(" STOCK PUTTER") ||
      !Array.isArray(p.tags) || !p.tags.includes("stock-putter")
    ) continue;
    if (
      !p.vendor?.match(/^L\.A\.B\.? Golf(?: Partner Store)?$/) ||
      !p.handle?.match(/^[a-z0-9]+(?:-[a-z0-9]+)*$/) ||
      !Array.isArray(p.variants) || !p.variants.length
    ) throw new Error("Unrecognized L.A.B. stock putter");
    const name = p.title.slice(0, -" STOCK PUTTER".length).trim();
    // Narrow structured model grammar: unexpected marketing titles stop publication for inspection.
    if (!/^[A-Z][A-Z0-9. ]{0,40}i?(?: HS| MAX)?$/.test(name)) {
      throw new Error("Unrecognized L.A.B. model name");
    }
    const id = `lab-stock-${p.handle}`;
    catalog.sources.push({
      id,
      url: `https://labgolf.com/products/${p.handle}`,
      checkedAt,
    });
    catalog.families.push({
      brand: "LAB Golf",
      name,
      category: "putter",
      sourceIDs: [id],
      variants: [{ code: "PT", displayName: "Putter" }],
    });
  }
  return validateCatalog(catalog); // An empty or duplicate feed fails closed.
}

export async function fetchLabCatalog(
  fetchJSON: (url: string) => Promise<unknown>,
  checkedAt: string,
): Promise<Catalog> {
  const products: unknown[] = [];
  for (let page = 1; page <= 4; page++) {
    const body = await fetchJSON(
      `https://labgolf.com/products.json?limit=250&page=${page}`,
    ) as { products?: unknown[] };
    if (!Array.isArray(body.products)) {
      throw new Error("L.A.B. feed format changed");
    }
    products.push(...body.products);
    if (body.products.length < 250) {
      const catalog = parseLabProducts({ products }, checkedAt);
      // A partial storefront response must not masquerade as a successful full refresh.
      if (catalog.families.length < 5 || catalog.families.length > 100) {
        throw new Error("Unexpected L.A.B. model count");
      }
      return catalog;
    }
  }
  throw new Error("L.A.B. feed exceeded pagination limit");
}
