local _, ns = ...

local MAX_ROWS, RECENT_ROWS = 8, 5
local MAX_ARGS = 20
local DEFAULT_HINT = "Search spells, quests, zones, settings..."
local LAST_UTF8_CHARACTER = "[\128-\191]*.$"

local EXAMPLES_UNTIL = 3
local EXAMPLES = {
	{ "map", "Panels and the map", "Interface/Icons/INV_Misc_Map_01" },
	{ "mount", "Mounts, pets and toys", "Interface/Icons/Ability_Mount_RidingHorse" },
	{ "auto loot", "Settings that turn on and off", "Interface/Icons/INV_Misc_Gear_01" },
	{ "/", "Slash commands, also from your addons", "Interface/Icons/UI_Chat", "List commands" },
	{ "25*4", "Calculator", "Interface/Icons/INV_Misc_Note_01" },
}

local Session = {}
Session.__index = Session

---@param db table saved data: history (key -> pick) and args (command -> argument -> pick)
---@param now fun(): number the clock, in seconds
function ns.newSession(db, now)
	db.history = db.history or {}
	db.args = db.args or {}
	return setmetatable({ db = db, now = now, entries = {}, searchable = {}, query = "", selected = 1, rows = {} },
		Session)
end

function ns.forget(db)
	db.history = {}
	db.args = {}
end

local function wrap(list)
	local rows = {}
	for i, e in ipairs(list) do rows[i] = { entry = e } end
	return rows
end

local function calcRow(query)
	local v = ns.calc(query)
	if not v then return nil end
	return { entry = { name = ns.formatNumber(v), cat = "Calculator", sub = query:gsub("|", "||"), rank = 0,
		icon = "Interface/Icons/INV_Misc_Note_01", calc = true, action = "Use the result", call = function() end } }
end

local function exampleRows()
	local rows = {}
	for i, x in ipairs(EXAMPLES) do
		rows[i] = { entry = { name = x[1], cat = "Try", sub = x[2], rank = 0, key = "example:" .. x[1], icon = x[3],
			example = x[1], action = x[4] or ("Search for " .. x[1]), call = function() end } }
	end
	return rows
end

function Session:argRow(arg, recent)
	local token = self.token
	local line = arg == "" and token.slash or token.slash .. " " .. arg
	return { entry = { name = recent and arg or line, cat = recent and "Recent" or "As typed", rank = 0, key = arg,
		argOf = token, arg = arg, icon = token.icon, atlas = token.atlas, action = "Run " .. line, line = line } }
end

