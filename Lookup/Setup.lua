local _, ns = ...

local CANDIDATES = { "CTRL-SPACE", "CTRL-F", "SHIFT-F" }

---@param actionOf fun(key: string): string? GetBindingAction
function ns.suggestKey(actionOf, candidates)
	candidates = candidates or CANDIDATES
	for _, key in ipairs(candidates) do
		if (actionOf(key) or "") == "" then return key end
	end
	return candidates[1]
end

---@param actionOf fun(key: string): string? GetBindingAction
function ns.keyConflict(key, actionOf)
	local action = actionOf(key) or ""
	if action == "" or action == "LOOKUP_TOGGLE" then return nil end
	local name = _G["BINDING_NAME_" .. action]
	return type(name) == "string" and name or action
end

local window
local chosen

local function refresh()
	window.key:SetText(window.capturing and "Press a key..." or GetBindingText(chosen))
	local conflict = not window.capturing and ns.keyConflict(chosen, GetBindingAction)
	if window.capturing then
		window.note:SetText("Esc to cancel")
	elseif conflict then
		window.note:SetText("|cffff9933Now used for " .. conflict .. ". Lookup will replace it.|r")
	else
		window.note:SetText("Click the key to choose another")
	end
end

local function capture(on)
	window.capturing = on
	window:EnableKeyboard(on)
	refresh()
end

local function finish()
	LookupDB.setup = true
	window:Hide()
end

local function build()
	local f = CreateFrame("Frame", "LookupSetup", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(380, 200)
	f:SetPoint("CENTER", 0, 140)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f.TitleText:SetText("Lookup")
	tinsert(UISpecialFrames, "LookupSetup")

	local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	intro:SetPoint("TOP", 0, -40)
	intro:SetWidth(330)
	intro:SetText("Search panels, spells, settings and commands from one box. Choose a key to open it.")

	f.key = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.key:SetSize(180, 30)
	f.key:SetPoint("TOP", intro, "BOTTOM", 0, -16)
	f.key:SetScript("OnClick", function() capture(not f.capturing) end)

	f.note = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.note:SetPoint("TOP", f.key, "BOTTOM", 0, -6)
	f.note:SetWidth(340)

	local use = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	use:SetSize(130, 24)
	use:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 34)
	use:SetText("Use this key")
	use:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		SetBinding(chosen, "LOOKUP_TOGGLE")
		SaveBindings(GetCurrentBindingSet())
		print("Lookup: press " .. GetBindingText(chosen) .. " to search.")
		finish()
		ns.toggle()
	end)

	local skip = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	skip:SetSize(130, 24)
	skip:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 34)
	skip:SetText("Skip")
	skip:SetScript("OnClick", finish)

	local later = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	later:SetPoint("BOTTOM", 0, 14)
	later:SetText("Later: Key Bindings > Lookup, or /lookup setup")

	f:SetScript("OnKeyDown", function(self, key)
		self:SetPropagateKeyboardInput(false)
		if key == "ESCAPE" then
			capture(false)
		elseif not IsKeyPressIgnoredForBinding(key) then
			chosen = CreateKeyChordStringUsingMetaKeyState(key)
			capture(false)
		end
	end)
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function() capture(false) end)
	f:SetScript("OnHide", function()
		capture(false)
		if GetTime() - (f.shownAt or 0) >= 1 then LookupDB.setup = true end
	end)
	return f
end

function ns.showSetup()
	if InCombatLockdown() then
		print("Lookup: setup opens after combat.")
		return
	end
	window = window or build()
	chosen = GetBindingKey("LOOKUP_TOGGLE") or ns.suggestKey(GetBindingAction)
	window.capturing = false
	window.shownAt = GetTime()
	window:Show()
	refresh()
end

function ns.firstRun()
	LookupDB.bound = nil
	if LookupDB.setup then return end
	if GetBindingKey("LOOKUP_TOGGLE") then
		LookupDB.setup = true
		return
	end
	local wait = CreateFrame("Frame")
	wait:RegisterEvent("PLAYER_ENTERING_WORLD")
	wait:SetScript("OnEvent", function(_, event)
		wait:UnregisterAllEvents()
		if InCombatLockdown() then
			wait:RegisterEvent("PLAYER_REGEN_ENABLED")
		elseif event == "PLAYER_ENTERING_WORLD" then
			C_Timer.After(0, ns.showSetup)
		else
			ns.showSetup()
		end
	end)
end
