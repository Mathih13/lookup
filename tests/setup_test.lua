local ns = dofile("tests/stubs.lua")({ "Lookup/Setup.lua" })

local function bindings(bound)
	return function(key) return bound[key] end
end

test("with nothing bound, the first suggestion wins", function()
	assert(ns.suggestKey(bindings({})) == "CTRL-SPACE")
end)

test("taken suggestions are skipped", function()
	assert(ns.suggestKey(bindings({ ["CTRL-SPACE"] = "TOGGLEAUTORUN" })) == "CTRL-F")
end)

test("with every suggestion taken, the first one wins and the card names what it replaces", function()
	local actionOf = bindings({ ["CTRL-SPACE"] = "TOGGLEAUTORUN", ["CTRL-F"] = "FOCUSTARGET", ["SHIFT-F"] = "TOGGLEFRIENDSTAB" })
	BINDING_NAME_TOGGLEAUTORUN = "Toggle Autorun"
	assert(ns.suggestKey(actionOf) == "CTRL-SPACE")
	assert(ns.keyConflict("CTRL-SPACE", actionOf) == "Toggle Autorun")
end)

test("a binding with no name is named by its command", function()
	assert(ns.keyConflict("CTRL-F", bindings({ ["CTRL-F"] = "FOCUSTARGET" })) == "FOCUSTARGET")
end)

test("a free key, or one that already opens Lookup, is no conflict", function()
	assert(ns.keyConflict("ALT-L", bindings({})) == nil)
	assert(ns.keyConflict("ALT-L", bindings({ ["ALT-L"] = "LOOKUP_TOGGLE" })) == nil)
end)

test("keycaps show modifiers in short form and the key as the game names it", function()
	local text = function(k) return k == "SPACE" and "Spacebar" or k end
	local parts = ns.keyParts("CTRL-SHIFT-SPACE", text)
	assert(parts[1] == "Ctrl" and parts[2] == "Shift" and parts[3] == "Spacebar" and #parts == 3)
end)

test("only combos and F keys are choices, so plain keys keep moving the character", function()
	assert(ns.isKeyChoice("CTRL-SPACE") and ns.isKeyChoice("F5") and ns.isKeyChoice("SHIFT-F"))
	assert(not ns.isKeyChoice("W") and not ns.isKeyChoice("SPACE") and not ns.isKeyChoice("F"))
end)

done()
