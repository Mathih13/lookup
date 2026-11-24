-- First-time setup: a welcome window that gives Lookup a key. See docs/design.md "First-time setup".
-- The helpers at the top are pure, for tests. The window is made on first show.
local _, ns = ...

-- Suggested keys, in order. The first one with no binding wins.
local CANDIDATES = { "CTRL-SPACE", "CTRL-F", "SHIFT-F" }

---The first suggested key that nothing uses, or the first one when all are taken.
---@param actionOf fun(key: string): string? GetBindingAction
function ns.suggestKey(actionOf, candidates)
	candidates = candidates or CANDIDATES
	for _, key in ipairs(candidates) do
		if (actionOf(key) or "") == "" then return key end
	end
	return candidates[1]
end

---The name of what a key does now, or nil when it is free or already opens Lookup.
---@param actionOf fun(key: string): string? GetBindingAction
function ns.keyConflict(key, actionOf)
	local action = actionOf(key) or ""
	if action == "" or action == "LOOKUP_TOGGLE" then return nil end
	local name = _G["BINDING_NAME_" .. action]
	return type(name) == "string" and name or action
end

local window -- made on first show
local chosen -- the key the window offers, as a binding string ("CTRL-SPACE")

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
	tinsert(UISpecialFrames, "LookupSetup") -- Esc closes it

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

	-- Capture: the next key with its modifiers, as Key Bindings reads it.
	f:SetScript("OnKeyDown", function(self, key)
		self:SetPropagateKeyboardInput(false)
		if key == "ESCAPE" then
			capture(false)
		elseif not IsKeyPressIgnoredForBinding(key) then
			chosen = CreateKeyChordStringUsingMetaKeyState(key)
			capture(false)
		end
	end)
	-- Key capture stops when combat starts.
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function() capture(false) end)
	-- Closing it any way counts as done: the window does not come back on its own.
	f:SetScript("OnHide", function()
		capture(false)
		-- The game hides it too, for example on a loading screen (CloseAllWindows). Only a
		-- window the player had time to see counts as closed by them.
		if GetTime() - (f.shownAt or 0) >= 1 then LookupDB.setup = true end
	end)
	return f
end

---Show the welcome window. It offers the key Lookup has, or the first free suggestion.
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

---At login: the window, once, for a player with no Lookup key. Out of combat, and after the
---game's own PLAYER_ENTERING_WORLD handler, which closes every window (CloseAllWindows).
function ns.firstRun()
	LookupDB.bound = nil -- the old auto-bind flag
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
			C_Timer.After(0, ns.showSetup) -- the next frame: after every handler of this event
		else
			ns.showSetup()
		end
	end)
end
