#!/usr/bin/env bash
# ai-agent plugin safety hook — PreToolUse, matcher: Write|Edit.
#
# Denies file writes whose content contains secret-shaped or PHI-shaped values,
# BEFORE they reach disk. This makes the hipaa skill's "never write secrets or
# real-looking PHI" rule mechanical instead of prompt-enforced.
#
# Scope is deliberately narrow and universal: real token shapes and dashed SSNs.
# Project-specific style rules do NOT belong here — this hook runs in every
# consuming repo, so it must never block legitimate project code.
#
# Exit codes: 0 = allow; 2 = deny (stderr becomes the blocking reason).
# The matched values are NEVER echoed back — only the pattern names.
# Fails OPEN without jq (defense-in-depth; prompt rules still apply).
#
# Known accepted limits: matching is line-based, so a secret split across a
# line boundary is not caught (not a natural failure mode — a split credential
# is usually non-functional anyway); and a standalone kebab-case identifier of
# 24+ chars starting with "sk-" is a rare fail-safe false positive.

set -u

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
content=$(printf '%s' "$payload" | jq -r '[.tool_input.content // empty, .tool_input.new_string // empty] | join("\n")' 2>/dev/null) || exit 0
[ -n "$content" ] || exit 0
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // "the target file"' 2>/dev/null)

names=(
  "github-token"
  "github-fine-grained-token"
  "atlassian-api-token"
  "slack-token"
  "sk-style-api-key"
  "aws-access-key-id"
  "private-key-block"
  "ssn-shaped-value"
)
patterns=(
  'ghp_[A-Za-z0-9]{20,}'
  'github_pat_[A-Za-z0-9_]{20,}'
  'ATATT[A-Za-z0-9_=-]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  '(^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{24,}'
  '(^|[^A-Z0-9])AKIA[0-9A-Z]{16}($|[^A-Z0-9])'
  '-----BEGIN [A-Z ]*PRIVATE KEY'
  '(^|[^0-9A-Za-z-])[0-9]{3}-[0-9]{2}-[0-9]{4}($|[^0-9A-Za-z-])'
)

hits=""
i=0
while [ $i -lt ${#patterns[@]} ]; do
  if printf '%s' "$content" | grep -qE -e "${patterns[$i]}"; then
    hits="$hits ${names[$i]}"
  fi
  i=$((i + 1))
done

if [ -n "$hits" ]; then
  echo "Blocked by the ai-agent plugin: the content being written to $file matches never-write patterns:$hits. Secrets and real-looking PHI must never be written to any file — use obviously-fake placeholders (per the hipaa skill: member-0001, TEST_LASTNAME; an all-zero dashed SSN is still blocked, use SSN-PLACEHOLDER) and retry. The matched values are intentionally not echoed here." >&2
  exit 2
fi

exit 0
