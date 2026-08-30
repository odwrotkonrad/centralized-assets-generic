#!/usr/bin/env zsh
##[>] 🤖🤖
set -uo pipefail

root=$(git rev-parse --show-toplevel)
lockfile=$root/.repo/upstream.env
[[ -f $lockfile ]] || { print -u2 -- "upstream-env-drift: $lockfile missing"; exit 2 }

drifted=0
while IFS='=' read -r key value; do
  [[ -z $key || $key == \#* ]] && continue
  group_var=GRP_KO_VAR_$key
  applied=${(P)group_var:-}
  if [[ -z $applied ]] {
    print -- "upstream-env-drift: $key: no $group_var in this pipeline, skipped"
    continue
  }
  if [[ $applied != $value ]] {
    print -- "upstream-env-drift: $key: lockfile $value, group $applied"
    drifted=1
  }
done < $lockfile

if (( drifted )) {
  print -u2 -- 'upstream-env-drift: .repo/upstream.env lags the applied group variables: bump the lockfile, che renders the rest'
  exit 1
}
print -- 'upstream-env-drift: .repo/upstream.env matches the applied group variables'
##[<] 🤖🤖
