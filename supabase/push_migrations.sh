#!/usr/bin/env bash
# Push local SQL migrations to your hosted Supabase project.
#
# Prerequisites:
#   1. brew install supabase/tap/supabase
#   2. supabase login   # opens browser; stores access token
#
# Usage (from repo root):
#   ./supabase/push_migrations.sh
#
# If `supabase link` asks for the database password, pass it:
#   ./supabase/push_migrations.sh -p 'YOUR_DATABASE_PASSWORD'
#
# Override project ref (defaults to SwingPal hosted project):
#   SUPABASE_PROJECT_REF=otherref ./supabase/push_migrations.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${SUPABASE_PROJECT_REF:-zhmvngzfhzyyvyseeaxi}"

if ! command -v supabase >/dev/null 2>&1; then
  echo "Install the Supabase CLI: brew install supabase/tap/supabase" >&2
  exit 1
fi

echo "→ supabase link --project-ref $REF $@"
supabase link --project-ref "$REF" "$@"

echo "→ supabase db push"
supabase db push

echo "Done. Migrations applied to remote database."
