#!/usr/bin/env bash
set -euo pipefail

# Apply gamification migration to a Postgres database using psql.
# Requires: PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE environment variables.

SQL_FILE="$(pwd)/migrations/2025_09_12_gamification_setup.sql"

if [ ! -f "$SQL_FILE" ]; then
  echo "Migration file not found: $SQL_FILE"
  exit 1
fi

echo "Applying gamification migration: $SQL_FILE"

psql "$PGDATABASE" -h "$PGHOST" -p "${PGPORT:-5432}" -U "$PGUSER" -f "$SQL_FILE"

echo "Migration applied."


