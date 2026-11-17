local addonName, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	print(addonName .. " loaded")
	ns.log("PLAYER_LOGIN", addonName)
end)