function Session:argRows()
	local history = self.db.args[self.token.slash] or {}
	local list = {}
	for arg in pairs(history) do list[#list + 1] = self:argRow(arg, true).entry end
	local rows
	if self.query == "" then
		rows = wrap(ns.recent(list, history, MAX_ROWS - 1))
	else
		rows = ns.rank(list, self.query, history, self.now(), MAX_ROWS - 1)
	end
	if not (rows[1] and rows[1].entry.name == self.query) then rows[#rows + 1] = self:argRow(self.query, false) end
	return rows
end

function Session:commandRows()
	local query, history, now = self.query, self.db.history, self.now()
	local list = {}
	for _, e in ipairs(self.entries) do
		if e.slash then list[#list + 1] = e end
	end
	if query == "/" then
		table.sort(list, function(a, b)
			local ba, bb = ns.boost(history[a.key], now), ns.boost(history[b.key], now)
			if ba ~= bb then return ba > bb end
			if (a.addon ~= nil) ~= (b.addon ~= nil) then return a.addon ~= nil end
			return a.name < b.name
		end)
		local rows = {}
		for i = 1, math.min(MAX_ROWS, #list) do rows[i] = { entry = list[i] } end
		return rows, #list
	end
	local rows, total = ns.rank(list, query, history, now, MAX_ROWS)
	local typed = query:lower()
	for _, e in ipairs(list) do
		local isAlias = false
		for _, alias in ipairs(e.aliases or {}) do
			if alias:lower() == typed then isAlias = true end
		end
		if isAlias then
			for i = #rows, 1, -1 do
				if rows[i].entry == e then table.remove(rows, i) end
			end
			table.insert(rows, 1, { entry = e })
			rows[MAX_ROWS + 1] = nil
			break
		end
	end
	if #rows == 0 or query:find(" ") then
		table.insert(rows, math.min(#rows + 1, MAX_ROWS), { entry = { name = query, cat = "As typed", rank = 0,
			key = "typed", noRecord = true, icon = "Interface/Icons/UI_Chat", action = "Run " .. query, line = query } })
		rows[MAX_ROWS + 1] = nil
	end
	return rows, total
end

function Session:update()
	local query, total = self.query, nil
	self.header = nil
	if self.token then
		self.rows = self:argRows()
	elseif query:sub(1, 1) == "/" then
		self.rows, total = self:commandRows()
	elseif query == "" then
		local picks = 0
		for _ in pairs(self.db.history) do picks = picks + 1 end
		if picks < EXAMPLES_UNTIL then
			self.rows, self.header = exampleRows(), "Try"
		else
			self.rows = wrap(ns.recent(self.entries, self.db.history, RECENT_ROWS))
			self.header = #self.rows > 0 and "Recent" or nil
		end
	else
		self.rows, total = ns.rank(self.searchable, query, self.db.history, self.now(), MAX_ROWS)
		local calc = calcRow(query)
		if calc then
			table.insert(self.rows, 1, calc)
			self.rows[MAX_ROWS + 1] = nil
		end
	end
	self.total = total
	self.selected = math.max(1, math.min(self.selected, #self.rows))
end

function Session:open(entries)
	self.entries, self.query, self.token, self.selected = entries, "", nil, 1
	self.searchable = {}
	for _, e in ipairs(entries) do
		if not e.slash then self.searchable[#self.searchable + 1] = e end
	end
	self:update()
end

function Session:type(char)
	if self.query == "" and char == " " then return end
	local picked = self:selectedEntry()
	if char == " " and not self.token and self.query:sub(1, 1) == "/" and not self.query:find(" ")
		and picked and picked.slash then
		self.token, self.query = picked, ""
	else
		self.query = self.query .. char
	end
	self.selected = 1
	self:update()
end

function Session:backspace(word)
	if self.token and self.query == "" then
		self.query, self.token = self.token.slash, nil
	elseif word then
		self.query = self.query:gsub("%S*%s*$", "")
	else
		self.query = self.query:gsub(LAST_UTF8_CHARACTER, "")
	end
	self.selected = 1
	self:update()
end

function Session:select(i)
	if i >= 1 and i <= #self.rows then self.selected = i end
end

function Session:selectedEntry()
	local row = self.rows[self.selected]
	return row and row.entry
end

function Session:pick(entry)
	if entry.calc or entry.example then
		self.query, self.selected = entry.example or entry.name, 1
		self:update()
		return true
	end
	local now = self.now()
	if entry.argOf then
		ns.remember(self.db.history, entry.argOf.key, now)
		if entry.arg ~= "" then
			local command = entry.argOf.slash
			local args = self.db.args[command] or {}
			self.db.args[command] = args
			ns.remember(args, entry.arg, now)
			local list = {}
			for arg, h in pairs(args) do list[#list + 1] = { arg = arg, last = h.last } end
			table.sort(list, function(a, b) return a.last > b.last end)
			for i = MAX_ARGS + 1, #list do args[list[i].arg] = nil end
		end
	elseif not entry.noRecord then
		ns.remember(self.db.history, entry.key, now)
	end
	return false
end

function Session:view()
	local query, token = self.query, self.token
	local hint = token and query == "" and "Type text or pick"
		or not token and query == "/" and "Type a command"
		or query == "" and DEFAULT_HINT or nil
	local entry = self:selectedEntry()
	local status
	if entry then
		local action = entry.action
		if type(action) == "function" then action = action() end
		status = { action = action or entry.line and "Run " .. entry.line or "Open" }
		if entry.alt then
			status.right = { "Shift-Enter", entry.alt.action or "Open" }
		elseif entry.drag then
			status.right = { "Drag", entry.dragHint or "to your bars" }
		elseif entry.toggle then
			status.right = { "Shift-Enter", "keep open" }
		elseif entry.slash and not token and query:sub(1, 1) == "/" then
			status.right = { "Space", "add text" }
		elseif token and query == "" then
			status.right = { "Backspace", "back to commands" }
		end
	else
		status = { message = query ~= "" and "No matches" or "" }
	end
	return {
		token = token and token.slash, query = query, hint = hint,
		count = self.total and self.total > #self.rows and (#self.rows .. " of " .. self.total) or "",
		header = self.header,
		rows = self.rows, selected = self.selected, status = status,
	}
end
