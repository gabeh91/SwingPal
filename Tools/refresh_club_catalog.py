#!/usr/bin/env python3
"""Run the deployed importer once and verify its public result; uses existing CLI login."""
import json
import re
import uuid
from collections import Counter
import urllib.error

from deploy_club_catalog import ROOT, http, query


def main():
    ref = (ROOT / "supabase/.temp/project-ref").read_text().strip()
    if not re.fullmatch(r"[a-z]{20}", ref):
        raise RuntimeError("Link the intended Supabase project first")
    base = f"https://{ref}.supabase.co"
    public_url = f"{base}/storage/v1/object/public/club-catalog/v1/catalog.json"
    before = http(public_url + f"?revision={uuid.uuid4()}")
    # Capture the Vault token privately; never include credentials in argv or output.
    secret = query("select decrypted_secret as token from vault.decrypted_secrets where name = 'club_catalog_cron_secret';")[0]["token"]
    result = http(f"{base}/functions/v1/refresh-club-catalog", b"{}",
                  {"Content-Type": "application/json", "x-catalog-secret": secret})
    if result.get("status") != "published":
        raise RuntimeError(f"Importer did not publish: {result.get('status')}")
    after = http(public_url + f"?revision={result['revision']}")
    if after.get("schemaVersion") != 1 or len(after.get("families", [])) != result["models"]:
        raise RuntimeError("Public readback does not match publication")
    old = Counter(f["brand"] for f in before["families"])
    new = Counter(f["brand"] for f in after["families"])
    print(json.dumps({"status": "published", "revision": result["revision"],
                      "modelsBefore": len(before["families"]), "modelsAfter": len(after["families"]),
                      "clubs": sum(len(f["variants"]) for f in after["families"]),
                      "brands": dict(sorted(new.items())),
                      "modelsAddedByBrand": {b: n - old[b] for b, n in sorted(new.items()) if n > old[b]},
                      "feeds": result.get("feeds", [])}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        print(f"Importer stopped: HTTP {error.code}. Check Supabase function/run logs.")
        raise SystemExit(1)
