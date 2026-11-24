# No comments in code

Decided 2026-11-24. Lua files carry no comments. Names, tests and these ADRs carry the meaning instead. An audit of the 319 comments in the code found that most repeated the code, some had gone stale, and some excused a shortcut that then spread. The few that recorded a real decision now live in `docs/adr/`, in one place a reviewer reads, grouped by topic.

When code needs a comment to be understood, change the code first: give the value or the helper a name that says it. When a choice is non-obvious (a taint rule, a client quirk, a timing constraint), write or extend an ADR and name the function it applies to. When code is a known shortcut, open an issue.

## Allowed

- LuaLS annotations: `---@param`, `---@return`, `---@diagnostic`, and inline casts such as `--[[@as string?]]`. The checker reads them.
- Packager directives such as `--@debug@` and `--@end-debug@`. The release build reads them.

## Enforcement

`make check` runs `scripts/comments.lua check`. It counts the comments in every file under `Lookup/`, `tests/` and `scripts/` and compares each count with `.comments-baseline`:

- A count above the baseline fails. A new file has a baseline of 0.
- A count below the baseline also fails until you run `make comments-baseline`, so each deletion stays locked in.
- `make comments-baseline` never raises a count. Deleting `.comments-baseline` resets it to the current counts, and that shows in review.

The baseline lets the clean-up happen over several changes. On 2026-11-24 `Lookup/` and `scripts/` reached 0. `tests/` keeps its scenario labels until they become named test cases.

## Considered options

- LuaLS, luacheck and selene have no rule that bans comments, so the check is a small tokenizer in plain Lua 5.1. It skips strings and long brackets, so text such as `"--- new session"` does not count.
- A single repository-wide count: rejected, because a deleted comment in one file would let a new one appear in another.
