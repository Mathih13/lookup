date = os.date
local handler, onEvent
local prevCalls = 0
function geterrorhandler() return function() prevCalls = prevCalls + 1 end end
function seterrorhandler(f) handler = f end
function debugstack() return "stack" end
function issecretvalue(v) return v == "SECRET" end
function CreateFrame() return { RegisterEvent = function() end, SetScript = function(_, _, f) onEvent = f end } end
local ns = {}
assert(loadfile("Lookup/Debug.lua"))("Lookup", ns)
ns.log("early")
LookupLog = { "old1", "old2" } -- saved data, loaded by the game after the file runs
onEvent(nil, "ADDON_LOADED", "OtherAddon")
onEvent(nil, "ADDON_LOADED", "Lookup")
ns.log("a", 1, nil, "SECRET")
handler("boom")
onEvent(nil, "ADDON_ACTION_BLOCKED", "Lookup", "UseAction()")
onEvent(nil, "PLAYER_LOGOUT")
assert(LookupLog[1] == "old1" and LookupLog[2] == "old2", LookupLog[1])
assert(LookupLog[3] == "--- new session", LookupLog[3])
assert(LookupLog[4]:match("early$"), LookupLog[4])
assert(LookupLog[5]:match("a 1 nil <secret>$"), LookupLog[5])
assert(LookupLog[6]:match("ERROR boom \nstack"), LookupLog[6])
assert(LookupLog[7]:match("ADDON_ACTION_BLOCKED Lookup UseAction%(%)$"), LookupLog[7])
assert(prevCalls == 1)
for i = 1, 2000 do ns.log(i) end
assert(#LookupLog == 3 + 1000 and LookupLog[#LookupLog] == "log full, later lines dropped")
print("ok")
