# Lookup design

Agreed with the user on 2026-11-17. Change this file when a decision changes.

## Terms

Use these words the same way in the code, this file and conversation.

- **Entry**: one result row's data: name, category, context, icon, value, one action.
- **Action**: what Enter does, from a closed set of kinds: `binding` (a binding command, with an optional `button` for the mouse and `tab`), `line` (one macro line), `call` (plain code), `toggle` (`get` and `set`). `after` is a plain step after a `binding` or a `line`. `alt` is a second action for Shift-Enter and a right click.
- **Action plan**: how an action runs: an override binding, a LookupRun click, or plain code (`Action.lua`).
- **Provider**: something that builds entries of one rank: a built-in source, an addon discovery surface, or later an outside addon.
- **Discovery record**: what an addon discovery surface finds (a slash command, a binding, a LibDataBroker launcher), with the addon that owns it.
- **Query session**: the typed text, the token, the selection and the mode, and what the box shows for them.
- **Command mode**: a query that starts with `/`. **Token**: the command picked with Space, whose argument is being typed.
- **Pick memory**: what the box remembers of your picks: entries, and arguments per command.

## Product

A Spotlight-style search box for **WoW Forever only** (Interface `16001`). Use Forever's (Camelot) Blizzard UI paths; ignore retail-only systems. Personal tool first, but publishable: display text comes from the game's localized strings. Licence MIT.

v1 was **navigation only**. Since v1, spells cast on Enter (out of combat, like every row), and the spellbook opens on Shift-Enter.

## Identity

Compete with EasyFind on:

1. **Light**: no static databases, lazy index from Blizzard APIs, near-zero work at login.
2. **No errors**: no taint, no secret-value errors, tested in combat.
3. **Patch-proof**: panels and settings come from Blizzard data, not hand-written tab indexes.
4. **Searches more**: quests in the log, friends, guild members.
5. **Spotlight feel**: recent picks in the empty box, few options.

Never copy EasyFind code (all rights reserved).

## Opening and keys

- Binding `LOOKUP_TOGGLE`, with no fixed default key: the game binds Shift+Space by default. `/lookup` opens the box; `/lookup reset` clears history; `/lookup setup` shows the welcome window again. Addon compartment entry.
- **First-time setup** (`Setup.lua`): at the first login with no Lookup key, after 3 s and out of combat, a welcome window offers a key. It suggests the first free one of Ctrl+Space, Ctrl+F, Shift+F (`GetBindingAction`), or Ctrl+Space if all are taken, and then names what it replaces. A click on the key captures a new one, as Key Bindings does. "Use this key" binds it, saves, and opens the box. Skip, Esc or the close button: the window does not come back on its own. A player who already has a Lookup key never sees it.
- The box auto-focuses. Up/Down select, Enter runs and closes, Shift+Enter runs and keeps it open, Esc or the binding closes. On a row with an `alt` action (spells), Shift+Enter and a right click run the alt and close. Mouse works.
- A toggle prints one chat line, for example `Damage Meter: Off`.

## Look

Decided 2026-11-18 after five mock review rounds (v6 mock). The box looks like part of the WoW UI:

