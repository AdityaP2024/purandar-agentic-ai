#!/usr/bin/env bash
# ai-agent plugin safety hook — PreToolUse, matcher: Bash.
#
# Enforces the plugin contract "the developer commits; the plugin never does":
# denies git write operations (commit, push, tag creation/modification/deletion)
# and gh pr create/merge BEFORE they run. Read-only git (status, diff, log,
# grep, tag -l) always passes.
#
# Design: the command string is split into simple-command segments (every shell
# metacharacter, quote, and backslash is a separator — so `sh -c 'git push'`,
# `$(git push)`, and `git push;echo` all surface the inner command as its own
# segment), then each segment is tokenized and the subcommand is read from its
# actual position after git's global flags. This avoids both bypass-by-quoting
# and false denies on read-only commands like `git grep push` or `git log push`.
#
# Known accepted limits: runtime string indirection (eval of a variable,
# base64) cannot be caught statically — the agents' prompt-level hard rules
# remain the primary control; this hook is defense-in-depth for the ordinary
# path. Exit 0 = allow; exit 2 = deny (stderr becomes the blocking reason).
# Fails OPEN without jq.

set -u
set -f  # no globbing while tokenizing segments

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

MSG_WRITE="Blocked by the ai-agent plugin: this command contains a git write operation (commit/push). The plugin contract is that the DEVELOPER commits and pushes — agents only write code and artifacts. Ask the developer to commit, or remove the git write from the command."
MSG_TAG="Blocked by the ai-agent plugin: this command creates, modifies, or deletes a git tag. Tags are release actions the DEVELOPER performs. Listing tags (git tag, git tag -l) is allowed."
MSG_PR="Blocked by the ai-agent plugin: creating or merging a pull request is the DEVELOPER's action. Agents prepare the code and artifacts; the developer opens the PR."

deny() { printf '%s\n' "$1" >&2; exit 2; }

# Every shell metacharacter, quote, and backslash becomes a segment separator.
seps=';&|()<>`$"\'\'''
segments=$(printf '%s' "$cmd" | tr "$seps" '\n')

while IFS= read -r seg; do
  [ -n "${seg// /}" ] || continue
  # shellcheck disable=SC2086
  set -- $seg

  # Skip leading env assignments (VAR=value) and wrapper commands + their flags.
  while [ $# -gt 0 ]; do
    case "$1" in
      [A-Za-z_]*=*) shift ;;
      command|builtin|exec|nohup|time|sudo|env|xargs)
        shift
        while [ $# -gt 0 ] && case "$1" in -*) true ;; *) false ;; esac; do shift; done ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || continue

  prog=${1##*/}  # basename: catches /usr/bin/git too

  if [ "$prog" = "gh" ]; then
    if [ $# -ge 3 ] && [ "$2" = "pr" ]; then
      case "$3" in create|merge) deny "$MSG_PR" ;; esac
    fi
    continue
  fi

  [ "$prog" = "git" ] || continue
  shift

  # Skip git's global flags to find the real subcommand.
  # These take a separate argument:
  while [ $# -gt 0 ]; do
    case "$1" in
      -C|-c|--git-dir|--work-tree|--namespace) shift 2 || break ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || continue

  sub=$1
  shift
  case "$sub" in
    commit|push) deny "$MSG_WRITE" ;;
    tag)
      [ $# -gt 0 ] || continue  # bare `git tag` lists — read-only
      case "$1" in
        -l|--list|-n*|--contains|--no-contains|--points-at|--merged|--no-merged|--sort=*|--format=*|--column*)
          continue ;;  # read-only listing forms
        *) deny "$MSG_TAG" ;;
      esac ;;
  esac
done <<EOF
$segments
EOF

exit 0
