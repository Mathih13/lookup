local addonName, ns = ...

BINDING_HEADER_LOOKUP = "Lookup"
BINDING_NAME_LOOKUP_TOGGLE = "Open search"
local DEFAULT_KEY = "SHIFT-SPACE"

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