- **Frame**: the Midnight dropdown menu background `common-dropdown-bg` (SetAtlas only: the atlas has its own 9-slice data, and explicit slice margins stretch its corners; drawn twice so the scene does not show through, placed as `MenuStyle1Mixin` does), 540 wide, at the top of the screen. All text is in the default UI font (Friz Quadrata), 12 or larger, with a drop shadow. Key names are plain words (`Enter`, `Shift-Enter`): the WoW fonts have no key glyphs.
- **Stock art only** (chosen 2026-11-18 over five more review rounds with real game art, mock v12): search field `common-search-border-left/middle/right` dimmed to 0.8; selected row `friends-card-quickJoin-selected` (the Quick Join card outline, made for 38px rows), additive; icons in `search-iconframe-large` (achievement search); quests `QuestTurnin` when ready to turn in, `Quest-In-Progress-Icon-yellow` while in progress; divider `UI-TooltipDivider-Transparent` (menu divider); checkbox `checkbox-minimal`. Plain colour only for the caret and the dark icon slot.
- **Search field**: magnifying glass over the icon column, typed text over the name column, a caret. "8 of 9" at the right when matches do not fit.
- **Rows**: at most 8, one ranked list, no group headers. A row has an icon in a framed slot, the name (line 1), the category and context (line 2, for example `Spell · Holy`, `Quest · Lvl 22 · Ashenvale`), and one value at the right (rank, objectives `1/3`, standing, count, key, or a checkbox for an on/off setting). Spells show only their highest rank.
- **Colour**: gold marks the typed letters in the name, and nothing else. Other colours only where WoW uses them: quest difficulty, faction standing, class, `Complete`.
- **Status line**: at the bottom, what Enter does for the selected row (`Enter: Open spellbook`), and what a drag puts on the bars or `Shift-Enter: keep open` for settings.
- **Empty box**: the 5 most recent picks under a grey `Recent` label. Until there are 3 picks in history, example searches under `Try` instead (map, mount, auto loot, `/`, a sum). Picking one types its text into the box.

## Calculator

A query that is only arithmetic (`1+10`, `(3.5 + 2) * 4`, `2^8`, `10 % 3`, `3x4`) shows the result as the first row. Enter puts the result in the box, so calculations chain. Addons cannot write to the clipboard. The parser is in `Match.lua`; it never runs the text as Lua.

## Matching and ranking

- Word-prefix match first, then initials (`bfd`), then fuzzy subsequence ranked lower.
- Ignore apostrophes and accents.
- A short English alias list (`rep`, `dmg`, `lfg`, ...) adds to real names.
- History boosts frequent and recent picks. One history for all characters; skip entries that do not exist on the current character.
- Equal matches rank by the category order below.

## Categories

A thing with several actions gets separate rows, for example `Ashenvale` (Zone) and `Quests in Ashenvale` (Quests, value 3).

| Rank | Category | Enter does |
|---|---|---|
| 1 | UI panels and tabs | Open the panel or tab |
| 2 | Settings and key bindings | On/off: toggle in place and show state. Other: open Settings at it. Bindings: open Key Bindings. Skip protected settings |
| 3 | Zones, cities, dungeons, raids | Open the map on it |
| 4 | Quests in the log | `Quests in <zone>` (only when there are some) opens map with quest log. Title match opens the quest details. No waypoints or tracking |
| 5 | Mounts, pets, toys | Open Collections on it |
| 6 | Spells | Cast (`/cast <name>`, the highest rank). Shift-Enter: open the spellbook on the school tab. Passives open the spellbook |
| 7 | Macros | Open the macro window on it |
| 8 | Bag items | Open bags with the item highlighted |
| 9 | Currencies, reputations, achievements | Open the right tab. Achievements are Forever's Legacy Challenges |
| 10 | Slash commands | Run the command as a macro line. See "Command mode" |
| 11 | Friends, guild members | Open a whisper |

**Drag**: spells, items, macros, mounts, pets and toys drag from the row. The box closes on drag start. Out of combat only.

## Command mode

Decided 2026-11-19 from mock v13.

- A query that starts with `/` lists only slash commands. With only `/` typed, the most used come first, then addon commands, then by name. An exact alias (`/atr`, `/w`) goes first.
- Rows show the addon's TOC icon (`IconTexture` or `IconAtlas`), the addon title and the aliases.
- Enter runs the command as it is. Space on a command makes it a grey token in the field, and the rest of the query is its argument.
- With a token, the rows are the arguments you ran before with that command (`LookupDB.args`, the 20 most recent per command), then a last row that runs exactly what you typed. Backspace on an empty argument removes the token.
- The Query session (`Session.lua`) owns all of this, the calculator and pick memory; `UI.lua` paints its view. `/lookup reset` forgets entries and arguments.
- A typed line that matches no command, or that has a space, gets an "As typed" row, so any command still runs.
- Later: Blizzard commands with known arguments (`/w` and `/invite` take people, `/join` takes channels), and subcommands from AceConfig tables. Learning subcommands from `help` output is optional and runs only on request.

