-- The search box, drawn with stock Blizzard art (mock v12). See docs/design.md "Look" and "Panel-opening architecture".
--
-- The box is a keyboard-enabled frame with no EditBox: OnChar adds text, and only
-- Enter propagates, to an override binding on one secure button (LookupRun).
-- LookupRun sits over the selected row (at screen coordinates, never anchored to
-- it) and holds that row's secure action. The box closes when combat starts and
-- does not open in combat, because LookupRun cannot move or change then.
local _, ns = ...

local MAX_ROWS = 8 -- must match Session.lua
local WIDTH, GUTTER, TOP, BOTTOM = 540, 12, 10, 8
local SEARCH_H, HEADER_H, ROW_H, ROW_GAP, STATUS_H = 28, 18, 38, 2, 28
local ROWS_TOP = TOP + SEARCH_H + 10
local ICON_X, NAME_X = 9, 47 -- in a row: icon slot, and name column
local GOLD = "|cffffd100" -- typed matches, and nothing else
local WHITE = "|cffffffff"

---A FontString in the default UI font (Friz Quadrata) with the standard drop shadow.
local function text(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT, size, "")
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetTextColor(r, g, b)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

local function color(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer)
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

local function atlas(parent, layer, name, sublevel)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetAtlas(name)
	return t
end

-- The box: the Midnight dropdown menu background, placed as MenuStyle1Mixin does
-- (10 outside at the sides, 3 at top and bottom).
local box = CreateFrame("Frame", "LookupFrame", UIParent)
box:SetSize(WIDTH, ROWS_TOP)
box:SetPoint("TOP", 0, -140)
box:SetFrameStrata("FULLSCREEN_DIALOG")
box:EnableKeyboard(true)
box:EnableMouse(true)
box:Hide()
-- Its centre is 95% opaque: two layers keep bright scenes from showing through a box this size.
for layer = -8, -7 do
	-- The atlas has its own 9-slice data: SetAtlas only, as MenuStyle1Mixin does.
	-- Explicit slice margins override it and stretch the corners.
	local bg = atlas(box, "BACKGROUND", "common-dropdown-bg", layer)
	bg:SetPoint("TOPLEFT", -10, 3)
	bg:SetPoint("BOTTOMRIGHT", 10, -3)
end

-- The search field: SearchBoxTemplate's three border pieces, dimmed so the selection is the
-- brightest edge. The magnifying glass sits over the icon column, the text over the names.
local field = CreateFrame("Frame", nil, box)
field:SetPoint("TOPLEFT", GUTTER, -TOP)
field:SetPoint("TOPRIGHT", -GUTTER, -TOP)
field:SetHeight(SEARCH_H)
do
	local left = atlas(field, "BACKGROUND", "common-search-border-left")
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(10)
	local right = atlas(field, "BACKGROUND", "common-search-border-right")
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(10)
	local middle = atlas(field, "BACKGROUND", "common-search-border-middle")
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	for _, t in ipairs({ left, right, middle }) do t:SetVertexColor(0.8, 0.8, 0.8) end
end
local glass = atlas(field, "ARTWORK", "common-search-magnifyingglass")
glass:SetSize(15, 15)
glass:SetPoint("CENTER", field, "LEFT", ICON_X + 14, 0)
local input = text(field, 16, 1, 1, 1)
input:SetPoint("LEFT", NAME_X, 0)
local placeholder = text(field, 16, 0.48, 0.48, 0.48)
placeholder:SetPoint("LEFT", NAME_X + 2, 0)
placeholder:SetText("Search spells, quests, zones, settings...")
local caret = color(field, "OVERLAY", 1, 1, 1, 0.9)
caret:SetSize(2, 17)
local count = text(field, 12, 0.48, 0.48, 0.48)
count:SetPoint("RIGHT", -16, 0)

-- A section heading: just above the first row, in line with the row icons.
local recentLabel = text(box, 12, 0.6, 0.6, 0.6)
recentLabel:SetPoint("BOTTOMLEFT", field, "BOTTOMLEFT", ICON_X, -(ROWS_TOP - TOP - SEARCH_H + HEADER_H - 3))
recentLabel:SetText("Recent")

