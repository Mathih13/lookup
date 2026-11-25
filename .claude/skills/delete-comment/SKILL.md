---
name: delete-comment
description: Audit the comments in Lua files, move decisions into ADRs, file issues for shortcuts, and lower the comment ratchet.
disable-model-invocation: true
argument-hint: "[file or folder ...]"
---

# Delete comments

The policy and the ratchet are in `docs/adr/0001-no-code-comments.md`. The scope is `$ARGUMENTS`, or every file in `LUA_FILES` in the `Makefile` when it is empty.

## 1. List

Run `lua5.1 scripts/comments.lua list <files>`. It prints each counted comment as `path:line: text`. It skips LuaLS annotations (`---@...`, `--[[@as ...]]`) and packager directives (`--@debug@`). Leave those alone.

## 2. Categorise

Read each file whole before you judge its comments. Put every listed comment in exactly one category:

| Category | Test | Action |
|---|---|---|
| **Tautology** | The code, a name or a test already says it. A section banner. A doc line that restates the signature. | Delete. |
| **Stale** | It describes code that changed or a claim that is false now. Check the claim: run it in `lua5.1` with `tests/stubs.lua` when you can. | Delete. Note any defect it hid (step 4). |
| **Excuse** | It explains why a shortcut is acceptable: a duplicated value "that must match", a positional table that needs a legend, a special case, a "not reached" branch, a `ponytail:` note, a migration that stays forever. | Delete, and file an issue (step 4). |
| **Decision record** | It records a non-obvious choice: a taint rule, a client quirk, an event order, a reason a simpler call is wrong. | Move it into an ADR (step 3), then delete. |

When a comment only explains a value or a pattern, give the value a name that says it (`MACROTEXT_LIMIT`, `LAST_UTF8_CHARACTER`). It is then a Tautology.

A comment in `tests/` that names a scenario is a test name. Move the scenario into `test("<the name>", function() ... end)` from `tests/stubs.lua`, with its own setup, and delete the comment.

## 3. Record decisions

1. Look in `docs/design.md` and `docs/adr/`. When a section or an ADR already covers the topic, extend it. Otherwise write the next `docs/adr/NNNN-slug.md`: a title, one to three sentences on the context and the decision, then bullets.
2. Name the function or the constant each bullet applies to. Use no line numbers: they go stale.
3. Check every claim against the code before you write it. The first audit found a comment that said "not reached" about a branch that a 263-character line reaches.

## 4. File issues

For each Excuse, and for each defect a Stale comment hid, run `gh issue create -R Mathih13/lookup`. Give the file, the function, the deleted comment in quotes, what the shortcut costs, and a fix. Add `--label bug` when players can see the defect.

## 5. Delete and lower the ratchet

1. Delete the comments. Collapse the blank lines this leaves.
2. Run `make comments-baseline`, then `make check test`.

## Done

- `lua5.1 scripts/comments.lua list <scope>` prints nothing.
- Every deleted Decision record is in `docs/design.md` or an ADR, and every Excuse has an issue.
- `make check test` passes, and `.comments-baseline` has the lower counts (empty once every file is at 0).
- Report a table: `path:line`, category, and the action (deleted, ADR file, or issue link). Then give the number of lines removed.
