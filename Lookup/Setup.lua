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

function ns.keyParts(key, keyText)
	local MOD = { CTRL = "Ctrl", ALT = "Alt", SHIFT = "Shift", META = "Cmd" }
	local parts = {}
	for part in key:gmatch("[^-]+") do parts[#parts + 1] = MOD[part] or keyText(part) end
	return parts
end

function ns.isKeyChoice(chord)
	return chord:find("-") ~= nil or chord:match("^F%d+$") ~= nil
end

local card
local chosen
local confirm

local function words(key)
	return table.concat(ns.keyParts(key, GetBindingText), " + ")
end

local function keycap(parent)
	local cap = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	cap:SetHeight(40)
	cap:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	cap:SetBackdropColor(0.09, 0.09, 0.11, 1)
	cap:SetBackdropBorderColor(0.75, 0.6, 0.25, 1)
	cap.text = cap:CreateFontString(nil, "OVERLAY")
	cap.text:SetFont(STANDARD_TEXT_FONT, 19, "")
	cap.text:SetPoint("CENTER", 0, 1)
	return cap
end

local function refresh()
	local parts = ns.keyParts(chosen, GetBindingText)
	local total, prev = 0, nil
	for i, part in ipairs(parts) do
		local cap = card.caps[i] or keycap(card.keys)
		card.caps[i] = cap
		cap.text:SetText(part)
		cap:SetWidth(math.max(44, cap.text:GetStringWidth() + 26))
		cap:ClearAllPoints()
		if prev then
			local plus = card.plus[i] or card.keys:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
			card.plus[i] = plus
			plus:SetText("+")
			plus:ClearAllPoints()
			plus:SetPoint("LEFT", prev, "RIGHT", 8, 0)
			plus:Show()
			cap:SetPoint("LEFT", plus, "RIGHT", 8, 0)
			total = total + plus:GetStringWidth() + 16
		end
		total = total + cap:GetWidth()
		cap:Show()
		prev = cap
	end
	for i = #parts + 1, #card.caps do
		card.caps[i]:Hide()
		if card.plus[i] then card.plus[i]:Hide() end
	end
	card.caps[1]:SetPoint("LEFT", card.keys, "CENTER", -total / 2, 0)
	local name = words(chosen)
	local taken = ns.keyConflict(chosen, GetBindingAction)
	if taken and confirm == chosen then
		card.say:SetText("Press |cffffffff" .. name .. "|r again to use it for Lookup.")
	else
		card.say:SetText("Press |cffffffff" .. name .. "|r to open search.")
	end
	if taken then
		card.note:SetText("|cffff9933" .. name .. " is bound to " .. taken .. ".|r")
	else
		card.note:SetText("Or press another key to use that one.")
	end
end

local function bind()
	SetBinding(chosen, "LOOKUP_TOGGLE")
	SaveBindings(GetCurrentBindingSet())
	LookupDB.setup = true
	card:Hide()
	print("Lookup: " .. words(chosen) .. " opens search.")
	ns.toggle()
end

local function notNow()
	LookupDB.setup = true
	card:Hide()
	print("Lookup: type /lookup to search, or set a key in Key Bindings.")
end

local function build()
	local f = CreateFrame("Frame", "LookupSetup", UIParent)
	f:SetSize(380, 182)
	f:SetPoint("TOP", 0, -140)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:EnableMouse(true)
	for layer = -8, -7 do
		local bg = f:CreateTexture(nil, "BACKGROUND", nil, layer)
		bg:SetAtlas("common-dropdown-bg")
		bg:SetPoint("TOPLEFT", -10, 3)
		bg:SetPoint("BOTTOMRIGHT", 10, -3)
	end

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -16)
	title:SetText("Lookup")

	f.keys = CreateFrame("Frame", nil, f)
	f.keys:SetSize(340, 42)
	f.keys:SetPoint("TOP", 0, -40)
	f.caps, f.plus = {}, {}

	f.say = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
	f.say:SetPoint("TOP", 0, -96)
	f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	f.note:SetPoint("TOP", f.say, "BOTTOM", 0, -8)

	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 1, 1, 0.08)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", 18, 40)
	line:SetPoint("BOTTOMRIGHT", -18, 40)

	local later = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	later:SetPoint("BOTTOMLEFT", 20, 16)
	later:SetText("Change it later in Key Bindings.")

	local skip = CreateFrame("Button", nil, f)
	skip:SetSize(80, 20)
	skip:SetPoint("BOTTOMRIGHT", -14, 12)
	skip:SetNormalFontObject("GameFontDisable")
	skip:SetHighlightFontObject("GameFontHighlight")
	skip:SetText("Not now")
	skip:GetFontString():SetPoint("RIGHT")
	skip:SetScript("OnClick", notNow)

	f:EnableKeyboard(true)
	f:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			notNow()
			return
		end
		local chord = not IsKeyPressIgnoredForBinding(key) and CreateKeyChordStringUsingMetaKeyState(key)
		if not chord or not ns.isKeyChoice(chord) then
			self:SetPropagateKeyboardInput(true)
			return
		end
		self:SetPropagateKeyboardInput(false)
		if chord ~= chosen then
			chosen, confirm = chord, nil
			refresh()
		elseif ns.keyConflict(chosen, GetBindingAction) and confirm ~= chosen then
			confirm = chosen
			refresh()
		else
			bind()
		end
	end)

	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function(self)
		self.byGame = true
		self:Hide()
	end)
	f:SetScript("OnHide", function(self)
		if not self.byGame and GetTime() - (self.shownAt or 0) >= 1 then LookupDB.setup = true end
	end)
	return f
end

function ns.showSetup()
	if InCombatLockdown() then
		print("Lookup: setup opens after combat.")
		return
	end
	card = card or build()
	chosen = GetBindingKey("LOOKUP_TOGGLE") or ns.suggestKey(GetBindingAction)
	confirm = nil
	card.byGame = false
	card.shownAt = GetTime()
	card:Show()
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
