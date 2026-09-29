// deno-lint-ignore-file require-await -- asynchronous storage and job test doubles
import { type Catalog, mergeCatalog, validateCatalog } from "./catalog.ts";
import { parseLabProducts } from "./lab.ts";
import { type CatalogStorage, publishCatalog } from "./publisher.ts";
import { createHandler } from "./handler.ts";

function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
function rejects(fn: () => unknown) {
  try {
    fn();
  } catch {
    return;
  }
  throw new Error("Expected invalid catalog to be rejected");
}
const seed = (): Catalog => ({
  schemaVersion: 1,
  brands: ["PING"],
  sources: [{
    id: "ping",
    url: "https://ping.com/en-us/clubs/irons/g440",
    checkedAt: "2026-09-28",
  }],
  families: [{
    brand: "PING",
    name: "G440 Irons",
    category: "iron",
    sourceIDs: ["ping"],
    variants: [{ code: "7I", displayName: "7I" }],
  }],
});
const product = (title = "DF3i STOCK PUTTER", handle = "df3i-stock") => ({
  title,
  handle,
  vendor: "L.A.B. Golf",
  tags: ["stock-putter"],
  variants: [{ id: 123 }],
});

Deno.test("catalog normalization is deterministic and preserves explicit markings", () => {
  const input = seed();
  input.families[0].name = "  G440  Irons ";
  input.brands = ["unused"];
  const clean = validateCatalog(input);
  assert(clean.families[0].name === "G440 Irons");
  assert(clean.brands?.join() === "PING");
  assert(clean.families[0].variants[0].code === "7I");
  assert(JSON.stringify(validateCatalog(clean)) === JSON.stringify(clean));
});
Deno.test("unknown schemas, empty catalogs, unsafe sources and duplicate saved identities fail", () => {
  for (
    const change of [
      (x: Catalog) => {
        x.schemaVersion = 2;
      },
      (x: Catalog) => {
        x.families = [];
      },
      (x: Catalog) => {
        x.sources[0].url = "http://ping.com";
      },
      (x: Catalog) => {
        x.sources[0].checkedAt = "2026-02-30";
      },
      (x: Catalog) => {
        x.families[0].sourceIDs = ["missing"];
      },
      (x: Catalog) => {
        x.families[0].variants.push({ code: "seven", displayName: "7i" });
      },
      (x: Catalog) => {
        x.families.push({ ...x.families[0], category: "utilityIron" });
      },
    ]
  ) {
    const input = seed();
    change(input);
    rejects(() => validateCatalog(input));
  }
});
Deno.test("manufacturer adapter accepts only explicit stock putters and retains model spelling", () => {
  const feed = {
    products: [product(), {
      ...product("DF3 HEADCOVER"),
      tags: ["accessories"],
    }, product("DF3 CUSTOM PUTTER")],
  };
  const result = parseLabProducts(feed, "2026-09-28");
  assert(result.families.length === 1);
  assert(result.families[0].name === "DF3i");
  assert(result.families[0].variants[0].displayName === "Putter");
  assert(result.sources[0].url === "https://labgolf.com/products/df3i-stock");
  rejects(() => parseLabProducts({ products: [] }, "2026-09-28"));
  rejects(() =>
    parseLabProducts(
      { products: [product("DF3 STOCK PUTTER", "../admin")] },
      "2026-09-28",
    )
  );
});
Deno.test("merge preserves older models and unsupported brands while updating supported records", () => {
  const feed = parseLabProducts({ products: [product()] }, "2026-09-28");
  const first = mergeCatalog(seed(), feed);
  assert(first.families.length === 2);
  const next = mergeCatalog(
    first,
    parseLabProducts(
      { products: [product("OZ.1 STOCK PUTTER", "oz1-stock")] },
      "2026-09-29",
    ),
  );
  assert(next.families.length === 3);
  assert(next.families.some((x) => x.name === "DF3i"));
});
Deno.test("partial stock feeds retain verified clubs, labels and provenance", () => {
  const base = seed();
  base.families[0].variants.push({ code: "GW", displayName: "GW" });
  const feed = seed();
  feed.sources[0].id = "ping-stock";
  feed.families[0].sourceIDs = ["ping-stock"];
  feed.families[0].variants = [
    { code: "7I", displayName: "7 iron" },
    { code: "8I", displayName: "8I" },
    { code: "gap", displayName: "GW" },
  ];
  const merged = mergeCatalog(base, feed).families[0];
  assert(merged.variants.map((v) => v.code).join() === "7I,GW,8I");
  assert(merged.variants[0].displayName === "7I");
  assert(merged.sourceIDs.join() === "ping,ping-stock");
});
Deno.test("publication archives before live replacement and never publishes if backup fails", async () => {
  const writes: string[] = [];
  const storage: CatalogStorage = {
    put: async (path) => {
      writes.push(path);
      if (path.startsWith("revisions/")) throw new Error("unavailable");
    },
  };
  let failed = false;
  try {
    await publishCatalog(seed(), seed(), storage, "run-one");
  } catch {
    failed = true;
  }
  assert(failed);
  assert(writes.every((x) => x !== "v1/catalog.json"));
});
Deno.test("publication retains prior revision and publishes a complete new object", async () => {
  const writes = new Map<string, Catalog>();
  const storage: CatalogStorage = {
    put: async (path, document) => {
      writes.set(path, document);
    },
  };
  const next = mergeCatalog(
    seed(),
    parseLabProducts({ products: [product()] }, "2026-09-28"),
  );
  await publishCatalog(next, seed(), storage, "run-two");
  assert(writes.get("revisions/run-two-previous.json")?.families.length === 1);
  assert(writes.get("v1/catalog.json")?.families.length === 2);
  assert([...writes.keys()].at(-1) === "v1/catalog.json");
});

Deno.test("invalid candidates never write any object", async () => {
  let writes = 0;
  const input = seed();
  input.families = [];
  try {
    await publishCatalog(input, seed(), {
      put: async () => {
        writes++;
      },
    }, "invalid");
  } catch { /* expected */ }
  assert(writes === 0);
});
Deno.test("publisher rejects automatic model removal", async () => {
  let writes = 0, failed = false;
  const previous = mergeCatalog(
    seed(),
    parseLabProducts({ products: [product()] }, "2026-09-28"),
  );
  try {
    await publishCatalog(seed(), previous, {
      put: async () => {
        writes++;
      },
    }, "invalid");
  } catch {
    failed = true;
  }
  assert(failed && writes === 0);
});
Deno.test("cron authentication rejects public keys, missing secrets and wrong methods before work", async () => {
  let runs = 0;
  const secret = "a".repeat(64);
  const run = async () => {
    runs++;
    return { status: "published" };
  };
  const handler = createHandler(secret, run);
  const unauthorized: Record<string, string>[] = [{}, {
    apikey: "publishable-key",
  }, { "x-catalog-secret": "wrong" }];
  for (const headers of unauthorized) {
    assert(
      (await handler(
        new Request("https://example.com", { method: "POST", headers }),
      )).status === 401,
    );
  }
  assert((await handler(new Request("https://example.com"))).status === 405);
  assert(
    (await createHandler("", run)(
      new Request("https://example.com", { method: "POST" }),
    )).status === 401,
  );
  assert(runs === 0);
  assert(
    (await handler(
      new Request("https://example.com", {
        method: "POST",
        headers: { "x-catalog-secret": secret },
      }),
    )).status === 200,
  );
  assert(Number(runs) === 1);
});
