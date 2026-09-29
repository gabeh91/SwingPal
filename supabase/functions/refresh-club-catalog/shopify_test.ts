import fixtures from "./fixtures/shopify.json" with { type: "json" };
import { parseShopifyCatalog, SHOPIFY_SOURCES } from "./shopify.ts";

function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
function catalog(id: string, products?: unknown[]) {
  const source = SHOPIFY_SOURCES.find((s) => s.id === id)!;
  return parseShopifyCatalog(source, {
    products: products ?? fixtures[id as keyof typeof fixtures].products,
  }, "2026-09-28");
}
Deno.test("Cobra reads actual club options and ignores shaft dimensions", () => {
  const result = catalog("cobra");
  assert(
    result.families.find((f) => f.name === "OPTM X Fairway Woods")?.variants
      .map((v) => v.code).join() === "3W,3HF,5W,7W,9W",
  );
  assert(
    result.families.find((f) => f.name === "KING Irons")?.variants.map((v) =>
      v.code
    ).join() === "4I,5I,6I,7I,8I,9I,PW,GW,SW",
  );
  assert(
    result.families.find((f) => f.category === "putter")?.variants[0].code ===
      "PT",
  );
});
Deno.test("Tour Edge uses title and published options even when product_type incorrectly says Drivers", () => {
  const result = catalog("touredge");
  const irons = result.families.find((f) => f.name === "Exotics Max Irons")!;
  assert(irons.category === "iron");
  assert(
    irons.variants.map((v) => v.code).join() ===
      "4I,5I,6I,7I,8I,9I,PW,AW,GW,SW",
  );
  const fairway = result.families.find((f) =>
    f.name === "Exotics Max Fairway Woods"
  )!;
  assert(fairway.variants.some((v) => v.code === "3W-15°"));
  assert(fairway.variants.some((v) => v.code === "3W-16.5°"));
});
Deno.test("Honma retains 10/11 iron markings and loft-only offerings", () => {
  const result = catalog("honma");
  const iron = result.families.find((f) => f.name === "TW777 PCB MAX Irons")!;
  assert(iron.variants.some((v) => v.code === "11I"));
  assert(
    result.families.find((f) => f.name === "TW777 Hybrids")?.variants[0]
      .code === "3U",
  );
});
Deno.test("Takomo distinguishes utility irons and deduplicates wedge grinds", () => {
  const result = catalog("takomo");
  assert(
    result.families.find((f) => f.category === "utilityIron")?.variants.map((
      v,
    ) => v.code).join() === "2U,3U,4U",
  );
  assert(
    result.families.find((f) => f.category === "wedge")?.variants.map((v) =>
      v.code
    ).join() === "46°,48°,50°,52°,54°,56°,58°,60°",
  );
});
Deno.test("missing club specs never fabricate a generic iron range; accessories and test products are skipped", () => {
  const original = fixtures.cobra.products[0];
  const result = catalog("cobra", [original, {
    ...original,
    title: "Unspecified Irons",
    handle: "unspecified-irons",
    options: [],
  }, {
    ...original,
    title: "Driver Headcover",
    handle: "headcover",
    product_type: "Headcover",
  }, { ...original, title: "Test Putter", handle: "test-putter" }]);
  assert(result.families.length === 1);
});
Deno.test("Bettinardi and Evnroll accept named production putters without custom-build duplicates", () => {
  assert(catalog("bettinardi").families.length === 2);
  const evnroll = catalog("evnroll");
  assert(evnroll.families.length === 2);
  assert(evnroll.families.some((f) => f.name === "ORIGIN ER8cs"));
});
Deno.test("New Level uses explicit heads and ignores component shafts", () => {
  const result = catalog("newlevel");
  assert(result.families.length === 4);
  assert(
    result.families.find((f) => f.name === "702 CB Irons")?.variants.map((v) =>
      v.code
    ).join() === "4I,5I,6I,7I,8I,9I,PW",
  );
  assert(
    result.families.find((f) => f.category === "hybrid")?.variants.map((v) =>
      v.code
    ).join() === "17°,20°,23°",
  );
  assert(
    result.families.find((f) => f.category === "wedge")?.variants.map((v) =>
      v.code
    ).join() === "54°,56°,58°,60°",
  );
});
Deno.test("multi-head putter listings expand actual models and collapse handedness/finish choices", () => {
  const result = catalog("touredge", [{
    title: "HP Series Putters",
    handle: "hp-series-putters",
    vendor: "Tour Edge",
    product_type: "Putters",
    options: [{ name: "Model", values: ["#2 (Red)", "#02 (Left)", "#4"] }, {
      name: "Length",
      values: ["33", "34"],
    }],
  }]);
  assert(
    result.families.map((f) => f.name).join() === "HP Series #2,HP Series #4",
  );
  assert(
    result.families.every((f) =>
      f.variants.length === 1 && f.variants[0].code === "PT"
    ),
  );
});
Deno.test("iron number plus loft is not mistaken for a numbered set range", () => {
  const result = catalog("touredge", [{
    title: "Hot Launch E524 Ironwoods",
    handle: "hot-launch-e524-ironwoods",
    vendor: "Tour Edge",
    product_type: "Irons",
    options: [{
      name: "Loft",
      values: [
        "#4 - 23°",
        "#5 - 26°",
        "#6 - 29°",
        "#7 - 32°",
        "#8 - 36°",
        "#9 - 40°",
        "PW - 44°",
        "AW - 49°",
      ],
    }],
  }]);
  assert(
    result.families[0].variants.map((v) => v.code).join() ===
      "4I,5I,6I,7I,8I,9I,PW,AW",
  );
});
Deno.test("number-and-loft head identity never changes when another loft appears", () => {
  const product = {
    title: "Exotics LS Fairway Wood",
    handle: "exotics-ls-fairway-wood",
    vendor: "Tour Edge",
    product_type: "Fairways",
    options: [{ name: "Loft", values: ["#3-15°", "#5-18°"] }],
  };
  const before = catalog("touredge", [product]).families[0];
  const after = catalog("touredge", [{
    ...product,
    options: [{ name: "Loft", values: ["#3-13°", "#3-15°", "#5-18°"] }],
  }]).families[0];
  assert(before.variants[0].code === "3W-15°");
  assert(
    after.variants.some((v) =>
      v.code === before.variants[0].code &&
      v.displayName === before.variants[0].displayName
    ),
  );
  assert(after.variants.some((v) => v.code === "3W-13°"));
});
