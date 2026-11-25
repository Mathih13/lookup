WOW ?= $(HOME)/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_
ADDONS = $(WOW)/Interface/AddOns

.PHONY: setup update link check comments comments-baseline test log package

LUA_FILES = $(sort $(wildcard Lookup/*.lua tests/*.lua scripts/*.lua))

# Fetch WoW API annotations and Blizzard's UI source for WoW Forever.
setup:
	test -d .tools/vscode-wow-api || git clone --depth 1 https://github.com/Ketho/vscode-wow-api .tools/vscode-wow-api
	test -d .tools/wow-ui-source || git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source .tools/wow-ui-source
	test -d .tools/packager || git clone --depth 1 https://github.com/BigWigsMods/packager .tools/packager

# Run after a game patch.
update:
	git -C .tools/vscode-wow-api pull --ff-only
	git -C .tools/wow-ui-source pull --ff-only
	git -C .tools/packager pull --ff-only

# Symlink the addon into the game. Edit, then /reload in game.
link:
	ln -sfn "$(CURDIR)/Lookup" "$(ADDONS)/Lookup"

check: comments
	lua-language-server --check=. --configpath="$(CURDIR)/.luarc.json" --checklevel=Warning --check_format=pretty

# No comments in code (docs/adr/0001-no-code-comments.md). The baseline in .comments-baseline only goes down.
comments:
	lua5.1 scripts/comments.lua check $(LUA_FILES)

# Lock in deleted comments. It refuses to raise a count.
comments-baseline:
	lua5.1 scripts/comments.lua lower $(LUA_FILES)

test:
	for t in tests/*_test.lua; do lua5.1 "$$t" || exit 1; done

# Print the session log the addon saved on the last /reload or logout.
log:
	cat "$(WOW)"/WTF/Account/*/SavedVariables/Lookup.lua

# Build the release folder into .release/ as the GitHub workflow does, without the zip or the upload.
# Debug blocks are stripped, as in a release.
package:
	bash .tools/packager/release.sh -d -z -r "$(CURDIR)/.release"
