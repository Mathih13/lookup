-- Matching and ranking. Pure logic: tested in tests/match_test.lua.
local _, ns = ...

-- Latin-1 letters (UTF-8 lead byte 0xC3) to plain ASCII, indexed by the second byte - 0x7F.
local ACCENTS = "AAAAAAACEEEEIIIIDNOOOOOxOUUUUYTsaaaaaaaceeeeiiiidnooooo/ouuuuyty"

local function unaccent(b)
	return ACCENTS:sub(b:byte() - 0x7F, b:byte() - 0x7F)
end

---Lower case, no accents or apostrophes, other punctuation as one space.
---Also returns, per normalized character, its first and last byte in `s` (for highlights).
---@param s string
---@return string norm, integer[] starts, integer[] ends
function ns.normalize(s)
	local out, starts, ends = {}, {}, {}
	local space = false
	local i, n = 1, #s
	while i <= n do
		local b = s:byte(i)
		local len = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
		local ch = s:sub(i, i + len - 1)
		local c
		if ch == "'" or ch == "\226\128\153" then
			c = ""
		elseif b == 0xC3 and #ch == 2 then
			c = unaccent(ch:sub(2)):lower()
		else
			c = ch:lower()
		end
		if c ~= "" and not c:match("^%w$") then
			space = #out > 0
		elseif c ~= "" then
			if space then out[#out + 1], space = " ", false end
			out[#out + 1] = c
			starts[#out], ends[#out] = i, i + len - 1
		end
		i = i + len
	end
	return table.concat(out), starts, ends
end

-- Words of a normalized string, with their start positions.
local function words(s)
	local t = {}
	for at, w in s:gmatch("()(%S+)") do t[#t + 1] = { w = w, at = at } end
	return t
end

-- Short English aliases. A query word that equals a key also matches as the value.
ns.ALIASES = {
	rep = "reputation", dmg = "damage", lfg = "dungeon finder", lfd = "dungeon finder",
	ach = "achievements", spec = "specialization", keybind = "key bindings",
	keybinds = "key bindings", binds = "key bindings", opt = "options", options = "settings",
	gfx = "graphics", sfx = "sound", fps = "framerate", gold = "currency",
}

-- Each tier beats every score of the tier below it.
local PREFIX, INITIALS, FUZZY = 3000, 2000, 1000

-- Each scorer returns a score and the matched ranges {from, to} in the normalized name.

---Every query word is a prefix of a different name word.
local function prefixScore(qWords, nWords)
	local used, firstAt, hl = {}, nil, {}
	for _, q in ipairs(qWords) do
		local found
		for i, n in ipairs(nWords) do
			if not used[i] and n.w:sub(1, #q.w) == q.w then found = i break end
		end
		if not found then return nil end
		used[found] = true
		firstAt = firstAt or found
		hl[#hl + 1] = { nWords[found].at, nWords[found].at + #q.w - 1 }
	end
	return PREFIX - firstAt * 10, hl
end

local function initialsScore(q, nWords)
	if #q < 2 or #nWords < 2 then return nil end
	local initials = {}
	for i, n in ipairs(nWords) do initials[i] = n.w:sub(1, 1) end
	if table.concat(initials):sub(1, #q) ~= q then return nil end
	local hl = {}
	for i = 1, #q do hl[i] = { nWords[i].at, nWords[i].at } end
	return INITIALS, hl
end

---Query letters appear in order. Tighter matches score higher.
local function fuzzyScore(q, name)
	local pos, first, last, hl = 0, nil, nil, {}
	for i = 1, #q do
		local c = q:sub(i, i)
		if c ~= " " then
			pos = name:find(c, pos + 1, true)
			if not pos then return nil end
			first = first or pos
			last = pos
			hl[#hl + 1] = { pos, pos }
		end
	end
	if not first then return nil end
	return FUZZY - (last - first) - first, hl
end

local function scoreNormalized(q, name)
	local qWords, nWords = words(q), words(name)
	local s, hl = prefixScore(qWords, nWords)
	if not s then s, hl = initialsScore((q:gsub(" ", "")), nWords) end
	if not s then s, hl = fuzzyScore(q, name) end
	if not s then return nil end
	return s - #name, hl -- shorter names first
end

---Score a normalized query against a normalized name. Higher is better; nil means no match.
---@param q string
---@param name string
---@return number? score, table? ranges matched ranges in the name
function ns.score(q, name)
	local best, bestHl = scoreNormalized(q, name)
	local expanded = q:gsub("%S+", ns.ALIASES)
	if expanded ~= q then
		local s, hl = scoreNormalized(expanded, name)
		if s and (not best or s > best) then best, bestHl = s, hl end
	end
	return best, bestHl
end

---Wrap the matched parts of `name` in a colour code. `|` in the name is escaped.
---@param name string
---@param ranges table? from ns.score
---@param color string for example "|cffffd100"
function ns.highlight(name, ranges, color)
	local on = {}
	if ranges then
		local _, starts, ends = ns.normalize(name)
		for _, r in ipairs(ranges) do
			for k = r[1], r[2] do
				for b = starts[k] or 1, ends[k] or 0 do on[b] = true end
			end
		end
	end
	local out, inside = {}, false
	for b = 1, #name do
		if (on[b] or false) ~= inside then
			inside = not inside
			out[#out + 1] = inside and color or "|r"
		end
		local ch = name:sub(b, b)
		out[#out + 1] = ch == "|" and "||" or ch
	end
	if inside then out[#out + 1] = "|r" end
	return table.concat(out)
end

-- Calculator ---------------------------------------------------------------------

-- Recursive descent over tokens: expr = term {+|- term}; term = unary {*|/|% unary};
-- unary = (-|+) unary | power; power = atom [^ unary]; atom = number | ( expr ).
local function parse(tokens)
	local i = 1
	local function peek() return tokens[i] end
	local function take() i = i + 1 return tokens[i - 1] end
	local expr
	local function atom()
		local t = take()
		if type(t) == "number" then return t end
		if t == "(" then
			local v = expr()
			if take() ~= ")" then error() end
			return v
		end
		error()
	end
	local unary
	local function power()
		local v = atom()
		if peek() == "^" then take() return v ^ unary() end
		return v
	end
	function unary()
		if peek() == "-" then take() return -unary() end
		if peek() == "+" then take() return unary() end
		return power()
	end
	local function term()
		local v = unary()
		while peek() == "*" or peek() == "/" or peek() == "%" do
			local op, r = take(), unary()
			if op == "*" then v = v * r elseif op == "/" then v = v / r else v = v % r end
		end
		return v
	end
	function expr()
		local v = term()
		while peek() == "+" or peek() == "-" do
			if take() == "+" then v = v + term() else v = v - term() end
		end
		return v
	end
	local v = expr()
	if i <= #tokens then error() end
	return v
end

---The value of an arithmetic query such as "1+10" or "(3.5 + 2) * 4", or nil when the
---query is not arithmetic. It needs at least one operator. "x" also multiplies.
---@param s string
---@return number?
function ns.calc(s)
	if s:find("[^%d%.%s%+%-%*/%%%^%(%)xX]") or not s:find("%d") then return nil end
	local tokens, operators = {}, 0
	for num, op in s:gsub("[xX]", "*"):gmatch("%s*(%d*%.?%d*)%s*([%+%-%*/%%%^%(%)]?)") do
		if num ~= "" then
			local n = tonumber(num)
			if not n then return nil end
			tokens[#tokens + 1] = n
		end
		if op ~= "" then
			tokens[#tokens + 1] = op
			if op ~= "(" and op ~= ")" then operators = operators + 1 end
		end
	end
	if operators == 0 then return nil end
	local ok, v = pcall(parse, tokens)
	if not ok or v ~= v or v == math.huge or v == -math.huge then return nil end
	return v
end

---A calculator result as text: whole numbers without decimals, others to 10 digits.
function ns.formatNumber(v)
	if v == math.floor(v) and math.abs(v) < 1e15 then return ("%d"):format(v) end
	return (("%.10g"):format(v))
end

local DAY = 86400

---History boost: frequent and recent picks rank higher, at most 500 (below one tier).
---@param h {count: number, last: number}?
---@param now number
function ns.boost(h, now)
	if not h then return 0 end
	local age = math.max(0, now - h.last) / DAY
	return math.min(h.count, 10) * 50 / (1 + age / 7)
end

---Rank entries for a query. Returns at most `limit` rows ({ entry, hl = matched ranges }),
---and the number of matches. Entries are not changed, apart from a cached `norm`.
---@param entries table[] each has `name`, `rank` (category order), `key` (history id); `norm` is cached here
---@param query string raw text
---@param history table<string, {count: number, last: number}>
---@param now number
---@param limit integer
function ns.rank(entries, query, history, now, limit)
	local q = ns.normalize(query)
	local hits = {}
	for _, e in ipairs(entries) do
		e.norm = e.norm or (ns.normalize(e.name))
		local s, hl
		if q ~= "" then s, hl = ns.score(q, e.norm) end
		if s then
			hits[#hits + 1] = { entry = e, hl = hl, score = s + ns.boost(history[e.key], now) }
		end
	end
	table.sort(hits, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		if a.entry.rank ~= b.entry.rank then return a.entry.rank < b.entry.rank end
		return a.entry.name < b.entry.name
	end)
	local out = {}
	for i = 1, math.min(limit, #hits) do
		out[i] = { entry = hits[i].entry, hl = hits[i].hl }
	end
	return out, #hits
end

---The most recent picks that still exist, newest first.
function ns.recent(entries, history, limit)
	local list = {}
	for _, e in ipairs(entries) do
		if history[e.key] then list[#list + 1] = e end
	end
	table.sort(list, function(a, b) return history[a.key].last > history[b.key].last end)
	for i = #list, limit + 1, -1 do list[i] = nil end
	return list
end

---Record a pick.
function ns.remember(history, key, now)
	local h = history[key] or { count = 0 }
	h.count = h.count + 1
	h.last = now
	history[key] = h
end
