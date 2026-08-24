#!/usr/bin/env bash
# ai-agent plugin workspace scaffolding — SessionStart (all sources).
#
# Ensures the plugin's two workspace directories exist in the consuming repo
# so developers never create them by hand:
#   docs/input-specs/   drop zone for everything the pipeline READS (SRS, MOMs,
#                       design links, module-wise user-story .xlsx files)
#   docs/output-specs/  home of everything the pipeline WRITES at project level
#                       (PROJECT_BRIEF.md, the module-wise gap-analysis report)
# Each directory gets a short README explaining what belongs in it (written
# only when absent — never overwritten).
#
# Plugins have no install-time lifecycle, so "created on install" is
# implemented as "created idempotently on session start". Guarded so a
# personally-installed plugin does not litter unrelated repos: it scaffolds
# only when the repo opts in via .claude/settings.json (enables this plugin)
# or already has a docs/ directory.
#
# This hook never blocks: every exit path is 0 and every failure is swallowed.
# On a no-op (directories already present, or the guard says no) it prints
# nothing; when it creates the directories it prints one line, which
# SessionStart surfaces as session context.

set -u

proj=${CLAUDE_PROJECT_DIR:-}
if [ -z "$proj" ] && command -v jq >/dev/null 2>&1; then
  proj=$(jq -r '.cwd // empty' 2>/dev/null)
fi
[ -n "$proj" ] && [ -d "$proj" ] || exit 0

# Context-pointer repos scaffold nothing locally: docs live in the context repo,
# which scaffolds itself when a session runs there. Grep-based on purpose (no jq
# dependency, mirrors the enablement grep below); a pointer file without a
# contextRoot key falls through to local scaffolding — the local-docs default.
ptr="$proj/.claude/ai-agent.json"
[ -f "$ptr" ] && grep -q '"contextRoot"' "$ptr" 2>/dev/null && exit 0

in_dir="$proj/docs/input-specs"
out_dir="$proj/docs/output-specs"
[ -d "$in_dir" ] && [ -d "$out_dir" ] && exit 0

# Consuming-repo guard: explicit plugin enablement, or an existing docs/ tree.
wanted=""
for settings in "$proj/.claude/settings.json" "$proj/.claude/settings.local.json"; do
  [ -f "$settings" ] && grep -q 'ai-agent@purandar-ai' "$settings" 2>/dev/null && wanted=1 && break
done
[ -z "$wanted" ] && [ -d "$proj/docs" ] && wanted=1
[ -n "$wanted" ] || exit 0

mkdir -p "$in_dir" "$out_dir" 2>/dev/null || exit 0

if [ ! -f "$in_dir/README.md" ]; then
  cat > "$in_dir/README.md" 2>/dev/null <<'EOF'
# docs/input-specs/ — project source documents (drop zone)

Everything the ai-agent pipeline reads about this project goes here:

- The SRS (software requirements specification)
- Meeting minutes (MOMs) — dated; the latest dated source wins on conflicts
- A design-links document (Figma links), or exported PNG/PDF design frames
- Interface / integration documents
- Module-wise user stories as `.xlsx` (one workbook, or one file per module) —
  compared against the generated brief by `/gap-analysis`

Run `/onboard-project` after adding or materially changing documents — reruns
detect what changed and update only the affected brief modules.
Files here are inputs only: the pipeline reads them and never edits them.
EOF
fi

if [ ! -f "$out_dir/README.md" ]; then
  cat > "$out_dir/README.md" 2>/dev/null <<'EOF'
# docs/output-specs/ — generated project knowledge

Project-level artifacts the ai-agent pipeline writes:

- `PROJECT_BRIEF.md` — the module-wise operational brief distilled from
  `docs/input-specs/` by `/onboard-project`
- `.brief-state.json` — the brief's change-detection manifest, written with
  every brief write; commit it with the brief
- `GAP_ANALYSIS.md` — the consolidated module-wise gap report (manual user
  stories vs the brief), written by each `/gap-analysis` run

The brief is overwritten only through a diff-and-approval gate; the gap
report is regenerated whole by contract on every run. Review and commit them
like code. Do not hand-edit: rerun the generating command instead; hand edits
are lost on the next regeneration. (Per-ticket outputs live in
`docs/tickets/<KEY>/`, not here.)
EOF
fi

echo "ai-agent plugin: scaffolded docs/input-specs/ (drop SRS, MOMs, design links, user-story .xlsx here) and docs/output-specs/ (generated brief + gap report)."

exit 0
