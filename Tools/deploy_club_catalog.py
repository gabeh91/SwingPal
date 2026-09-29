#!/usr/bin/env python3
"""Deploy the catalog to the linked Supabase project using existing CLI login.

No secrets are printed or committed. The recurring job is enabled only after an
authenticated initial refresh succeeds. Review pending migrations before running.
"""
import json
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.error
import urllib.request
from urllib.parse import urlencode

ROOT = Path(__file__).resolve().parents[1]


def cli(*args, capture=False):
    result = subprocess.run(["supabase", *args], cwd=ROOT, check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout


def query(sql):
    result = json.loads(cli("db", "query", "--linked", "--output", "json", sql, capture=True))
    return result["rows"] if isinstance(result, dict) else result


def http(url, body=None, headers=None):
    request = urllib.request.Request(url, data=body, headers=headers or {})
    with urllib.request.urlopen(request, timeout=100) as response:
        return json.load(response)


def main():
    ref = (ROOT / "supabase/.temp/project-ref").read_text().strip()
    if not re.fullmatch(r"[a-z]{20}", ref):
        raise RuntimeError("Link a hosted Supabase project before deploying")
    url = f"https://{ref}.supabase.co"
    print(f"Deploying club catalog to linked project {ref}", flush=True)
    subprocess.run(["deno", "test", "supabase/functions/refresh-club-catalog"], cwd=ROOT, check=True)
    subprocess.run(["swift", "Tools/club_catalog_import.swift", "--source", "Tools/club_catalog_sources.json",
                    "--output", "SwingPal/Resources/club_catalog.json", "--check"], cwd=ROOT, check=True)
    subprocess.run(["deno", "eval", 'import {validateCatalog} from "./supabase/functions/refresh-club-catalog/catalog.ts"; validateCatalog(JSON.parse(await Deno.readTextFile("Tools/club_catalog_sources.json")));'], cwd=ROOT, check=True)
    cli("db", "push", "--yes")
    # Match Vault and Edge configuration while keeping the generated token out of argv/logs.
    secret = query("select decrypted_secret as token from vault.decrypted_secrets where name = 'club_catalog_cron_secret';")[0]["token"]
    with tempfile.TemporaryDirectory(prefix="swingpal-catalog-") as directory:
        env_file = Path(directory) / "catalog.env"
        env_file.touch(mode=0o600)
        env_file.write_text(f"CATALOG_CRON_SECRET={secret}\n")
        cli("secrets", "set", "--project-ref", ref, "--env-file", str(env_file))
    cli("functions", "deploy", "refresh-club-catalog", "--project-ref", ref, "--use-api")
    keys = json.loads(cli("projects", "api-keys", "--project-ref", ref, "--output", "json", capture=True))
    service = next(k["api_key"] for k in keys if k["name"] == "service_role")
    http(f"{url}/storage/v1/object/club-catalog-admin/source.json",
         (ROOT / "Tools/club_catalog_sources.json").read_bytes(),
         {"Authorization": f"Bearer {service}", "apikey": service, "Content-Type": "application/json", "x-upsert": "true"})
    result = http(f"{url}/functions/v1/refresh-club-catalog", b"{}",
                  {"Content-Type": "application/json", "x-catalog-secret": secret})
    if result.get("status") != "published":
        raise RuntimeError(f"Initial refresh did not publish: {result.get('status')}")
    # Confirm public unauthenticated access before scheduling the recurring refresh.
    public = http(f"{url}/storage/v1/object/public/club-catalog/v1/catalog.json?" +
                  urlencode({"revision": result["revision"]}))
    if public.get("schemaVersion") != 1 or len(public.get("families", [])) != result["models"]:
        raise RuntimeError("Public catalog readback did not match publication")
    query(f"""do $$ declare secret_id uuid; begin
      select id into secret_id from vault.secrets where name = 'club_catalog_project_url';
      if secret_id is null then
        perform vault.create_secret('{url}', 'club_catalog_project_url');
      else
        perform vault.update_secret(secret_id, '{url}');
      end if;
    end $$;
    select cron.schedule('refresh-club-catalog', '0 3 * * *', 'select public.invoke_club_catalog_refresh();');
    select cron.alter_job(jobid, active := true) from cron.job where jobname = 'refresh-club-catalog';""")
    print(f"Published {result['models']} models. Daily refresh enabled at 03:00 UTC.")
    print(f"Catalog: {url}/storage/v1/object/public/club-catalog/v1/catalog.json")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        # Storage/function errors contain no credentials, but keep logs minimal regardless.
        print(f"Deployment stopped: HTTP {error.code}. Check Supabase function/run logs.")
        raise SystemExit(1)
