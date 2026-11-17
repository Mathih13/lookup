# Lookup

WoW addon for **WoW Forever** (`_forever_`, Interface `16001`). Forever runs the Midnight retail client, so it uses the mainline 12.x API and the Midnight addon limits. Classic-only APIs are absent. Combat and unit data can be **secret values**: test with `issecretvalue(v)` before you compare, do maths on or store a value.

## Loop

1. Edit files in `Lookup/`. A Claude Code hook runs `make check test` after every Edit or Write on a `.lua` file and reports failures. After edits through the shell, run `make check test` yourself.
2. Ask the user to `/reload`. When you add a file to `Lookup.toc` or change its `##` fields, ask for a client restart.
3. Run `make log` to read what happened in game. It prints `LookupLog` from SavedVariables: the latest session's `ns.log(...)` lines and every Lua error (`ERROR` + stack), from any addon.

Done means: `make check test` passes, and `make log` after a reload shows the expected lines and no `ERROR` from Lookup.

## Evidence

- Add `ns.log(...)` calls to get runtime evidence. Ask the user to describe the screen only for visual layout.
- API signatures: `.tools/vscode-wow-api/Annotations/Core`.
- Real usage: `.tools/wow-ui-source`, Blizzard's UI code for Forever. Search it for how Blizzard calls an API or uses a template before you write new UI code. Its `version.txt` must match the `Version` in the game's `.build.info`; if not, run `make update`.
- `tests/*_test.lua` run in plain `lua5.1` with stubbed WoW globals. Use them for pure logic.
