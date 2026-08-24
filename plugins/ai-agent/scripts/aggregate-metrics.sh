#!/usr/bin/env bash
# ai-agent plugin — cross-repo metrics aggregation (Phase 3 of the observability
# initiative; Phase 1 is the event-logging hook, Phase 2 the /agent-audit command).
#
# Lead-facing trend report: merges the docs/agent-metrics.md tables that
# /agent-audit appends in each consuming repo into one team-wide markdown
# report on stdout — per-repo summary with totals, then every audit row,
# newest first, with a Repo column added.
#
# Usage:  aggregate-metrics.sh <repo-path> [<repo-path> ...]
#         aggregate-metrics.sh ~/work/repos/*/
# In the shared-context topology, point it at the project-context repo(s) —
# that is where docs/agent-metrics.md lives for all code repos sharing it.
#
# Read-only in the strongest sense: reads exactly one file per repo
# (docs/agent-metrics.md), writes nothing anywhere, never runs git. Repos
# without a metrics file are listed as "no data" rather than skipped silently;
# malformed table rows are counted and reported, never silently dropped.
# Plain bash + awk — no jq, no network.

set -u

if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <repo-path> [<repo-path> ...]" >&2
  echo "Merges each repo's docs/agent-metrics.md (written by /agent-audit) into one report on stdout." >&2
  exit 1
fi

rows=""        # collected data rows: repo|date|ticket|mode|pass|warn|fail|nodata|denials|notes
nodata_repos=""
bad_paths=""
malformed_total=0
scanned=0

for repo in "$@"; do
  repo=${repo%/}
  if [ ! -d "$repo" ]; then
    bad_paths="$bad_paths$repo"$'\n'
    continue
  fi
  scanned=$((scanned + 1))
  name=$(basename "$repo")
  file="$repo/docs/agent-metrics.md"
  if [ ! -f "$file" ]; then
    nodata_repos="$nodata_repos$name"$'\n'
    continue
  fi

  # Data rows are 9-column markdown table lines; skip the header row and the
  # |---| separator. A |-line with the wrong column count is malformed.
  # ROW|/BAD| prefixes carry both streams through one substitution — no temp
  # files, keeping the script's writes-nothing contract literal.
  extracted=$(awk -F'|' -v repo="$name" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^\|/ {
      d = trim($2)
      if (d == "Date" || d ~ /^-+$/) next
      if (NF != 11) { bad++; next }
      out = "ROW|" repo
      for (i = 2; i <= 10; i++) out = out "|" trim($i)
      print out
    }
    END { print "BAD|" bad + 0 }
  ' "$file")
  bad=$(printf '%s\n' "$extracted" | grep '^BAD|' | cut -d'|' -f2)
  data=$(printf '%s\n' "$extracted" | grep '^ROW|' | cut -d'|' -f2-)
  malformed_total=$((malformed_total + ${bad:-0}))

  if [ -n "$data" ]; then
    rows="$rows$data"$'\n'
  else
    nodata_repos="$nodata_repos$name"$'\n'
  fi
done

echo "# Team Agent Pipeline Metrics"
echo
echo "- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "- Repos scanned: $scanned"
[ -n "$bad_paths" ] && printf -- "- Not a directory (skipped): %s\n" "$(printf '%s' "$bad_paths" | tr '\n' ' ')"
[ "$malformed_total" -gt 0 ] && echo "- Malformed rows skipped: $malformed_total (fix or regenerate the affected docs/agent-metrics.md)"
echo

echo "## Per-repo summary"
echo
echo "| Repo | Audits | PASS | WARN | FAIL | NO-DATA | Denials |"
echo "|---|---|---|---|---|---|---|"
if [ -n "$nodata_repos" ]; then
  printf '%s' "$nodata_repos" | awk 'NF { printf "| %s | no data | — | — | — | — | — |\n", $0 }'
fi
if [ -n "$rows" ]; then
  printf '%s' "$rows" | awk -F'|' '
    NF < 10 { next }
    {
      audits[$1]++
      pass[$1] += $5 + 0; warn[$1] += $6 + 0; fail[$1] += $7 + 0
      nod[$1] += $8 + 0; den[$1] += $9 + 0
      ta++; tp += $5 + 0; tw += $6 + 0; tf += $7 + 0; tn += $8 + 0; td += $9 + 0
    }
    END {
      for (r in audits)
        printf "| %s | %d | %d | %d | %d | %d | %d |\n", r, audits[r], pass[r], warn[r], fail[r], nod[r], den[r] | "sort"
      close("sort")
      printf "| **TOTAL** | %d | %d | %d | %d | %d | %d |\n", ta+0, tp+0, tw+0, tf+0, tn+0, td+0
    }'
fi
echo

echo "## All audits (newest first)"
echo
echo "| Date | Repo | Ticket | Mode | PASS | WARN | FAIL | NO-DATA | Denials | Notes |"
echo "|---|---|---|---|---|---|---|---|---|---|"
if [ -n "$rows" ]; then
  printf '%s' "$rows" | awk -F'|' 'NF >= 10 {
    printf "%s\t| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n",
      $2, $2, $1, $3, $4, $5, $6, $7, $8, $9, $10
  }' | sort -r | cut -f2-
fi

exit 0
