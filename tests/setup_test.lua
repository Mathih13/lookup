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

print("ok")
