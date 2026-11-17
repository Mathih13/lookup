-- Session log saved to SavedVariables (LookupLog) so it can be read from disk
-- after /reload. Holds only the latest session.
local _, ns = ...

local MAX_ENTRIES = 1000 -- ponytail: keeps the first 1000 lines; the first error is usually the root cause
local entries = {}

local function str(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	return tostring(v)
end

---Append one line to the session log. Arguments are joined with spaces.
function ns.log(...)
	if #entries >= MAX_ENTRIES then return end
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = str((select(i, ...)))
	end
	entries[#entries + 1] = date("%H:%M:%S") .. " " .. table.concat(parts, " ")
	if #entries == MAX_ENTRIES then entries[#entries] = "log full, later lines dropped" end
end

-- Record every Lua error (from any addon), then pass it to the previous handler
-- so the in-game error display still works.
local previousHandler = geterrorhandler()
local inHandler = false
seterrorhandler(function(msg)
	if not inHandler then
		inHandler = true
		pcall(ns.log, "ERROR", msg, "\n" .. (debugstack(3) or ""))
		inHandler = false
	end
	return previousHandler(msg)
end)

-- The game loads saved data over the global after this file runs, so assign it
-- at logout. /reload also fires PLAYER_LOGOUT, then writes SavedVariables.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function()
	LookupLog = entries
end)
