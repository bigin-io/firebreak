#!/usr/bin/env bash
# Resolve the change set Firebreak reviews. Never scans a whole repository.
#
#   ./scope.sh              working tree (staged + unstaged) — pre-commit mode
#   ./scope.sh <ref>        <ref> vs its merge-base with the default branch — review mode
#   ./scope.sh --ci [<ref>] same as review, machine-readable, exits 2 on an empty set
set -uo pipefail

CI=0
[[ "${1:-}" == "--ci" ]] && { CI=1; shift; }
REF="${1:-}"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "firebreak: not a git repository" >&2; exit 2; }

default_branch() {
  git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' && return
  for b in main master; do git show-ref --verify --quiet "refs/heads/$b" && { echo "$b"; return; }; done
  echo main
}

if [[ -z "$REF" ]]; then
  MODE=working-tree; BASE=HEAD
  FILES=$(git diff --name-only --diff-filter=d HEAD; git ls-files --others --exclude-standard)
  DIFF=$(git diff HEAD)
else
  MODE=review
  DB=$(default_branch)
  BASE=$(git merge-base "$DB" "$REF" 2>/dev/null) || { echo "firebreak: cannot resolve merge-base of $DB and $REF" >&2; exit 2; }
  FILES=$(git diff --name-only --diff-filter=d "$BASE..$REF")
  DIFF=$(git diff "$BASE..$REF")
fi

FILES=$(printf '%s\n' "$FILES" | sed '/^$/d' | sort -u)
COUNT=$(printf '%s\n' "$FILES" | sed '/^$/d' | wc -l | tr -d ' ')

if [[ "$COUNT" -eq 0 ]]; then
  echo "firebreak: change set is empty — nothing to review" >&2
  [[ "$CI" -eq 1 ]] && exit 2 || exit 0
fi

OUT=$(mktemp -d)/firebreak-changeset.diff
printf '%s' "$DIFF" > "$OUT"

echo "mode=$MODE"
echo "base=$BASE"
echo "ref=${REF:-WORKING_TREE}"
echo "files_changed=$COUNT"
echo "diff_file=$OUT"
echo "--- changed files ---"
printf '%s\n' "$FILES"
