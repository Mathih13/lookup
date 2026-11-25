# Development log in SavedVariables

`Debug.lua` saves `ns.log` lines and every Lua error to `LookupLog`, so `make log` can read a session from disk after `/reload`. It exists only in development copies: the release packager comments out the `--@debug@` block, and players get a no-op `ns.log`, no error handler and no saved log.

- The log keeps the first `MAX_ENTRIES` (1000) lines of a session and drops later ones. The first error is usually the root cause, so a ring buffer that keeps the last lines would lose it.
- It keeps the last `KEEP_OLD` (1000) lines of earlier sessions, so several reloads can be read at once. `--- new session` separates sessions.
- The game loads saved data after the file runs. The log merges the old lines at `ADDON_LOADED` and assigns the global at `PLAYER_LOGOUT`. `/reload` also fires `PLAYER_LOGOUT`, and then writes SavedVariables.
- The error handler records errors from every addon, then passes each one to the previous handler, so the in-game error display still works.
- `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` are logged from every addon: they are taint symptoms.
