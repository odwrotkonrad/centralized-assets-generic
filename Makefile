##[>] 🤖🤖
SHELL := zsh
.SHELLFLAGS := -c

COMMANDS := che-install generic-setup test

.PHONY: $(COMMANDS)

-include shared/generic/make/generic.mk

##[>] Setup [genai-include]
#[what] install the latest released che into ~/.local/bin, only when the one on PATH is older
che-install:
	@curl -fsSL https://konradodwrot.gitlab.io/go-modules/che-install.sh | sh -s -- --skip-if-present-is-newer

#[what] render this repo's own consumer payload (generic.mk, lefthook.yml, shared/generic/) from its source tree
generic-setup:
	@$${CHE_BIN:-che} render-templates --profiles=genericSetup

shared/generic/make/generic.mk: generic-setup
##[<] Setup

##[>] Test [genai-include]
#[what] run the minitest suites: lib/ profile-coverage rules, the shared Ruby, the GitLab template shapes
test:
	@for suite in test/*_test.rb; do ruby -Ilib "$$suite" || exit 1; done
##[<] Test
##[<] 🤖🤖
