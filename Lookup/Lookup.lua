local addonName, ns = ...

BINDING_HEADER_LOOKUP = "Lookup"
BINDING_NAME_LOOKUP_TOGGLE = "Open search"

---Open or close the box. Used by the binding, /lookup and the addon compartment.
function Lookup_Toggle()
	ns.toggle()
end

SLASH_LOOKUP1 = "/lookup"
SlashCmdList.LOOKUP = function(msg)
	if msg == "probe" then
		ns.probe()
	elseif msg == "setup" then
		ns.showSetup()
	elseif msg == "reset" then
		ns.forget(LookupDB)
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
		ns.firstRun()
	end
end)
