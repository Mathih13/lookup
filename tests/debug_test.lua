dofile("tests/stubs.lua")
date = os.date
local handler, onEvent
local previousHandlerCalls = 0
function geterrorhandler() return function() previousHandlerCalls = previousHandlerCalls + 1 end end
function seterrorhandler(f) handler = f end
function debugstack() return "stack" end
function CreateFrame() return { RegisterEvent = function() end, SetScript = function(_, _, f) onEvent = f end } end
local ns = {}
assert(loadfile("Lookup/Debug.lua"))("Lookup", ns)

test("the log keeps saved lines, then this session's lines, errors and taint events", function()
	ns.log("early")
	local savedByTheGameAfterTheFileRuns = { "old1", "old2" }
	LookupLog = savedByTheGameAfterTheFileRuns
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
	assert(previousHandlerCalls == 1)
end)

test("the log keeps the first 1000 lines of a session", function()
	for i = 1, 2000 do ns.log(i) end
	assert(#LookupLog == 3 + 1000 and LookupLog[#LookupLog] == "log full, later lines dropped")
end)

done()