-- The status line: what Enter does for the selected row, and a second hint, under the
-- menu divider (MenuVariants.CreateDivider).
local status = CreateFrame("Frame", nil, box)
status:SetPoint("BOTTOMLEFT", GUTTER, BOTTOM)
status:SetPoint("BOTTOMRIGHT", -GUTTER, BOTTOM)
status:SetHeight(STATUS_H)
do
	local divider = status:CreateTexture(nil, "BORDER")
	divider:SetTexture("Interface/Common/UI-TooltipDivider-Transparent")
	divider:SetPoint("TOPLEFT", 0, 6)
	divider:SetPoint("TOPRIGHT", 0, 6)
	divider:SetHeight(13)
end
local statusLeft = text(status, 12, 0.66, 0.66, 0.66)
statusLeft:SetPoint("LEFT", 10, 0)
local statusRight = text(status, 12, 0.66, 0.66, 0.66)
statusRight:SetPoint("RIGHT", -10, 0)

local run = CreateFrame("Button", "LookupRun", UIParent, "SecureActionButtonTemplate")
run:RegisterForClicks("AnyUp", "AnyDown")
run:RegisterForDrag("LeftButton")
run:SetAttribute("useOnKeyDown", false) -- act on release, for keys and mouse alike
run:SetFrameStrata("FULLSCREEN_DIALOG")
run:Hide()
local bindOwner = CreateFrame("Frame")

-- A second step for LookupRun's macro: "/click LookupTab" clicks a tab button that
-- has no global name (entry.tab returns it), for example a spellbook school tab.
local tab = CreateFrame("Button", "LookupTab", UIParent, "SecureActionButtonTemplate")
tab:SetAttribute("type", "click")
tab:SetAttribute("useOnKeyDown", false) -- /click sends only the release
local armed -- the selected entry's Action plan (Action.lua)
local armedAlt -- the plan for its alt (Shift-Enter and a right click), or nil
local session -- the Query session (Session.lua), made on first open: LookupDB loads after this file
local rows = {}

local function inCombat() return InCombatLockdown() end

local function value(entry)
	local v = entry.value
	if type(v) == "function" then v = v() end
	local shortcut = entry.shortcut or entry.binding
	if v == nil and shortcut then
		local key = GetBindingKey(shortcut)
		v = key and GetBindingText(key)
	end
	return v
end

local function setIcon(row, entry)
	local icon = row.icon
	if entry.portrait then
		SetPortraitTexture(icon, entry.portrait)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetSize(28, 28)
	elseif entry.atlas then
		icon:SetAtlas(entry.atlas)
		icon:SetSize(20, 20)
	else
		icon:SetTexture(entry.icon or 134400) -- question mark
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- hide the baked border
		icon:SetSize(28, 28)
	end
end

local function setRow(row, r)
	local entry = r.entry
	row.entry = entry
	setIcon(row, entry)
	row.name:SetText(ns.highlight(entry.name, r.hl, GOLD))
	row.sub:SetText(entry.cat .. (entry.sub and " · " .. entry.sub or ""))
	local checked = entry.toggle and entry.toggle.get()
	row.checkbox:SetShown(entry.toggle ~= nil)
	row.checkmark:SetShown(checked or false)
	row.value:SetText(not entry.toggle and value(entry) or "")
	row:Show()
end

local function setStatus(status)
	if status.message then
		statusLeft:SetText(status.message)
	else
		statusLeft:SetText(WHITE .. "Enter:|r " .. status.action)
	end
	statusRight:SetText(status.right and WHITE .. status.right[1] .. ":|r " .. status.right[2] or "")
end

