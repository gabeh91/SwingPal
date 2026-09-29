import { type Catalog } from "./catalog.ts";
import { collectFeeds } from "./refresh.ts";

const seed: Catalog = {
  schemaVersion: 1,
  sources: [{
    id: "reviewed",
    url: "https://ping.com/en-us/golf-clubs/irons",
    checkedAt: "2026-09-28",
  }],
  families: [{
    brand: "PING",
    name: "i540 Irons",
    category: "iron",
    sourceIDs: ["reviewed"],
    variants: [{ code: "4I", displayName: "4I" }, {
      code: "5I",
      displayName: "5I",
    }],
  }],
};
function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
Deno.test("one unavailable brand retains its data while other validated feeds publish", async () => {
  const incoming = structuredClone(seed);
  incoming.families[0].variants = [{ code: "6I", displayName: "6I" }];
  const result = await collectFeeds(seed, [
    {
      brand: "Cobra",
      load: () => Promise.reject(new Error("Upstream HTTP 429")),
    },
    { brand: "PING", load: () => Promise.resolve(incoming) },
  ]);
  assert(result.catalog.families[0].variants.length === 3);
  assert(result.feeds[0].status === "retained");
  assert(result.feeds[1].status === "updated");
});
Deno.test("malformed feed cannot contaminate successful brands and all failures are reported", async () => {
  let failed = false;
  try {
    await collectFeeds(seed, [{
      brand: "PING",
      load: () => Promise.resolve({ ...seed, schemaVersion: 2 }),
    }]);
  } catch {
    failed = true;
  }
  assert(failed);
  const result = await collectFeeds(seed, [
    {
      brand: "Bad",
      load: () => Promise.resolve({ ...seed, schemaVersion: 2 }),
    },
    { brand: "PING", load: () => Promise.resolve(seed) },
  ]);
  assert(result.catalog.families.length === 1);
  assert(result.feeds[0].status === "retained");
});
