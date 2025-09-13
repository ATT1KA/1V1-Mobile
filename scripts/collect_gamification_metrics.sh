#!/usr/bin/env bash
set -euo pipefail

# Collect simple gamification metrics via psql
# Requires PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE

PSQL_ARGS=("-h" "$PGHOST" "-p" "${PGPORT:-5432}" "-U" "$PGUSER" "$PGDATABASE")

echo "-- Total point transactions"
psql "${PSQL_ARGS[@]}" -c "select count(*) from user_points;"

echo "-- Total redemptions"
psql "${PSQL_ARGS[@]}" -c "select count(*) from point_redemptions;"

echo "-- Total unlocked rewards"
psql "${PSQL_ARGS[@]}" -c "select count(*) from user_unlocked;"

echo "-- Top 5 users by points"
psql "${PSQL_ARGS[@]}" -c "select id, username, total_points from profiles order by total_points desc limit 5;"


