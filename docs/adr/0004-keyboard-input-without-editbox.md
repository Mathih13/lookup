# Keyboard input without an EditBox

The box is a keyboard-enabled frame with no EditBox. `OnChar` adds text, and only Enter propagates, to the override binding on `LookupRun` (see `docs/design.md` "Panel-opening architecture", Decision: Input). A focused EditBox consumes Enter, so the binding would not fire. This choice has these consequences in `UI.lua` and `Session.lua`:

- The key that opened the box can also send its character (Shift+F types "F"). `OnChar` ignores characters until the box sees a key press of its own (the `fresh` flag).
- A space as the first character is dropped in `Session:type`. It comes from the default Shift+Space binding that opened the box.
- The box takes every key, so Lookup's own binding never runs while it is open. `OnKeyDown` checks for that key (`isLookupKey`) and closes the box.
- Shift+Enter keeps the box open, unless the entry has an `alt`, which Shift picks instead (`ns.activate`).
- Moving `LookupRun` with the keyboard can put a row under a cursor that has not moved. `OnEnter` selects the row only when the cursor position changed.
