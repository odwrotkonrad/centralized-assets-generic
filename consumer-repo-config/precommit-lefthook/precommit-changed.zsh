#!/usr/bin/env zsh
##[>] 🤖🤖
set -uo pipefail
base=origin/$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')
git rev-parse --verify -q $base >/dev/null || base=FETCH_HEAD
git diff --name-only -z --diff-filter=d $base...HEAD | lefthook run pre-push --files-from-stdin
##[<] 🤖🤖
