local addonName, ns = ...

---@diagnostic disable-next-line: duplicate-set-field
function ns.log() end

--@debug@

local MAX_ENTRIES = 1000
local KEEP_OLD = 1000
local entries, count = {}, 0

local function str(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	return tostring(v)
end

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
