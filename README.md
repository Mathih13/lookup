<img src="assets/logo-400.png" width="96" height="96" alt="">

# Lookup

A Spotlight-style search box for **WoW Forever**. Press your Lookup key, type a few letters, and press **Enter**. Use it to open a panel, cast a spell, run a command or change a setting without looking through menus.

## What it finds

| Type | Enter does |
|---|---|
| Panels and tabs (Character, Skills, Reputation, Spellbook, Legacy, Collections, ...) | Opens the panel on that tab |
| Settings | Turns an on/off setting on or off in place. Other settings open at their page |
| Minimap tracking (Flight Master, Mailbox, Repair, ...) | Turns that tracking on or off |
| Key bindings | Opens Key Bindings |
| Zones, cities, dungeons and raids | Opens the map there |
| Quests in your log | Opens the quest |
| Mounts, pets and toys | Opens Collections on it |
| Spells | Casts the spell. **Shift+Enter** opens the spellbook on its tab |
| Macros | Opens the macro window on it |
| Bag items | Opens your bags with the item highlighted |
| Currencies and reputations | Opens the right tab |
| Legacy Challenges | Opens the Legacy panel on that challenge |
| Slash commands, from Blizzard and from your addons (type `/` first) | Runs the command |
| Addon launchers (minimap buttons) | Opens the addon's window |
| Friends and guild members | Starts a whisper |

Lookup remembers what you pick, so your usual choices come first. An empty box shows your recent picks.

## Keys

- **Your Lookup key** opens and closes the box. On first login, Lookup suggests a free key, such as Ctrl+Space, and you can choose another. Change it later in Key Bindings under Lookup, or with `/lookup setup`. `/lookup` and the addon compartment button also open the box.
- **Up** and **Down** move the selection. **Enter** runs the selected row.
- **Shift+Enter** runs the row and keeps the box open. On rows with a second action, such as spells, it runs that action instead. The line at the bottom of the box shows what each key does.
- **Backspace** deletes a character. **Ctrl+Backspace** deletes a word. **Esc** closes the box.
- Drag a spell, item or macro row to your action bars.

## Commands

Type `/` to list only slash commands. Select one and press **Space** to add text after it. For example, `/auctionator` + Space + `post` runs `/auctionator post`. Lookup remembers the text you used, and shows it next time.

## Calculator

Type a sum such as `1250*3` or `(40+12)/4`. The first row shows the result, and Enter puts it in the box.

## Good to know

- The box closes when combat starts, and it does not open in combat. Blizzard does not let addons open panels or cast spells from a search box in combat.
- Lookup uses no data files of its own. It reads everything from the game when you open the box.
- `/lookup reset` makes Lookup forget your picks and command history.

## Development

The addon is in `Lookup/`. Product decisions are in [`docs/design.md`](docs/design.md).

Requires `lua-language-server` (`pacman -S lua-language-server`) and `lua5.1`.

```sh
make setup    # fetch WoW API annotations, Blizzard's Forever UI source and the packager into .tools/
make update   # refresh them after a game patch
make link     # symlink Lookup/ into WoW Forever's AddOns folder
make check    # type-check against the WoW API
make test     # run tests/*_test.lua in plain Lua
make log      # print the session log saved on the last /reload
make package  # build the release folder in .release/, as a release does
```

Edit a file, run `make check test`, then `/reload` in game. Restart the client after you change `Lookup.toc`. Set `WOW=...` if your `_forever_` folder is somewhere else.

The development log (`ns.log`, Lua errors and blocked actions, saved in `LookupLog`) runs only in a development copy. Release builds comment out the `--@debug@` block in `Debug.lua`.

### Releases

Push a tag such as `v0.1.0`. The GitHub workflow builds the zip with the [BigWigs packager](https://github.com/BigWigsMods/packager), then uploads it to CurseForge and GitHub Releases. A tag that contains `alpha` or `beta` uploads as an alpha or beta file. Write the notes in `CHANGELOG.md` first.

## Licence

MIT
