.PHONY: serve build scrub new publish install-hooks install-hugo clean help

help:           ## list targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

serve:          ## live preview (includes drafts)
	hugo server -D

build:          ## production build into ./public (no drafts)
	hugo --minify

scrub:          ## run the security gate over staged changes
	./scripts/scrub.sh

install-hooks:  ## activate the pre-commit scrub gate
	chmod +x scripts/scrub.sh scripts/git-hooks/pre-commit
	git config core.hooksPath scripts/git-hooks
	@echo "pre-commit scrub gate active."

new:            ## new draft:  make new NEW=my-post-slug
	hugo new content/posts/$(NEW).md

publish:        ## flip a draft live:  make publish POST=content/posts/foo.md
	@sed -i 's/^draft: true/draft: false/' $(POST)
	@echo "published $(POST) — review, then commit & push to deploy."

install-hugo:   ## install hugo (Debian/Ubuntu)
	sudo apt install -y hugo

clean:          ## remove build artifacts
	rm -rf public resources .hugo_build.lock
