import { type Catalog, mergeCatalog, validateCatalog } from "./catalog.ts";
import { collectFeeds, manufacturerJobs } from "./refresh.ts";
import { requestJSON } from "./http.ts";
import { publishCatalog } from "./publisher.ts";
import { createHandler } from "./handler.ts";

const projectURL = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const adminHeaders = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  "Content-Type": "application/json",
};
async function rpc(name: string, body: unknown) {
  return await requestJSON(`${projectURL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: adminHeaders,
    body: JSON.stringify(body),
  });
}

async function refresh() {
  const runID = crypto.randomUUID();
  if (!await rpc("begin_club_catalog_refresh", { p_run_id: runID })) {
    return { status: "already_running" };
  }
  const deadline = AbortSignal.timeout(60_000);
  try {
    const get = (path: string) =>
      requestJSON(`${projectURL}/storage/v1/object/authenticated/${path}`, {
        headers: adminHeaders,
        signal: deadline,
      });
    const seed = validateCatalog(await get("club-catalog-admin/source.json"));
    // Query object metadata so a missing live object is distinguished from an outage/error.
    const objects = await requestJSON(
      `${projectURL}/storage/v1/object/list/club-catalog`,
      {
        method: "POST",
        headers: adminHeaders,
        signal: deadline,
        body: JSON.stringify({
          prefix: "v1",
          limit: 100,
          search: "catalog.json",
        }),
      },
    ) as { name: string }[];
    const previous: Catalog | null = objects.some((o) =>
        o.name === "catalog.json"
      )
      ? validateCatalog(await get("club-catalog/v1/catalog.json"))
      : null;
    let candidate = previous ? mergeCatalog(previous, seed) : seed;
    // Vendor discovery has its own deadline, leaving time to archive and publish
    // successful brands even when one manufacturer's feed hangs.
    const vendorDeadline = AbortSignal.timeout(50_000);
    const collected = await collectFeeds(
      candidate,
      manufacturerJobs(
        (url) => requestJSON(url, { signal: vendorDeadline }, 8_000_000),
        new Date().toISOString().slice(0, 10),
      ),
    );
    candidate = collected.catalog;
    const publicationDeadline = AbortSignal.timeout(25_000);
    await publishCatalog(candidate, previous, {
      put: async (path, document) => {
        const bucket = path.startsWith("revisions/")
          ? "club-catalog-admin"
          : "club-catalog";
        await requestJSON(`${projectURL}/storage/v1/object/${bucket}/${path}`, {
          method: "POST",
          headers: {
            ...adminHeaders,
            "x-upsert": "true",
            "cache-control": path.startsWith("v1/")
              ? "max-age=300"
              : "max-age=31536000",
          },
          body: JSON.stringify(document),
          signal: publicationDeadline,
        });
      },
    }, runID);
    await rpc("finish_club_catalog_refresh", {
      p_run_id: runID,
      p_status: "published",
      p_detail: {
        models: candidate.families.length,
        feeds: collected.feeds,
        revision: runID,
      },
    });
    return {
      status: "published",
      models: candidate.families.length,
      brands: candidate.brands?.length,
      feeds: collected.feeds,
      revision: runID,
    };
  } catch (error) {
    await rpc("finish_club_catalog_refresh", {
      p_run_id: runID,
      p_status: "failed",
      p_detail: {
        error: error instanceof Error ? error.message : "Unknown error",
      },
    }).catch(() => {});
    throw error;
  }
}

Deno.serve(createHandler(Deno.env.get("CATALOG_CRON_SECRET") ?? "", refresh));
