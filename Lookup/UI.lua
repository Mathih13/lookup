-- The search box, drawn with stock Blizzard art (mock v12). See docs/design.md "Look" and "Panel-opening architecture".
--
-- The box is a keyboard-enabled frame with no EditBox: OnChar adds text, and only
-- Enter propagates, to an override binding on one secure button (LookupRun).
-- LookupRun sits over the selected row (at screen coordinates, never anchored to
-- it) and holds that row's secure action. The box closes when combat starts and
-- does not open in combat, because LookupRun cannot move or change then.
local _, ns = ...

local MAX_ROWS, RECENT_ROWS = 8, 5
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

local recentLabel = text(box, 12, 0.6, 0.6, 0.6)
recentLabel:SetPoint("TOPLEFT", field, "BOTTOMLEFT", NAME_X, -2)
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
local armedCommand -- the binding command Enter runs, if any

local query, results, selected, rows = "", {}, 1, {}
local entries -- built on open
-- Command mode: a query that starts with "/" lists only commands. Space on a command makes it
-- the token, and the query becomes its argument text.
local token

local function inCombat() return InCombatLockdown() end

local function value(entry)
	local v = entry.value
	if type(v) == "function" then v = v() end
	if v == nil and entry.binding then
		local key = GetBindingKey(entry.binding)
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

local function setRow(row, entry)
	row.entry = entry
	setIcon(row, entry)
	row.name:SetText(query ~= "" and ns.highlight(entry.name, entry.hl, GOLD) or entry.name:gsub("|", "||"))
	row.sub:SetText(entry.cat .. (entry.sub and " · " .. entry.sub or ""))
	local checked = entry.check and entry.check()
	row.checkbox:SetShown(entry.check ~= nil)
	row.checkmark:SetShown(checked or false)
	row.value:SetText(not entry.check and value(entry) or "")
	row:Show()
end

local function setStatus(entry)
	if not entry then
		statusLeft:SetText(query ~= "" and "No matches" or "")
		statusRight:SetText("")
		return
	end
	local action = entry.action
	if type(action) == "function" then action = action() end
	statusLeft:SetText(WHITE .. "Enter:|r " .. (action or "Open"))
	if entry.drag then
		statusRight:SetText(WHITE .. "Drag:|r " .. (entry.dragHint or "to your bars"))
	elseif entry.check then
		statusRight:SetText(WHITE .. "Shift-Enter:|r keep open")
	elseif entry.slash and not token and query:sub(1, 1) == "/" then
		statusRight:SetText(WHITE .. "Space:|r add text")
	elseif token and query == "" then
		statusRight:SetText(WHITE .. "Backspace:|r back to commands")
	else
		statusRight:SetText("")
	end
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
	local row = rows[selected]
	local entry = row and row:IsShown() and row.entry
	if not entry then
		run:Hide()
		ClearOverrideBindings(bindOwner)
		return
	end
	local secure = entry.secure or {}
	local macrotext = secure.macrotext
	local tabButton = entry.tab and entry.tab()
	armedCommand = entry.command
	if tabButton and macrotext then
		tab:SetAttribute("clickbutton", tabButton)
		-- Skip the toggle when the panel is already open, or it would close it.
		if tabButton:IsVisible() then macrotext = "" end
		macrotext = macrotext .. "\n/click LookupTab"
		armedCommand = nil
	end
	run:SetAttribute("type", secure.type)
	run:SetAttribute("macrotext", macrotext)
	run:SetAttribute("clickbutton", secure.clickbutton and _G[secure.clickbutton])
	-- Screen coordinates, no anchor to the row: an anchor would make the box protected.
	run:ClearAllPoints()
	run:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", row:GetLeft(), row:GetTop())
	run:SetSize(row:GetWidth(), row:GetHeight())
	run:SetFrameLevel(row:GetFrameLevel() + 10)
	run:Show()
	for _, key in ipairs({ "ENTER", "SHIFT-ENTER" }) do
		if armedCommand then
			SetOverrideBinding(bindOwner, true, key, armedCommand) -- Blizzard's binding runs it securely
		else
			SetOverrideBindingClick(bindOwner, true, key, "LookupRun", "LeftButton")
		end
	end
end

local function disarm()
	if inCombat() then return end
	ClearOverrideBindings(bindOwner)
	run:ClearAllPoints()
	run:Hide()
