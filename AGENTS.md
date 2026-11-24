# Lookup

WoW addon for **WoW Forever** (`_forever_`, Interface `16001`). Forever runs the Midnight retail client, so it uses the mainline 12.x API and the Midnight addon limits. Classic-only APIs are absent. Product decisions live in `docs/design.md`: read it before you change behaviour or add a category, and update it when a decision changes. Combat and unit data can be **secret values**: test with `issecretvalue(v)` before you compare, do maths on or store a value.

## Loop

1. Edit files in `Lookup/`. A Claude Code hook runs `make check test` in the background after every Edit or Write on a `.lua` file and wakes you on failure (about 10 s). Before asking for a reload, run `make check test` yourself.
2. Ask the user to `/reload`. When you add a file to `Lookup.toc` or change its `##` fields, ask for a client restart.
3. Run `make log` to read what happened in game. It prints `LookupLog` from SavedVariables: `ns.log(...)` lines from this session and the end of earlier ones (`--- new session` separates them) and every Lua error (`ERROR` + stack), from any addon.

Done means: `make check test` passes, and `make log` after a reload shows the expected lines and no `ERROR` from Lookup.

## Evidence

- Add `ns.log(...)` calls to get runtime evidence. Ask the user to describe the screen only for visual layout.
- API signatures: `.tools/vscode-wow-api/Annotations/Core`. The checker also reads Blizzard's Forever Lua source, but not its XML: add XML-defined frames (for example `CharacterFrame`) to `diagnostics.globals` in `.luarc.json`.
- Real usage: `.tools/wow-ui-source`, Blizzard's UI code for Forever. Search it for how Blizzard calls an API or uses a template before you write new UI code. Its `version.txt` must match the `Version` in the game's `.build.info`; if not, run `make update`.
- `tests/*_test.lua` run in plain `lua5.1` with stubbed WoW globals. Use them for pure logic.

## Release

A `v*` tag runs `.github/workflows/release.yml`, which builds with the BigWigs packager (`.pkgmeta`) and uploads to CurseForge. Packaged builds comment out `--@debug@` blocks: put code that only serves development (the log, error capture) inside one, and keep a no-op fallback outside it. `make package` builds the same folder locally in `.release/`. Write the release notes in `CHANGELOG.md`.
