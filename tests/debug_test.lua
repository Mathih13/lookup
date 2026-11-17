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
ns.log("a", 1, nil, "SECRET")
handler("boom")
onEvent()
assert(LookupLog[1]:match("a 1 nil <secret>$"), LookupLog[1])
assert(LookupLog[2]:match("ERROR boom \nstack"), LookupLog[2])
assert(prevCalls == 1)
for i = 1, 2000 do ns.log(i) end
assert(#LookupLog == 1000 and LookupLog[1000] == "log full, later lines dropped")
print("ok")