end

function ns.select(i)
	if i < 1 or i > #results then return end
	selected = i
	for j, row in ipairs(rows) do
		local on = j == i and row:IsShown()
		row.highlight:SetShown(on)
	end
	setStatus(results[i])
	arm()
end

-- A calculator row for arithmetic queries. Enter puts the result in the box.
local function calcEntry()
	local v = ns.calc(query)
	if not v then return nil end
	return { name = ns.formatNumber(v), cat = "Calculator", sub = query:gsub("|", "||"), rank = 0,
		icon = "Interface/Icons/INV_Misc_Note_01", calc = true, action = "Use the result" }
end

-- A row that runs the token's command with this argument text ("" runs it bare).
local function argEntry(arg, cat)
	local line = arg == "" and token.slash or token.slash .. " " .. arg
	return { name = cat == "Recent" and arg or line, cat = cat, rank = 0, key = arg, argOf = token,
		icon = token.icon, atlas = token.atlas, action = "Run " .. line, secure = { type = "macro", macrotext = line } }
end

local function argRows()
	local history = LookupDB.args[token.slash] or {}
	local list = {}
	for arg in pairs(history) do list[#list + 1] = argEntry(arg, "Recent") end
	local out = query == "" and ns.recent(list, history, MAX_ROWS - 1)
		or ns.rank(list, query, history, time(), MAX_ROWS - 1)
	if not (out[1] and out[1].name == query) then out[#out + 1] = argEntry(query, "As typed") end
	return out
end

local function commandRows()
	local list = {}
	for _, e in ipairs(entries) do
		if e.slash then list[#list + 1] = e end
	end
	local out, total
	if query == "/" then
		-- Nothing to match yet: most used first, then addon commands, then by name.
		local history, now = LookupDB.history, time()
		table.sort(list, function(a, b)
			local ba, bb = ns.boost(history[a.key], now), ns.boost(history[b.key], now)
			if ba ~= bb then return ba > bb end
			if (a.addon ~= nil) ~= (b.addon ~= nil) then return a.addon ~= nil end
			return a.name < b.name
		end)
		out, total = {}, #list
		for i = 1, math.min(MAX_ROWS, #list) do
			list[i].hl = nil
			out[i] = list[i]
		end
		return out, total
	end
	out, total = ns.rank(list, query, LookupDB.history, time(), MAX_ROWS)
	-- An exact alias ("/atr", "/w") goes first.
	local typed = query:lower()
	for _, e in ipairs(list) do
		for _, alias in ipairs(e.aliases) do
			if alias:lower() == typed then
				for i = #out, 1, -1 do
					if out[i] == e then table.remove(out, i) end
				end
				e.hl = nil
				table.insert(out, 1, e)
				out[MAX_ROWS + 1] = nil
			end
		end
	end
	-- Commands Lookup does not list, or a command with its text typed in, still run as typed.
	if #out == 0 or query:find(" ") then
		table.insert(out, math.min(#out + 1, MAX_ROWS), { name = query, cat = "As typed", rank = 0, key = "typed",
			icon = "Interface/Icons/UI_Chat", action = "Run " .. query, secure = { type = "macro", macrotext = query } })
		out[MAX_ROWS + 1] = nil
	end
	return out, total
end

local function refresh()
	local shown = query:gsub("|", "||")
	if token then shown = "|cff9a9a9a" .. token.slash .. "|r " .. shown end
	input:SetText(shown)
	local width = input:GetStringWidth()
	local hint = token and query == "" and "Type text or pick"
		or not token and query == "/" and "Type a command"
		or query == "" and "Search spells, quests, zones, settings..."
	placeholder:SetText(hint or "")
	placeholder:SetShown(hint ~= false)
	placeholder:ClearAllPoints()
	placeholder:SetPoint("LEFT", input, "LEFT", width > 0 and width + 4 or 2, 0)
	caret:SetPoint("LEFT", input, "LEFT", width + 1, 0)
	local total
	if token then
		results = argRows()
	elseif query:sub(1, 1) == "/" then
		results, total = commandRows()
	elseif query == "" then
		results = ns.recent(entries, LookupDB.history, RECENT_ROWS)
	else
		results, total = ns.rank(entries, query, LookupDB.history, time(), MAX_ROWS)
		local calc = calcEntry()
		if calc then
			table.insert(results, 1, calc)
			results[MAX_ROWS + 1] = nil
		end
	end
	count:SetText(total and total > #results and (#results .. " of " .. total) or "")
	local header = query == "" and not token and #results > 0
	recentLabel:SetShown(header)
	local top = ROWS_TOP + (header and HEADER_H or 0)
	selected = math.min(selected, math.max(#results, 1))
	for i, row in ipairs(rows) do
		if results[i] then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", GUTTER, -top - (i - 1) * (ROW_H + ROW_GAP))
			row:SetPoint("TOPRIGHT", -GUTTER, -top - (i - 1) * (ROW_H + ROW_GAP))
			setRow(row, results[i])
		else
			row:Hide()
		end
	end
	local showStatus = #results > 0 or query ~= ""
	status:SetShown(showStatus)
	local rowsH = #results > 0 and #results * (ROW_H + ROW_GAP) - ROW_GAP or 0
	box:SetHeight(showStatus and top + rowsH + 6 + STATUS_H + BOTTOM or TOP + SEARCH_H + TOP)
	ns.select(selected)
	if #results == 0 then
		setStatus(nil)
		arm()
	end
end

function ns.close()
	disarm()
	box:Hide()
end

---Record the pick, close, then run the entry's plain code. Called after the secure
---part (LookupRun click or binding command), or alone when there is none.
function ns.activate(entry)
	if not entry then return end
	if entry.calc then
		query, selected = entry.name, 1
		refresh()
		return
	end
	if entry.argOf then
		local command = entry.argOf.slash
		ns.remember(LookupDB.history, entry.argOf.key, time())
		if entry.cat == "Recent" or (entry.key ~= "" and entry.cat == "As typed") then
			-- ponytail: argument history grows without a cap; trim it if it ever gets long.
			LookupDB.args[command] = LookupDB.args[command] or {}
			ns.remember(LookupDB.args[command], entry.key, time())
		end
	elseif entry.key ~= "typed" then
		ns.remember(LookupDB.history, entry.key, time())
	end
	ns.log("activate", entry.key)
	local keep = IsShiftKeyDown()
	if not keep then ns.close() end
	if entry.run then
		local ok, err = pcall(entry.run)
		if not ok then ns.log("run failed", entry.key, err) end
	end
	if keep and box:IsShown() then refresh() end
end

run:HookScript("OnClick", function(_, _, down)
	if not down then ns.activate(rows[selected] and rows[selected].entry) end
end)
run:SetScript("OnDragStart", function()
	local entry = rows[selected] and rows[selected].entry
	if entry and entry.drag then
		ns.close()
		entry.drag()
	end
end)

box:SetScript("OnChar", function(_, char)
	if query == "" and char == " " then return end -- the Shift+Space that opened the box
	-- Space after a command name makes it the token (command mode).
	local picked = results[selected]
	if char == " " and not token and query:sub(1, 1) == "/" and not query:find(" ") and picked and picked.slash then
		token, query, selected = picked, "", 1
		refresh()
		return
	end
	query = query .. char
	selected = 1
	refresh()
end)

box:SetScript("OnKeyDown", function(self, key)
	local propagate = false
	if key == "ENTER" then
		local entry = rows[selected] and rows[selected].entry
		if entry and armedCommand then
			propagate = true -- the override binding runs the command
			C_Timer.After(0, function() ns.activate(entry) end)
		elseif entry and entry.secure then
			propagate = true -- the override binding clicks LookupRun
		else
			ns.activate(entry)
		end
	elseif key == "ESCAPE" then
		ns.close()
	elseif key == "BACKSPACE" then
		if token and query == "" then
			query, token = token.slash, nil -- back to the command, to edit it
		elseif IsControlKeyDown() then
			query = query:gsub("%S*%s*$", "")
		else
			query = query:gsub("[\128-\191]*.$", "") -- one UTF-8 character
		end
		selected = 1
		refresh()
	elseif key == "UP" then
		ns.select(selected - 1)
	elseif key == "DOWN" or key == "TAB" then
		ns.select(selected + 1)
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
	entries = ns.collect()
	ns.log("index", #entries, "entries in", math.floor(debugprofilestop() - start), "ms")
	query, selected, token = "", 1, nil
	box:Show()
	refresh()
end
