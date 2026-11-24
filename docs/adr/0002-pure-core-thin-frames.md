# Pure core, thin frame code

Logic that does not need the client lives in pure files that use no frames: `Match.lua` (matching, ranking, the calculator), `Action.lua` (the Action plan), `Session.lua` (the Query session and Pick memory), and the helpers `ns.suggestKey`, `ns.keyConflict`, `ns.keyParts` and `ns.isKeyChoice` at the top of `Setup.lua`. `tests/*_test.lua` run them in plain `lua5.1`. `UI.lua` only paints `Session:view()` and runs the Action plan. So most logic is tested without the game, and the frame code that needs the client stays small.

## Consequences

- The game loads SavedVariables after the addon files run. So `UI.lua` makes the session on the first open (`ns.toggle`), when `LookupDB` exists. It does not make it when the file loads.
- `ns.rank` does not write onto entries, except for a cached `norm`. `tests/session_test.lua` checks this.
