local addonName, ns = ...

BINDING_HEADER_LOOKUP = "Lookup"
BINDING_NAME_LOOKUP_TOGGLE = "Open search"
local DEFAULT_KEY = "SHIFT-SPACE"

---Title and folder name of the addon that set tbl[key], or nil for Blizzard's own (secure)
---values and Lookup's.
function ns.addonOf(tbl, key)
	local secure, by = issecurevariable(tbl, key)
	if secure or not by or by == addonName then return nil end
	local title = C_AddOns.GetAddOnMetadata(by, "Title") or by
	-- Titles can carry colour codes and inline icons ("|T...|t AtlasLoot Forever [Core]").
	return strtrim((title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))), by
end

---Call f(command, addonTitle, addonFolder, aliases) for each slash command. addonTitle and
---addonFolder are nil for Blizzard's. aliases are the other spellings (SLASH_X2, ...).
---Chat moves registered commands into a hidden table on first use and empties SlashCmdList
---(ChatFrameUtil ImportListToHash), so read both. The SLASH_ global keeps the addon's taint.
function ns.eachSlash(f)
	local seen = {}
	local hidden = getmetatable(SlashCmdList)
	for _, list in ipairs({ SlashCmdList, hidden and type(hidden.__index) == "table" and hidden.__index or {} }) do
		for key in pairs(list) do
			local command = _G["SLASH_" .. key .. "1"]
			if type(command) == "string" and not seen[command] then
				seen[command] = true
				local aliases, i = {}, 2
				while type(_G["SLASH_" .. key .. i]) == "string" do
					aliases[#aliases + 1] = _G["SLASH_" .. key .. i]
					i = i + 1
				end
				local title, folder = ns.addonOf(_G, "SLASH_" .. key .. "1")
				f(command, title, folder, aliases)
			end
		end
	end
end

---Log how many entries each discovery surface in docs/design.md ("Other addons") would give.
function ns.probe()
	local n, names = {}, {}
	local function count(k, name)
		n[k] = (n[k] or 0) + 1
		if name then names[#names + 1] = k .. " " .. name end
	end
	ns.eachSlash(function(command, by)
		count(by and "slash.addon" or "slash.blizzard", by and (command .. " (" .. by .. ")"))
	end)
	for i = 1, GetNumBindings() do
		local command = GetBinding(i)
		if command and _G["BINDING_NAME_" .. command] then
			local by = ns.addonOf(_G, "BINDING_NAME_" .. command)
			count(by and "binding.addon" or "binding.blizzard", by and (command .. " (" .. by .. ")"))
		end
	end
	local compartment = AddonCompartmentFrame and AddonCompartmentFrame.registeredAddons
	for _, data in ipairs(compartment or {}) do count("compartment", tostring(data.text)) end
	local libStub = _G.LibStub
	local ldb = libStub and libStub("LibDataBroker-1.1", true)
	if ldb then
		for name, obj in ldb:DataObjectIterator() do count("ldb." .. tostring(obj.type), name) end
	end
	local ace = libStub and libStub("AceConfigRegistry-3.0", true)
	if ace then
		for app in ace:IterateOptionsTables() do count("aceconfig", app) end
	end
	for _, line in ipairs(names) do ns.log("probe", line) end
	local parts = {}
	for k, v in pairs(n) do parts[#parts + 1] = k .. "=" .. v end
	table.sort(parts)
	ns.log("probe counts", table.concat(parts, " "), "LibStub", libStub and "yes" or "no")
	print("Lookup probe: " .. table.concat(parts, ", "))
end

---Open or close the box. Used by the binding, /lookup and the addon compartment.
function Lookup_Toggle()
	ns.toggle()
end

SLASH_LOOKUP1 = "/lookup"
SlashCmdList.LOOKUP = function(msg)
	if msg == "probe" then
		ns.probe()
	elseif msg == "reset" then
		LookupDB.history = {}
		print("Lookup: history cleared.")
	else
		ns.toggle()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		LookupDB = LookupDB or {}
		LookupDB.history = LookupDB.history or {}
		LookupDB.args = LookupDB.args or {} -- per command: argument text -> {count, last}
	elseif event == "PLAYER_LOGIN" then
		ns.log("PLAYER_LOGIN", addonName)
		-- Bind the default key once, and only if nothing uses it.
		if not LookupDB.bound then
			LookupDB.bound = true
			if (GetBindingAction(DEFAULT_KEY) or "") == "" then
				SetBinding(DEFAULT_KEY, "LOOKUP_TOGGLE")
				SaveBindings(GetCurrentBindingSet())
				print("Lookup: press Shift+Space to search. Change it in Key Bindings.")
			else
				print("Lookup: Shift+Space is taken. Use /lookup or set a key in Key Bindings.")
			end
		end
	end
end)
