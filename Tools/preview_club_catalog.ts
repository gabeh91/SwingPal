// Fetch and validate all configured manufacturer feeds without publishing.
// deno run --allow-net --allow-read --allow-write Tools/preview_club_catalog.ts /tmp/catalog-preview.json
import { validateCatalog } from "../supabase/functions/refresh-club-catalog/catalog.ts";
import {
  collectFeeds,
  manufacturerJobs,
} from "../supabase/functions/refresh-club-catalog/refresh.ts";
import { requestJSON } from "../supabase/functions/refresh-club-catalog/http.ts";
const destination = Deno.args[0];
if (!destination) {
  throw new Error("Specify an output JSON path (does not publish)");
}
const seed = validateCatalog(
  JSON.parse(
    await Deno.readTextFile(
      new URL("./club_catalog_sources.json", import.meta.url),
    ),
  ),
);
const deadline = AbortSignal.timeout(90_000);
const jobs = manufacturerJobs(
  (url) => requestJSON(url, { signal: deadline }, 8_000_000),
  new Date().toISOString().slice(0, 10),
);
const result = await collectFeeds(seed, jobs);
await Deno.writeTextFile(
  destination,
  JSON.stringify(result.catalog, null, 2) + "\n",
);
await Deno.writeTextFile(
  destination + ".report.json",
  JSON.stringify(result.feeds, null, 2) + "\n",
);
console.log(
  JSON.stringify(
    {
      models: result.catalog.families.length,
      brands: result.catalog.brands,
      feeds: result.feeds,
    },
    null,
    2,
  ),
);
