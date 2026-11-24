# Run entries through Blizzard's own entry points

The rules and the spike results are in `docs/design.md` "Panel-opening architecture". In short: a panel open from plain addon code taints the action bars, so entries open panels through a secure path. The secure paths are a binding command, a `/click`, or a Blizzard slash command. Plain code runs only after the secure part, or alone for calls proven clean. This ADR collects the code-level consequences that used to be comments.

## Secure buttons

- `LookupRun` acts on release (`useOnKeyDown` false), for keys and the mouse alike. `LookupTab` also acts on release, because `/click` sends only the release.
- `LookupRun` sits at screen coordinates over the selected row (`arm` in `UI.lua`). An anchor to the row would make the box protected.
- The right button runs the `alt` (`type2`). An alt with no secure part sets `ATTRIBUTE_NOOP`. With no alt, the right button falls back to `type`, like the left button.
- For a `binding` plan, Enter goes to `SetOverrideBinding(owner, true, "ENTER", command)`: Blizzard's binding runs the command securely.
- Enter propagates only when the override binding must fire: for a `binding` plan or a `click` plan. `ns.activate` then runs the plain `after` step. For a binding it runs on the next frame (`C_Timer.After(0)`), after the binding.
- After a `binding` plan, `disarm` keeps the override binding until Enter is up (`IsKeyDown("ENTER")`, the `release` frame). A binding declared with `runOnUp` then gets its release, and no API tells Lookup which bindings have it. Combat start clears the binding at once.
- A row's own `OnClick` runs only when `LookupRun` is missing. It logs that case.
- The box closes on `PLAYER_REGEN_DISABLED`. That event fires just before lockdown, while hiding is still allowed.

## Panels and deep links (`Sources.lua`)

- `inPanel`: when the panel is already open as the box opens, its binding would close it, so the row only selects. Otherwise the binding opens the panel and the select step runs after it. `ns.plan` applies the same rule to tabs: when the tab is visible, the macro clicks only the tab.
- Currency: on a new character the game's `TOGGLECURRENCY` binding does nothing. While `C_CurrencyInfo.GetCurrencyListSize()` is 0, the Currency row prints a message instead of running the binding.
- Skills and Statistics: the Reputation binding opens the character frame, then `CharacterFrame:OnModeTabClicked(tab)` selects the tab. Reputation is used, not Character, so the plain step never hides or shows the paper doll, which reads secret values.
- Legacy pages: the tabs are Frames. A click fires `Legacy.SelectPage` with the tab's id. Lookup finds a tab by its text, so a new tab order does not break the rows.
- Legacy Challenges: a series shows as one row, so `selectChallenge` selects the step on display (`AchievementFrame_FindDisplayedAchievement`).
- Calendar, Stopwatch, Clock and Edit Mode have no binding command on Forever. A secure macro line opens them, as a click on their minimap button or the typed command would. Edit Mode opens through Blizzard's `/editmode` handler, because `ShowUIPanel` from addon code would taint Edit Mode.
- Spells: no page jump. `GoToSpell` from addon code taints the spellbook and the action bars.
- Bag items: the item search filter stays until something clears it, so Lookup clears it when the bags close (the `OnHide` hook on `ContainerFrameCombinedBags` and `ContainerFrame1`).
- Settings: a CVar in `CVAR_FALLBACKS` gets its own toggle only when the Settings walk found no entry for it. In 2026-11, a comment said the Damage Meter setting registers only on standard realms. Blizzard's Forever source registers it on every realm except Plunderstorm (`AdvancedOptions.lua`). The fallback logs `settings: no Settings entry for` when it fires, so `make log` shows whether Forever still needs it.
- Minimap tracking uses `MinimapUtil.SetTrackingFilterByFilterIndex` when it exists. It also keeps the Options panel in step for the filters shown there (trivial quests).
- Key bindings: addon bindings run. `CLICK` bindings press another addon's secure button (use an item, target), and Blizzard's include movement, so those rows open Key Bindings.
- Slash commands run as macro lines, as if typed. Secure commands (`/cast`) are not in `SlashCmdList`.

## Frames that load on first open

The spellbook school tabs (`spellTab`) and the Legacy frame's tabs exist only after the player opens that panel once. Until then, the spell row opens the book without a tab, and the Legacy rows use the micro menu icon.