## Other addons

Goal: other addons' features appear with no per-addon code. Decided 2026-11-18 after a review of the discovery surfaces.

**Attribution.** `issecurevariable(table, key)` names the addon that set a value. Lookup uses it to tell addon commands and bindings from Blizzard's, and shows the addon's title as the context.

**Surfaces.** `Discovery.lua` finds them and returns discovery records; a provider per surface in `Sources.lua` turns them into entries.

| Surface | State | Rows | Enter does |
|---|---|---|---|
| Slash commands (`SlashCmdList` and its hidden import table, `SLASH_*1` tainted) | Built | One per command, context = addon title | Runs the command as a macro line, like every command (see "Command mode") |
| Key bindings (`GetBinding`, `BINDING_NAME_*` tainted) | Built | One per named binding | Addon bindings run through the override binding. `CLICK` and Blizzard bindings open Key Bindings |
| LibDataBroker-1.1 launchers (`DataObjectIterator`) | Built | One per launcher (category Addon, rank after panels) | `OnClick(frame, "LeftButton")`. The frame is the addon's LibDBIcon minimap button, or else an invisible frame where the box was |
| LibDataBroker data sources | Later | Their `text` as the value | — |
| Addon Compartment (`AddonCompartmentFrame.registeredAddons`) | Later: only Lookup used it on 2026-11-19 | One per addon | Its `func`, as the compartment menu calls it |
| AceConfig-3.0 (`IterateOptionsTables`) | Later | `<Addon> options` | `AceConfigDialog:Open(app)`. Toggles inside the tables only if the probe counts justify it |

The owner of a launcher is the addon with the launcher's name, else the addon that set its `OnClick`.

Rejected: scanning `_G` for functions (unknown arguments and side effects). The Encounter Journal does not exist on Forever (checked in game 2026-11-18), so boss loot needs a loot addon.

**Providers.** Every source, built-in or discovered, is a provider: `ns.provide(id, rank, build)` (`Providers.lua`), and its entries get its rank. Everything rebuilds on each open (about 12 ms for 966 entries on 2026-11-19). Add `events` (cache invalidation), `max` and `minQuery` per provider only when one measures slow, for example loot. Every entry gives data and one action from the closed set in "Terms"; the Action plan maps it to a proven mechanism. An entry with no action, two actions, or a line with a newline or over 255 characters is dropped and logged. For outside rows, the status line shows the exact macro line.

**Isolation.** `build` and plain steps run in `pcall`. A provider gets 500 entries per open; more are cut, with a log line. Over 5 ms is logged only. A build that throws or gives an invalid action counts as a failure, and three failures turn the provider off for the session.

**Public API, later.** `Lookup.RegisterProvider(id, spec)` after the built-in providers use the same registry. Loot ships as a separate addon (`Lookup_AtlasLoot`) on that API.

**Probe.** `/lookup probe` logs discovery records per surface (built and not yet built) and entries per provider, so the counts on real addon sets decide what to build next.

## Combat

The box closes when combat starts and does not open in combat (changed 2026-11-17 after the first in-game test: the secure row makes the box protected, so it could not hide in combat and kept the keyboard).

## Not in v1

No options page. Later: pins, user aliases, `@category` filters, mount and toy actions, queued combat actions. Other addons: see "Other addons".

## Panel-opening architecture

EasyFind reports that opening a Blizzard panel from addon code taints the action bars for the session (example: spellbook taints `MultiBarBottomLeft.showAllButtons`), which causes `ADDON_ACTION_BLOCKED` in combat. Its fix: rows are secure buttons with macrotext `/click <MicroButton>`, and Enter is override-bound to the selected row.

### Spike 1 result (2026-11-17)

Plain calls are out for panels. Secure rows work.

