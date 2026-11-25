local ns = dofile("tests/stubs.lua")({ "Lookup/Action.lua" })
local noop = function() end
local after = function() end
local spell = { binding = "TOGGLESPELLBOOK", button = "SpellbookMicroButton", tab = noop, after = after }

test("an entry has exactly one action kind, and modifiers only where they apply", function()
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
end)

test("a panel runs its binding on Enter, and the mouse clicks its micro button", function()
	local p = ns.plan({ binding = "TOGGLECURRENCY", button = "CharacterMicroButton" })
	assert(p.enter == "binding" and p.command == "TOGGLECURRENCY" and p.macrotext == "/click CharacterMicroButton")
end)

test("a panel with no button gives the mouse no secure part", function()
	local p = ns.plan({ binding = "TOGGLEWORLDMAP" })
	assert(p.enter == "binding" and p.macrotext == nil)
end)

test("a spell with a tab button opens the book, then clicks the tab", function()
	local p = ns.plan(spell, false)
	assert(p.enter == "click" and p.clickTab and p.macrotext == "/click SpellbookMicroButton\n/click LookupTab", p.macrotext)
	assert(p.after == after)
end)

test("an open book gets only the tab click, because a panel click would close it", function()
	assert(ns.plan(spell, true).macrotext == "/click LookupTab")
end)

test("a tab button that does not exist yet falls back to the binding", function()
	local p = ns.plan(spell, nil)
	assert(p.enter == "binding" and not p.clickTab)
end)

test("a line clicks LookupRun", function()
	local p = ns.plan({ line = "/auctionator post" })
	assert(p.enter == "click" and p.macrotext == "/auctionator post")
end)

test("a plain call has no secure part", function()
	local p = ns.plan({ call = after })
	assert(p.enter == "plain" and p.macrotext == nil and p.after == after)
end)

test("a toggle flips and prints the new state", function()
	local value, said = false, nil
	local realPrint = print
	print = function(s) said = s end
	local p = ns.plan({ name = "Auto Loot", toggle = { get = function() return value end, set = function(v) value = v end } })
	p.after()
	print = realPrint
	assert(p.enter == "plain" and value == true and said == "Auto Loot: On", said)
end)

test("an alt is one more action for Shift-Enter, with no alt and no second tab", function()
	local cast = { line = "/cast Seal of Light",
		alt = { binding = "TOGGLESPELLBOOK", button = "SpellbookMicroButton", tab = noop } }
	assert(ns.actionKind(cast) == "line")
	local p = ns.plan(cast.alt, false)
	assert(p.clickTab and p.macrotext == "/click SpellbookMicroButton\n/click LookupTab")
	assert(select(2, ns.actionKind({ line = "/cast X", alt = { call = after, alt = { call = after } } })))
	assert(select(2, ns.actionKind({ line = "/cast X", alt = {} })) == "alt: no action")
	assert(select(2, ns.actionKind({ binding = "A", button = "B", tab = after,
		alt = { binding = "A", button = "B", tab = after } })) == "tab on both actions")
end)

done()
