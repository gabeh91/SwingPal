import { type Catalog, mergeCatalog, validateCatalog } from "./catalog.ts";
import { fetchLabCatalog } from "./lab.ts";
import { fetchShopifyCatalog, SHOPIFY_SOURCES } from "./shopify.ts";

export interface FeedJob {
  brand: string;
  load: () => Promise<Catalog>;
}
export interface FeedResult {
  brand: string;
  status: "updated" | "retained";
  models?: number;
  error?: string;
}

/** A blocked manufacturer never erases its history or prevents other brands updating. */
export async function collectFeeds(base: Catalog, jobs: FeedJob[]) {
  const results = await Promise.allSettled(jobs.map((job) => job.load()));
  let catalog = validateCatalog(base);
  const feeds: FeedResult[] = [];
  for (let i = 0; i < results.length; i++) {
    const result = results[i], brand = jobs[i].brand;
    try {
      if (result.status === "rejected") throw result.reason;
      catalog = mergeCatalog(catalog, result.value);
      feeds.push({
        brand,
        status: "updated",
        models: result.value.families.length,
      });
    } catch (error) {
      feeds.push({
        brand,
        status: "retained",
        error: error instanceof Error
          ? error.message.slice(0, 200)
          : "Feed unavailable",
      });
    }
  }
  if (!feeds.some((f) => f.status === "updated")) {
    throw new Error("All manufacturer feeds failed; previous catalog retained");
  }
  return { catalog, feeds };
}

export function manufacturerJobs(
  fetchJSON: (url: string) => Promise<unknown>,
  checkedAt: string,
): FeedJob[] {
  return [
    { brand: "LAB Golf", load: () => fetchLabCatalog(fetchJSON, checkedAt) },
    ...SHOPIFY_SOURCES.map((source) => ({
      brand: source.brand,
      load: () => fetchShopifyCatalog(source, fetchJSON, checkedAt),
    })),
  ];
}
