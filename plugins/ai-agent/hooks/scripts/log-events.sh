#!/usr/bin/env bash
# ai-agent plugin observability hook — PostToolUse, matcher: Skill|Task|Agent|Read|Write|Edit.
#
# Ground-truth data source for /agent-audit: appends one metadata-only JSONL
# line per interesting event to .claude/ai-agent-metrics/events.jsonl in the
# consuming repo — skill invocations, agent spawns, reads of standards and
# knowledge files, writes to pipeline artifacts. The audit command
# cross-references this log with the produced artifacts per ticket ("were the
# right skills read by the right agents; did each stage produce its output").
#
# HARD RULE: never log file content, command strings, prompts, or tool
# responses. Tool names, skill names, agent types, and file PATHS only —
# nothing secret-shaped or PHI-shaped can land in this log by construction.
#
# This hook never blocks: every exit path is 0 and every failure is swallowed.
# Fails silent without jq (consistent with the safety hooks). The metrics
# directory ignores itself via a generated .gitignore — the event log is
# per-developer local data; the durable committed outputs are the /agent-audit
# scorecards, not this file. The log rotates once past ~5MB (.old is
# overwritten) so it can never grow unbounded.

set -u

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)

field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }

tool=$(field '.tool_name')
[ -n "$tool" ] || exit 0

event=""
target=""
case "$tool" in
  Skill)
    event="skill"
    target=$(field '.tool_input.skill')
    ;;
  Task|Agent)
    event="agent"
    target=$(field '.tool_input.subagent_type')
    ;;
  Read)
    target=$(field '.tool_input.file_path')
    if printf '%s' "$target" | grep -qE '(SKILL\.md$|MEMORY\.md$|CLAUDE\.md$|PROJECT_BRIEF\.md$|decisions\.md$|docs/input-specs/|docs/output-specs/|docs/tickets/|templates/)'; then
      event="read"
    fi
    ;;
  Write|Edit)
    target=$(field '.tool_input.file_path')
    if printf '%s' "$target" | grep -qE '(docs/|PROJECT_BRIEF\.md$|decisions\.md$)'; then
      event="artifact_write"
    fi
    ;;
esac
{ [ -n "$event" ] && [ -n "$target" ]; } || exit 0

proj=${CLAUDE_PROJECT_DIR:-$(field '.cwd')}
[ -n "$proj" ] || exit 0
dir="$proj/.claude/ai-agent-metrics"
mkdir -p "$dir" 2>/dev/null || exit 0
[ -f "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null

log="$dir/events.jsonl"
if [ -f "$log" ]; then
  size=$(wc -c < "$log" 2>/dev/null) || size=0
  if [ "${size:-0}" -gt 5242880 ] 2>/dev/null; then
    mv -f "$log" "$log.old" 2>/dev/null
  fi
fi

# Machine-agnostic where possible: store the path relative to the project.
target=${target#"$proj"/}

jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg sid "$(field '.session_id')" \
  --arg event "$event" \
  --arg tool "$tool" \
  --arg target "$target" \
  '{ts: $ts, session: $sid, event: $event, tool: $tool, target: $target}' \
  >> "$log" 2>/dev/null

exit 0
