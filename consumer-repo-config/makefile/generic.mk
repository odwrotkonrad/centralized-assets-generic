##[>] 🤖🤖
GENERIC_CHE ?= $${CHE_BIN:-che}
GENERIC_FILES_TRACKED_PROFILES ?= generic/filesTracked
GENERIC_FILES_UNTRACKED_PROFILES ?= generic/filesUntracked
GENERIC_ENV_PROFILES ?= generic/env
GENERIC_DEPS_PROFILES ?= generic/deps
GENERIC_SETUP_PROFILES ?= genericSetup

.PHONY: generic-files-tracked-generate generic-files-untracked-generate generic-files-tracked-verify \
  generic-env-generate generic-env-update-dependencies generic-env-update-from-shell generic-env-update-all \
  generic-precommit-install generic-precommit-changed generic-precommit-all \
  generic-deps-install generic-semver-next generic-tag-mint generic-dev-env-prepare

##[>] Generic: Files [genai-include]
#[what] render every git-tracked generated file (README, LICENSE, repo-specific tracked renders); the untracked set first, the tracked templates read it
generic-files-tracked-generate: generic-files-untracked-generate
	@$(GENERIC_CHE) run --profiles=$(GENERIC_FILES_TRACKED_PROFILES)

#[what] render every gitignored generated file (agent docs, repo data)
generic-files-untracked-generate:
	@$(GENERIC_CHE) run --profiles=$(GENERIC_FILES_UNTRACKED_PROFILES)

#[what] regenerate the tracked files, fail on drift, restore the tree either way
generic-files-tracked-verify: generic-files-untracked-generate
	@GENERIC_CHE="$(GENERIC_CHE)" GENERIC_FILES_TRACKED_PROFILES="$(GENERIC_FILES_TRACKED_PROFILES)" shared/generic/ci/verify-tracked.zsh
##[<] Generic: Files

##[>] Generic: Env [genai-include]
#[what] render .che/tpl/repo-git-tracked/env.tpl to .env: missing keys only, existing values kept
generic-env-generate:
	@CHE_ENV_UNSET=empty $(GENERIC_CHE) render-templates --profiles=$(GENERIC_ENV_PROFILES) --merge-update=none

#[what] as generate, plus every upstream pin (.repo/upstream.env) overwritten
generic-env-update-dependencies:
	@CHE_ENV_UNSET=empty $(GENERIC_CHE) render-templates --profiles=$(GENERIC_ENV_PROFILES) --merge-update=dependencies

#[what] as generate, plus every shell-valued key re-run (glab, op)
generic-env-update-from-shell:
	@CHE_ENV_UNSET=empty $(GENERIC_CHE) render-templates --profiles=$(GENERIC_ENV_PROFILES) --merge-update=shell

#[what] every template key overwritten, keys the template does not name kept
generic-env-update-all:
	@CHE_ENV_UNSET=empty $(GENERIC_CHE) render-templates --profiles=$(GENERIC_ENV_PROFILES) --merge-update=all
##[<] Generic: Env

##[>] Generic: Precommit [genai-include]
#[what] install the lefthook git hooks
generic-precommit-install:
	@lefthook install --force

#[what] run the pre-push checks over the files this branch changed against origin/main
generic-precommit-changed:
	@git diff --name-only origin/main...HEAD | lefthook run pre-push --files-from-stdin

#[what] run the pre-push checks over every file
generic-precommit-all:
	@lefthook run pre-push --all-files --force
##[<] Generic: Precommit

##[>] Generic: Deps [genai-include]
#[what] install the toolchain the generic targets need: make, lefthook, yq, glab (never che)
generic-deps-install:
	@$(GENERIC_CHE) run --profiles=$(GENERIC_DEPS_PROFILES)
##[<] Generic: Deps

##[>] Generic: Release [genai-include]
#[what] print the next semver tag inferred from the last tag..HEAD diff (override: `semver: major|minor|patch` commit token)
generic-semver-next:
	@shared/generic/ci/semver-bump.zsh

#[what] mint and push the next semver tag (CI: authed via TAG_TOKEN)
generic-tag-mint:
	@shared/generic/ci/tag-mint.zsh
##[<] Generic: Release

##[>] Generic: Dev Environment [genai-include]
#[what] make a fresh clone a working checkout: .env, generated files, toolchain, git hooks
generic-dev-env-prepare: generic-env-generate generic-files-tracked-generate generic-deps-install generic-precommit-install
##[<] Generic: Dev Environment
##[<] 🤖🤖
