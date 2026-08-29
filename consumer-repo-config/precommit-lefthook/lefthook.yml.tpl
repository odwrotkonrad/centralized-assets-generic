##[>] 🤖🤖
extends:
  - ~/.config/lefthook/lefthook.yml
{{- if eq .var.lefthookLocal "true" }}
  - .che/lefthook.local.yml
{{- end }}

pre-push:
  parallel: false
  jobs:
    - name: generic-files-tracked-verify
      run: make generic-files-tracked-verify
{{- if eq .var.lefthookGitlabCiVerify "true" }}
    - name: generic-gitlab-ci-verify
      glob: ".gitlab-ci.yml"
      run: '[ -n "${CI:-}" ] || glab ci lint'
{{- end }}
{{- if eq .var.lefthookYmlVerify "true" }}
    - name: generic-yml-verify
      glob: "*.{yml,yaml}"
      run: yq -e '.' {push_files} >/dev/null
{{- end }}
##[<] 🤖🤖