- `PlayerSpellsUtil.ToggleSpellBookFrame()` tainted `showAllButtons` on every action bar and `snappedToFrame` on the bottom bars.
- `ToggleCharacter("PaperDollFrame")` raised a secret-value error in `TextStatusBar.lua` at once. The character frame runs tainted code over secret health values.
- In the next combat, the tainted bars caused `ADDON_ACTION_BLOCKED` on `SetPointBase`/`ClearAllPointsBase` for `MainActionBar`, the bottom bars and `StanceBar`. The action bar disappeared. Unit frames and tooltips raised secret-value errors.
- The secure button with macrotext `/click CharacterMicroButton`, clicked through an override binding on Enter, left no taint, and the combat after it was clean.
- A focused EditBox consumes Enter, so the override binding does not fire. With no focus, it fires.
- Spike 1 cannot tell if map, settings or mounts taint by themselves, because spellbook tainted everything first.

### Spike 2 result (2026-11-17)

- A keyboard-enabled frame read typed text with `OnChar`. On Enter it called `SetPropagateKeyboardInput(true)`, the override binding fired, and the secure row opened the character window.
- `OpenWorldMap(mapID)`, `Settings.OpenToCategory(id)` and `ToggleCollectionsJournal(tab)`, each in its own session: no action bar taint, no blocked action and no error in the combat after.

### Decision

- **Input:** no EditBox. The box is a keyboard-enabled frame: `OnChar` adds text, `OnKeyDown` handles Backspace, Up/Down and Esc, and only Enter propagates. Paste is lost; that is acceptable for search.
- **Rows:** each row is a `SecureActionButtonTemplate` button. While the box is open out of combat, Enter is override-bound to the selected row.
- **Two kinds of action:**
  - Secure: macrotext `/click <MicroButton>` or `type="click"` on a tab button. Use for the character frame (and its tabs), the spellbook, and every panel not proven clean.
  - Plain call from the row's click handler: only for calls proven clean in a spike. So far `OpenWorldMap`, `Settings.OpenToCategory`, `ToggleCollectionsJournal`. A new plain call needs the same check: open it, fight, and `make log` shows no `TAINT`, `ADDON_ACTION_BLOCKED` or `ERROR`.
- **No anchors:** LookupRun sits over the selected row at screen coordinates. Anchoring it to a row made the box protected, and a protected box silently stops `SetPropagateKeyboardInput` from passing Enter on (found 2026-11-17).
- **Binding commands:** Forever's Character, Collections and Legacy tabs are Frames, so `/click` cannot reach them. Every panel and tab with a Blizzard binding command (`TOGGLECURRENCY`, `TOGGLECHARACTER2`, `TOGGLECOLLECTIONSMOUNTJOURNAL`, ...) opens on Enter through `SetOverrideBinding(owner, true, "ENTER", command)`, which runs Blizzard's binding securely. The mouse falls back to `/click <MicroButton>`, so a click on Currency opens the character frame on its current tab.
- **Unnamed tab buttons:** a second secure button, `LookupTab`, has `type="click"` and `clickbutton` set to the tab (for example a spellbook school tab). LookupRun's macro runs `/click SpellbookMicroButton` and then `/click LookupTab`. The tab exists only after its panel has loaded once, so the first open falls back to the binding command.
- **Deep links:** after the secure part, an entry's plain `run` may select inside the open panel (mount, pet, macro, bag search). Each one needs the taint check.
  - Skills and Statistics have no binding command, and their tabs are Frames. `TOGGLECHARACTER2` opens the character frame on Reputation, then `CharacterFrame:OnModeTabClicked(tab)` selects the tab. Reputation is used so that the plain step never hides or shows the paper doll. Taint check pending.
  - Legacy pages (Reward Track, Challenges, Tree): `TOGGLELEGACYSYSTEM`, then the event a tab click fires, `Legacy.SelectPage` with the tab's id. Lookup finds the tab by its text, never by a fixed index. Taint check pending.
  - A Legacy Challenge: the Challenges page, then `SelectChallenge(id)` on `LegacySystemFrame`. Taint check pending.
  - Every deep link into a panel that its binding toggles: if the panel is already open when the box opens, the row skips the binding (it would close the panel) and only selects.
- **Combat:** anchoring LookupRun over a row makes the box protected. Close the box on `PLAYER_REGEN_DISABLED` (before lockdown) and refuse to open in combat.