for i = 1, MAX_ROWS do
	local row = CreateFrame("Button", nil, box)
	row:SetHeight(ROW_H)
	-- Selection: the Quick Join card outline (made for 38px rows), additive.
	row.highlight = atlas(row, "BACKGROUND", "friends-card-quickJoin-selected")
	row.highlight:SetTextureSliceMargins(6, 6, 6, 6)
	row.highlight:SetBlendMode("ADD")
	row.highlight:SetAlpha(0.9)
	row.highlight:SetAllPoints()
	-- Icon slot: a dark square in the achievement search icon frame, so atlas icons line up.
	row.slot = color(row, "BORDER", 0.03, 0.03, 0.05)
	row.slot:SetSize(28, 28)
	row.slot:SetPoint("LEFT", ICON_X, 0)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetPoint("CENTER", row.slot)
	local frame = atlas(row, "OVERLAY", "search-iconframe-large")
	frame:SetPoint("TOPLEFT", row.slot, -1, 1)
	frame:SetPoint("BOTTOMRIGHT", row.slot, 1, -1)
	row.value = text(row, 12, 0.71, 0.71, 0.71)
	row.value:SetPoint("RIGHT", -10, 0)
	row.value:SetJustifyH("RIGHT")
	row.checkbox = row:CreateTexture(nil, "ARTWORK")
	row.checkbox:SetAtlas("checkbox-minimal")
	row.checkbox:SetSize(18, 18)
	row.checkbox:SetPoint("RIGHT", -10, 0)
	row.checkmark = row:CreateTexture(nil, "OVERLAY")
	row.checkmark:SetAtlas("checkmark-minimal")
	row.checkmark:SetSize(18, 18)
	row.checkmark:SetPoint("CENTER", row.checkbox)
	row.name = text(row, 14, 1, 1, 1)
	row.name:SetPoint("TOPLEFT", row.slot, "TOPRIGHT", 10, 1)
	row.name:SetPoint("RIGHT", row.value, "LEFT", -24, 0)
	row.sub = text(row, 12, 0.77, 0.77, 0.77)
	row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.sub:SetPoint("RIGHT", row.value, "LEFT", -24, 0)
	row:SetScript("OnEnter", function()
		-- Moving LookupRun by keyboard can put a row under a still cursor: ignore that.
		local x, y = GetCursorPosition()
		if x ~= row.cursorX or y ~= row.cursorY then ns.select(i) end
		row.cursorX, row.cursorY = x, y
	end)
	-- LookupRun covers the selected row, so this runs only if it is missing.
	row:SetScript("OnClick", function()
		ns.log("row click (LookupRun missing)", row.entry and row.entry.key)
		ns.activate(row.entry)
	end)
	rows[i] = row
end

-- Put the selected entry's action on LookupRun and LookupRun over its row.
local function arm()
	if inCombat() then return end
	local row = rows[session.selected]
	local entry = row and row:IsShown() and row.entry
	armed, armedAlt = nil, nil
	if not entry then
		run:Hide()
		ClearOverrideBindings(bindOwner)
		return
	end
	local alt = entry.alt
	local tabOf = entry.tab or (alt and alt.tab)
	local tabButton = tabOf and tabOf()
	local visible = tabButton and tabButton:IsVisible()
	armed = ns.plan(entry, entry.tab and visible)
	armedAlt = alt and ns.plan(alt, alt.tab and visible) or nil
	if not armed then -- not reached: the registry drops entries with invalid actions
		run:Hide()
		ClearOverrideBindings(bindOwner)
		return
	end
	if armed.clickTab or (armedAlt and armedAlt.clickTab) then tab:SetAttribute("clickbutton", tabButton) end
	run:SetAttribute("type", armed.macrotext and "macro" or nil)
	run:SetAttribute("macrotext", armed.macrotext)
	-- The right button runs the alt. With an alt that has no secure part it does nothing secure;
	-- with no alt it falls back to "type", like the left button.
	run:SetAttribute("type2", armedAlt and (armedAlt.macrotext and "macro" or ATTRIBUTE_NOOP) or nil)
	run:SetAttribute("macrotext2", armedAlt and armedAlt.macrotext)
	-- Screen coordinates, no anchor to the row: an anchor would make the box protected.
	run:ClearAllPoints()
	run:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", row:GetLeft(), row:GetTop())
	run:SetSize(row:GetWidth(), row:GetHeight())
	run:SetFrameLevel(row:GetFrameLevel() + 10)
	run:Show()
	local function bind(key, plan, mouseButton)
		if plan.enter == "binding" then
			SetOverrideBinding(bindOwner, true, key, plan.command) -- Blizzard's binding runs it securely
		else
			SetOverrideBindingClick(bindOwner, true, key, "LookupRun", mouseButton)
		end
	end
	bind("ENTER", armed, "LeftButton")
	bind("SHIFT-ENTER", armedAlt or armed, armedAlt and "RightButton" or "LeftButton")
end

local function disarm()
	if inCombat() then return end
	ClearOverrideBindings(bindOwner)
	run:ClearAllPoints()
	run:Hide()
end

function ns.select(i)
	session:select(i)
	for j, row in ipairs(rows) do
		row.highlight:SetShown(j == session.selected and row:IsShown())
	end
	setStatus(session:view().status)
	arm()
end

