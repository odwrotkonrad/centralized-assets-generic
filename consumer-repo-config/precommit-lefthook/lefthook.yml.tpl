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
    - name: generic-verify
      group:
        parallel: true
        jobs:
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
{{- if eq .var.lefthookEofNewlineVerify "true" }}
          - name: generic-eof-newline-verify
            run: shared/generic/ci/eof-newline-verify.zsh {push_files}
{{- end }}
##[<] 🤖🤖
