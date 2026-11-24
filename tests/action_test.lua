local ns = dofile("tests/stubs.lua")({ "Lookup/Action.lua" })
local noop = function() end

-- Exactly one kind, and modifiers only where they apply.
assert(ns.actionKind({ binding = "OPENALLBAGS" }) == "binding")
assert(ns.actionKind({ line = "/macro" }) == "line")
assert(ns.actionKind({ call = noop }) == "call")
assert(ns.actionKind({ toggle = { get = noop, set = noop } }) == "toggle")
local function bad(entry, why)
	local kind, err = ns.actionKind(entry)
	assert(kind == nil and err:find(why, 1, true), tostring(err))
	assert(ns.plan(entry) == nil)
end
bad({}, "no action")
bad({ line = "/a", call = noop }, "two actions")
bad({ line = "/a\n/cast Fireball" }, "one line")
bad({ line = "/" .. string.rep("a", 255) }, "one line")
bad({ call = "Settings.OpenToCategory" }, "not a function")
bad({ toggle = { get = noop } }, "get and set")
bad({ line = "/a", button = "X" }, "button needs a binding")
bad({ binding = "TOGGLESPELLBOOK", tab = noop }, "tab needs")
bad({ call = noop, after = noop }, "after needs")

-- A panel: Enter runs the binding, the mouse clicks the micro button.
local p = ns.plan({ binding = "TOGGLECURRENCY", button = "CharacterMicroButton" })
assert(p.enter == "binding" and p.command == "TOGGLECURRENCY" and p.macrotext == "/click CharacterMicroButton")
-- No button: the mouse has no secure part.
p = ns.plan({ binding = "TOGGLEWORLDMAP" })
assert(p.enter == "binding" and p.macrotext == nil)

-- A spell: with a tab button, Enter clicks LookupRun, which opens the book, then the tab.
local after = function() end
local spell = { binding = "TOGGLESPELLBOOK", button = "SpellbookMicroButton", tab = noop, after = after }
p = ns.plan(spell, false)
assert(p.enter == "click" and p.clickTab and p.macrotext == "/click SpellbookMicroButton\n/click LookupTab", p.macrotext)
assert(p.after == after)
-- The book is open: only the tab, or the click would close it.
p = ns.plan(spell, true)
assert(p.macrotext == "/click LookupTab", p.macrotext)
-- The tab button does not exist yet (book never opened): a plain panel open.
p = ns.plan(spell, nil)
assert(p.enter == "binding" and not p.clickTab)

-- A line: Enter clicks LookupRun.
p = ns.plan({ line = "/auctionator post" })
assert(p.enter == "click" and p.macrotext == "/auctionator post")

-- Plain kinds: nothing secure, Enter does not propagate.
p = ns.plan({ call = after })
assert(p.enter == "plain" and p.macrotext == nil and p.after == after)

-- A toggle flips and prints the new state.
local value = false
local said
local realPrint = print
print = function(s) said = s end
p = ns.plan({ name = "Auto Loot", toggle = { get = function() return value end, set = function(v) value = v end } })
assert(p.enter == "plain")
p.after()
print = realPrint
assert(value == true and said == "Auto Loot: On", said)

-- A second action for Shift-Enter: a spell casts, and the alt opens the book on its tab.
local cast = { line = "/cast Seal of Light",
	alt = { binding = "TOGGLESPELLBOOK", button = "SpellbookMicroButton", tab = function() end } }
assert(ns.actionKind(cast) == "line")
p = ns.plan(cast.alt, false)
assert(p.clickTab and p.macrotext == "/click SpellbookMicroButton\n/click LookupTab")
assert(select(2, ns.actionKind({ line = "/cast X", alt = { call = after, alt = { call = after } } })))
assert(select(2, ns.actionKind({ line = "/cast X", alt = {} })) == "alt: no action")
assert(select(2, ns.actionKind({ binding = "A", button = "B", tab = after,
	alt = { binding = "A", button = "B", tab = after } })) == "tab on both actions")

print("ok")