-- Paint the session's view.
local function refresh()
	local view = session:view()
	local shown = view.query:gsub("|", "||")
	if view.token then shown = "|cff9a9a9a" .. view.token .. "|r " .. shown end
	input:SetText(shown)
	local width = input:GetStringWidth()
	placeholder:SetText(view.hint or "")
	placeholder:SetShown(view.hint ~= nil)
	placeholder:ClearAllPoints()
	placeholder:SetPoint("LEFT", input, "LEFT", width > 0 and width + 4 or 2, 0)
	caret:SetPoint("LEFT", input, "LEFT", width + 1, 0)
	count:SetText(view.count)
	recentLabel:SetShown(view.header ~= nil)
	recentLabel:SetText(view.header or "")
	local top = ROWS_TOP + (view.header and HEADER_H or 0)
	for i, row in ipairs(rows) do
		if view.rows[i] then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", GUTTER, -top - (i - 1) * (ROW_H + ROW_GAP))
			row:SetPoint("TOPRIGHT", -GUTTER, -top - (i - 1) * (ROW_H + ROW_GAP))
			setRow(row, view.rows[i])
		else
			row:Hide()
		end
	end
	local n = #view.rows
	local showStatus = n > 0 or view.query ~= "" or view.token ~= nil
	status:SetShown(showStatus)
	local rowsH = n > 0 and n * (ROW_H + ROW_GAP) - ROW_GAP or 0
	box:SetHeight(showStatus and top + rowsH + 6 + STATUS_H + BOTTOM or TOP + SEARCH_H + TOP)
	ns.select(view.selected)
end

function ns.close()
	disarm()
	box:Hide()
end

---Record the pick, close, then run the plan's plain step. Called after the secure
---part (LookupRun click or binding command), or alone when there is none.
---useAlt: Shift-Enter or a right click ran the entry's alt.
function ns.activate(entry, useAlt)
	if not entry then return end
	if session:pick(entry) then -- the calculator: its result is now the query
		refresh()
		return
	end
	ns.log("activate", entry.key)
	-- Shift keeps the box open, unless Shift picks the alt.
	local keep = IsShiftKeyDown() and not entry.alt
	if not keep then ns.close() end
	local plan = ns.plan(useAlt and entry.alt or entry)
	if plan and plan.after then
		local ok, err = pcall(plan.after)
		if not ok then ns.log("run failed", entry.key, err) end
	end
	if keep and box:IsShown() then refresh() end
end

run:HookScript("OnClick", function(_, mouseButton, down)
	if not down then ns.activate(session:selectedEntry(), mouseButton == "RightButton") end
end)
run:SetScript("OnDragStart", function()
	local entry = session:selectedEntry()
	if entry and entry.drag then
		ns.close()
		entry.drag()
	end
end)

box:SetScript("OnChar", function(_, char)
	session:type(char)
	refresh()
end)

box:SetScript("OnKeyDown", function(self, key)
	local propagate = false
	if key == "ENTER" then
		local entry = session:selectedEntry()
		local useAlt = IsShiftKeyDown() and armedAlt ~= nil
		local plan = useAlt and armedAlt or armed
		if entry and plan and plan.enter == "binding" then
			propagate = true -- the override binding runs the command
			C_Timer.After(0, function() ns.activate(entry, useAlt) end)
		elseif entry and plan and plan.enter == "click" then
			propagate = true -- the override binding clicks LookupRun
		else
			ns.activate(entry, useAlt)
		end
	elseif key == "ESCAPE" then
		ns.close()
	elseif key == "BACKSPACE" then
		session:backspace(IsControlKeyDown())
		refresh()
	elseif key == "UP" then
		ns.select(session.selected - 1)
	elseif key == "DOWN" or key == "TAB" then
		ns.select(session.selected + 1)
	elseif key == "SPACE" and IsShiftKeyDown() then
		ns.close() -- the open binding also closes
	elseif key == "PRINTSCREEN" then
		propagate = true
	end
	self:SetPropagateKeyboardInput(propagate)
end)

box:SetScript("OnHide", disarm)
-- Fires just before lockdown starts, while hiding is still allowed.
box:RegisterEvent("PLAYER_REGEN_DISABLED")
box:SetScript("OnEvent", ns.close)

function ns.toggle()
	if box:IsShown() then
		ns.close()
		return
	end
	if inCombat() then
		UIErrorsFrame:AddMessage("Lookup: not available in combat", 1, 0.3, 0.3)
		return
	end
	local start = debugprofilestop()
	local entries = ns.collect()
	ns.log("index", #entries, "entries in", math.floor(debugprofilestop() - start), "ms")
	session = session or ns.newSession(LookupDB, time)
	session:open(entries)
	box:Show()
	refresh()
end
