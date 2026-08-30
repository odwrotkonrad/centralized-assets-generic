#!/usr/bin/env zsh
##[>] 🤖🤖
set -uo pipefail

che=${BIN_CHE:-che}
profiles=${GENERIC_FILES_TRACKED_PROFILES:-generic/filesTracked}
root=$(git rev-parse --show-toplevel)
cd $root

if [[ -n $(git status --porcelain --untracked-files=no) ]] {
  print -u2 -- 'verify-tracked: the working tree has uncommitted changes, commit or discard them first'
  exit 2
}

$che run --profiles=$profiles
render_status=$?

git diff --stat
git diff --quiet
drift_status=$?

git checkout -q -- .
git clean -qfd -- $(git ls-files --others --exclude-standard)

if (( render_status != 0 )) {
  print -u2 -- "verify-tracked: render failed ($render_status)"
  exit $render_status
}
if (( drift_status != 0 )) {
  print -u2 -- 'verify-tracked: tracked generated files drifted, run `make generic-files-tracked-generate` and commit'
  exit 1
}
print -- 'verify-tracked: tracked generated files are current'
##[<] 🤖🤖
