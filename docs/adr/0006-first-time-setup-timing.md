# When the key card shows and counts as seen

The product rules are in `docs/design.md` "Opening and keys". The timing and key handling in `Setup.lua`:

- `ns.firstRun` waits for `PLAYER_ENTERING_WORLD` and then shows the card on the next frame (`C_Timer.After(0)`). The game's own handler for that event closes every window (`CloseAllWindows`), and the next frame runs after every handler. In combat, it waits for `PLAYER_REGEN_ENABLED`.
- The card keeps only presses that can be a choice (`ns.isKeyChoice`): a combo with a modifier, or an F key. Plain keys propagate, so the player can still move and chat while the card is open.
- Esc or "Not now" sets `LookupDB.setup`, so the card does not come back on its own.
- When combat starts, the card hides (`PLAYER_REGEN_DISABLED`): keyboard frames cannot change in combat. This hide sets `byGame`, so the card comes back at the next login.
- The game also hides the card, for example on a loading screen. `OnHide` counts a close as the player's only when the game did not hide it and the card was shown for at least 1 second (`shownAt`).
