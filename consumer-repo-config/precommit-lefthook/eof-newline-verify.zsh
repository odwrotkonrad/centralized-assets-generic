#!/usr/bin/env zsh
##[>] 🤖🤖
set -uo pipefail

typeset -a offenders
for f in "$@"; do
  [[ -f $f && -s $f ]] || continue
  LC_ALL=C grep -Iq . "$f" || continue
  [[ $(tail -c1 "$f" | od -An -c | tr -d ' ') == '\n' ]] || offenders+=("$f")
done

(( ${#offenders} )) || exit 0
print -u2 -- "missing newline at end of file:"
print -u2 -l -- "  ${^offenders}"
exit 1
##[<] 🤖🤖
