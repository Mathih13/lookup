# Lookup design

Agreed with the user on 2026-11-17. Change this file when a decision changes.

## Product

A Spotlight-style search box for **WoW Forever only** (Interface `16001`). Use Forever's (Camelot) Blizzard UI paths; ignore retail-only systems. Personal tool first, but publishable: display text comes from the game's localized strings. Licence MIT.

v1 is **navigation only**: results open, toggle or link. Nothing casts or uses.

## Identity

Compete with EasyFind on:

1. **Light**: no static databases, lazy index from Blizzard APIs, near-zero work at login.
2. **No errors**: no taint, no secret-value errors, tested in combat.
3. **Patch-proof**: panels and settings come from Blizzard data, not hand-written tab indexes.
4. **Searches more**: quests in the log, friends, guild members.
5. **Spotlight feel**: recent picks in the empty box, few options.

Never copy EasyFind code (all rights reserved).

## Opening and keys

- Binding `Shift+Space`. On first login, bind it only if the key is unused, and print one line. `/lookup` opens the box; `/lookup reset` clears history. Addon compartment entry.
- The box auto-focuses. Up/Down select, Enter runs and closes, Shift+Enter runs and keeps it open, Esc or the binding closes. Mouse works.
- A toggle prints one chat line, for example `Damage Meter: Off`.

## Look

Minimal dark, slightly translucent box near the top of the screen, at most 8 rows. A row shows an icon, the name, a grey category label, and the key binding for the same thing when one exists. The empty box shows the 5 most recent picks.

## Matching and ranking

- Word-prefix match first, then initials (`bfd`), then fuzzy subsequence ranked lower.
- Ignore apostrophes and accents.
- A short English alias list (`rep`, `dmg`, `lfg`, ...) adds to real names.
- History boosts frequent and recent picks. One history for all characters; skip entries that do not exist on the current character.
- Equal matches rank by the category order below.

## Categories

A thing with several actions gets separate rows, for example `Map: Ashenvale` and `Quests in Ashenvale (3)`.

| Rank | Category | Enter does |
|---|---|---|
| 1 | UI panels and tabs | Open the panel or tab |
| 2 | Settings and key bindings | On/off: toggle in place and show state. Other: open Settings at it. Bindings: open Key Bindings. Skip protected settings |
| 3 | Zones, cities, dungeons, raids | Open the map on it |
| 4 | Quests in the log | `Quests in <zone>` (only when there are some) opens map with quest log. Title match opens the quest details. No waypoints or tracking |
| 5 | Mounts, pets, toys | Open Collections on it |
| 6 | Spells | Open the spellbook |
| 7 | Macros | Open the macro window on it |
| 8 | Bag items | Open bags with the item highlighted |
| 9 | Currencies, reputations, achievements | Open the right tab. Achievements are Forever's Legacy Challenges |
| 10 | Slash commands | Open chat with the command typed in |
| 11 | Friends, guild members | Open a whisper |

**Drag**: spells, items, macros, mounts and toys drag from the row icon. The box closes on drag start. Out of combat only.

## Combat

The box opens in combat. Results that need a panel show greyed with an "in combat" tag. Results that work in combat (setting toggles, whispers, chat) run.

## Not in v1

No options page. Later: pins, user aliases, `@category` filters, mount and toy actions, queued combat actions, discovering other addons' settings and commands.

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
- **Combat:** attributes and override bindings cannot change, and `SetPropagateKeyboardInput` is restricted. Set propagation back to false on `PLAYER_REGEN_DISABLED`. In combat, Enter runs the selected row's plain action in `OnKeyDown`; panel rows are greyed. Verify this when building v1.
