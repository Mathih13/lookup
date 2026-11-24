# When the welcome window shows and counts as seen

The product rules are in `docs/design.md` "Opening and keys". The timing in `Setup.lua`:

- `ns.firstRun` waits for `PLAYER_ENTERING_WORLD` and then shows the window on the next frame (`C_Timer.After(0)`). The game's own handler for that event closes every window (`CloseAllWindows`), and the next frame runs after every handler. In combat, it waits for `PLAYER_REGEN_ENABLED`.
- Closing the window any way (Skip, Esc, the close button) sets `LookupDB.setup`, so it does not come back on its own.
- The game also hides the window, for example on a loading screen. `OnHide` counts a close as the player's only when the window was shown for at least 1 second (`shownAt`).
- Key capture stops when combat starts (`PLAYER_REGEN_DISABLED`). "Use this key" does nothing in combat.
