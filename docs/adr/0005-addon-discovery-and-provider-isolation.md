# Addon discovery and provider isolation

The surfaces, attribution and limits are in `docs/design.md` "Other addons". The code-level details that used to be comments:

## Discovery (`Discovery.lua`)

- `ns.addonOf` uses `issecurevariable`. A secure value is Blizzard's. Values that Lookup set also count as Blizzard's, so Lookup shows no addon row for itself.
- Chat moves registered commands into a hidden table on first use and empties `SlashCmdList` (`ChatFrameUtil` `ImportListToHash`). `ns.discover.slash` reads both tables. The `SLASH_*1` global keeps the addon's taint, so attribution reads that global.
- Some `SLASH_*n` aliases repeat the first spelling (`SLASH_CALENDAR2 = "/calendar"`). Aliases are compared without case and kept once.
- A launcher's owner is the addon with the launcher's name, else the addon that set `OnClick`.
- Launcher menus anchor to the frame they get, and the box is closed by then. `anchorFor` in `Sources.lua` passes the addon's LibDBIcon minimap button, so menus open where they normally do. A hidden minimap button would put the menu off screen, so a hidden one falls back to a 1x1 frame where the box was.

## Providers (`Providers.lua`)

- An entry without a readable name (not a string, or a secret value) is skipped quietly and is not a failure: such rows happen in normal data.
- A build over `SLOW_MS` (5 ms) is logged, not punished: the settings walk can take this long.
- Every provider rebuilds on each open.
