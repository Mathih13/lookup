-- First-time setup: which key to suggest, and what a taken key does now.
local load = dofile("tests/stubs.lua")
local ns = load({ "Lookup/Setup.lua" })

local bound = {}
local function actionOf(key) return bound[key] end

-- Nothing bound: the first suggestion.
assert(ns.suggestKey(actionOf) == "CTRL-SPACE")
-- Taken keys are skipped.
bound["CTRL-SPACE"] = "TOGGLEAUTORUN"
assert(ns.suggestKey(actionOf) == "CTRL-F")
-- All taken: the first suggestion, and the window says what it replaces.
bound["CTRL-F"], bound["SHIFT-F"] = "FOCUSTARGET", "TOGGLEFRIENDSTAB"
assert(ns.suggestKey(actionOf) == "CTRL-SPACE")
BINDING_NAME_TOGGLEAUTORUN = "Toggle Autorun"
assert(ns.keyConflict("CTRL-SPACE", actionOf) == "Toggle Autorun")
-- No binding name: the command itself.
assert(ns.keyConflict("CTRL-F", actionOf) == "FOCUSTARGET")
-- Free, or already Lookup's: no conflict.
assert(ns.keyConflict("ALT-L", actionOf) == nil)
bound["ALT-L"] = "LOOKUP_TOGGLE"
assert(ns.keyConflict("ALT-L", actionOf) == nil)

-- Keycap labels: modifiers in short form, the key as the game names it.
local text = function(k) return k == "SPACE" and "Spacebar" or k end
local parts = ns.keyParts("CTRL-SHIFT-SPACE", text)
assert(parts[1] == "Ctrl" and parts[2] == "Shift" and parts[3] == "Spacebar" and #parts == 3)
-- Only combos and F keys are choices: plain keys keep moving the character.
assert(ns.isKeyChoice("CTRL-SPACE") and ns.isKeyChoice("F5") and ns.isKeyChoice("SHIFT-F"))
assert(not ns.isKeyChoice("W") and not ns.isKeyChoice("SPACE") and not ns.isKeyChoice("F"))

print("ok")
