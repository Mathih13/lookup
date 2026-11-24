-- Development log, saved to SavedVariables (LookupLog) so it can be read from disk after
-- /reload. Keeps the tail of earlier sessions, so several reloads can be read at once.
--
-- Only in development copies: the release packager comments out the debug block below, so
-- players get a no-op ns.log, no error handler and no saved log.
local addonName, ns = ...

---@diagnostic disable-next-line: duplicate-set-field
function ns.log() end

--@debug@

local MAX_ENTRIES = 1000 -- ponytail: keeps the first 1000 lines per session; the first error is usually the root cause
local KEEP_OLD = 1000 -- lines kept from earlier sessions
local entries, count = {}, 0

local function str(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	return tostring(v)
end

---Append one line to the session log. Arguments are joined with spaces.
---@diagnostic disable-next-line: duplicate-set-field
function ns.log(...)
	if count >= MAX_ENTRIES then return end
	count = count + 1
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = str((select(i, ...)))
	end
	entries[#entries + 1] = date("%H:%M:%S") .. " " .. table.concat(parts, " ")
	if count == MAX_ENTRIES then entries[#entries] = "log full, later lines dropped" end
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

-- The game loads saved data after this file runs: merge it at ADDON_LOADED and
-- assign the global at logout. /reload also fires PLAYER_LOGOUT, then writes SavedVariables.
-- Blocked and forbidden actions are taint symptoms, from any addon.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= addonName then return end
		local old, merged = LookupLog or {}, {}
		for i = math.max(1, #old - KEEP_OLD + 1), #old do merged[#merged + 1] = old[i] end
		merged[#merged + 1] = "--- new session"
		for _, line in ipairs(entries) do merged[#merged + 1] = line end
		entries = merged
	elseif event == "PLAYER_LOGOUT" then
		LookupLog = entries
	else
		ns.log(event, ...)
	end
end)
--@end-debug@
