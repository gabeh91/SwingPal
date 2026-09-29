import { type Catalog, validateCatalog } from "./catalog.ts";

export interface CatalogStorage {
  put(path: string, document: Catalog): Promise<void>;
}

export async function publishCatalog(
  candidate: Catalog,
  previous: Catalog | null,
  storage: CatalogStorage,
  runID: string,
) {
  const clean = validateCatalog(candidate);
  if (previous) {
    const old = validateCatalog(previous);
    if (clean.families.length < old.families.length) {
      throw new Error("Automatic publication cannot remove models");
    }
    await storage.put(`revisions/${runID}-previous.json`, old);
  }
  await storage.put(`revisions/${runID}.json`, clean);
  // Storage replaces one complete object; a failed source/validation/archive leaves live JSON intact.
  await storage.put("v1/catalog.json", clean);
}
