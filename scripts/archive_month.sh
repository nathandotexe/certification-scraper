#!/usr/bin/env bash
# © AngelaMos | 2026
# scripts/archive_month.sh
#
# Copies the latest global and Indonesia-filtered certification CSVs into a
# dated snapshot under site/history/<YYYY-MM>/, then rebuilds site/months.json
# so the static download page (site/index.html) knows what's available.
# Re-running within the same month overwrites that month's snapshot with the
# freshest data; a new month starts a new folder.

set -euo pipefail
cd "$(dirname "$0")/.."

month=$(date -u +"%Y-%m")
mkdir -p "site/history/$month/global" "site/history/$month/indonesia"

if [ -f output/data/certifications.csv ]; then
  cp output/data/certifications.csv "site/history/$month/global/certifications.csv"
  cp output/data/summary.json "site/history/$month/global/summary.json"
fi

if [ -f output/indonesia/data/certifications.csv ]; then
  cp output/indonesia/data/certifications.csv "site/history/$month/indonesia/certifications.csv"
  cp output/indonesia/data/summary.json "site/history/$month/indonesia/summary.json"
fi

mkdir -p site
tmp=$(mktemp)
echo "[" > "$tmp"

dirs=$(find site/history -mindepth 1 -maxdepth 1 -type d | sort -r)
total=$(echo "$dirs" | grep -c . || true)
i=0

for dir in $dirs; do
  i=$((i + 1))
  m=$(basename "$dir")
  has_global=false
  has_indonesia=false
  [ -f "$dir/global/certifications.csv" ] && has_global=true
  [ -f "$dir/indonesia/certifications.csv" ] && has_indonesia=true
  comma=","
  [ "$i" -eq "$total" ] && comma=""
  printf '  {"month": "%s", "global": %s, "indonesia": %s}%s\n' "$m" "$has_global" "$has_indonesia" "$comma" >> "$tmp"
done

echo "]" >> "$tmp"
mv "$tmp" site/months.json

# Roll every month's certifications.csv into one tidy long-format file per
# scope — one row per certification per month, "Scraped On" gives the date.
# This is the file to feed into Google Sheets / Looker Studio: import once,
# point a chart at it, and each future scheduled run appends a new date.
rollup() {
  scope="$1"
  out="site/history/${scope}_timeseries.csv"
  files=$(find site/history -mindepth 3 -maxdepth 3 -type f -path "*/$scope/certifications.csv" | sort)

  if [ -z "$files" ]; then
    return
  fi

  first=true
  tmp_out=$(mktemp)
  for f in $files; do
    if $first; then
      cp "$f" "$tmp_out"
      first=false
    else
      tail -n +2 "$f" >> "$tmp_out"
    fi
  done
  mv "$tmp_out" "$out"
}

rollup global
rollup indonesia
