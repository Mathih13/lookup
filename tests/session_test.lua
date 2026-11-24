local ns = dofile("tests/stubs.lua")({ "Lookup/Match.lua", "Lookup/Action.lua", "Lookup/Session.lua" })
local noop = function() end

local t = 1000000
local function now() return t end
local function command(slash, addon, aliases)
	return { name = slash, cat = "Command", rank = 10, key = "slash:" .. slash, slash = slash, addon = addon,
		aliases = aliases or {}, line = slash }
end
local function makeEntries()
	return {
		{ name = "Currency", cat = "Panel", rank = 1, key = "panel:currency", binding = "TOGGLECURRENCY" },
		{ name = "Auto Loot", cat = "Setting", rank = 2, key = "setting:autoLoot",
			toggle = { get = function() return true end, set = noop }, action = function() return "Turn off" end },
		{ name = "Seal of Light", cat = "Spell", rank = 6, key = "spell:Seal of Light", binding = "TOGGLESPELLBOOK",
			drag = noop, dragHint = "Rank 1 to your bars" },
		command("/who"),
		command("/whisper", nil, { "/w" }),
		command("/auctionator", "Auctionator", { "/atr" }),
		command("/atlasloot", "AtlasLoot Forever", { "/al" }),
	}
end
local function fresh(entries)
	entries = entries or makeEntries()
	local db = {}
	local s = ns.newSession(db, now)
	s:open(entries)
	return s, db, entries
end
local function names(view)
	local out = {}
	for i, r in ipairs(view.rows) do out[i] = r.entry.name end
	return table.concat(out, ",")
end
local function typed(s, text)
	for c in text:gmatch(".") do s:type(c) end
end
local function runAsTyped(s, entries, line)
	s:open(entries)
	typed(s, line)
	local rows = s:view().rows
	s:pick(rows[#rows].entry)
end
local function size(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

test("the empty box shows example searches under Try, and the search hint", function()
	local v = fresh():view()
	assert(v.header == "Try" and v.rows[1].entry.name == "map" and v.hint:find("^Search"), names(v))
	assert(v.status.action == "Search for map")
end)

test("picking an example types it into the box and is not remembered", function()
	local s, db = fresh()
	assert(s:pick(s:view().rows[1].entry) == true and s:view().query == "map" and next(db.history) == nil)
end)

test("the / example opens command mode", function()
	local s = fresh()
	s:pick(s:view().rows[4].entry)
	assert(s:view().hint == "Type a command")
end)

test("the space from the key that opened the box is not typed", function()
	local s = fresh()
	s:type(" ")
	assert(s:view().query == "")
end)

test("a search gives ranked rows with matched ranges, and the status line for the selected row", function()
	local s = fresh()
	typed(s, "seal")
	local v = s:view()
	assert(names(v) == "Seal of Light" and v.rows[1].hl and v.hint == nil)
	assert(v.status.action == "Open" and v.status.right[1] == "Drag" and v.status.right[2] == "Rank 1 to your bars")
end)

test("a second action shows instead of the drag hint", function()
	local entries = makeEntries()
	entries[3].alt = { binding = "TOGGLESPELLBOOK", action = "Open spellbook" }
	local s = fresh(entries)
	typed(s, "seal")
	local right = s:view().status.right
	assert(right[1] == "Shift-Enter" and right[2] == "Open spellbook")
end)

test("ranking does not write onto entries", function()
	local s, _, entries = fresh()
	typed(s, "seal")
	s:view()
	assert(entries[3].hl == nil)
end)

test("a toggle row offers Shift-Enter", function()
	local s = fresh()
	typed(s, "auto")
	assert(s:view().status.action == "Turn off" and s:view().status.right[1] == "Shift-Enter")
end)

test("a search with no match says so", function()
	local s = fresh()
	typed(s, "zzz")
	assert(#s:view().rows == 0 and s:view().status.message == "No matches")
end)

test("arithmetic gives a calculator row first, and picking it puts the result in the box", function()
	local s, db = fresh()
	typed(s, "1+10")
	local v = s:view()
	assert(v.rows[1].entry.calc and v.rows[1].entry.name == "11")
	assert(s:pick(v.rows[1].entry) == true and s:view().query == "11")
	assert(next(db.history) == nil)
end)

test("examples stay until three picks, then the empty box shows recent picks, newest first", function()
	local s, _, entries = fresh()
	s:pick(entries[1])
	t = t + 1
	s:pick(entries[3])
	s:open(entries)
	assert(s:view().header == "Try")
	t = t + 1
	s:pick(entries[4])
	s:open(entries)
	local v = s:view()
	assert(v.header == "Recent" and names(v) == "/who,Seal of Light,Currency", names(v))
end)

test("/ lists only commands: most used first, then addon commands, then by name", function()
	local s, _, entries = fresh()
	s:pick(entries[4])
	s:open(entries)
	s:type("/")
	local v = s:view()
	assert(names(v) == "/who,/atlasloot,/auctionator,/whisper", names(v))
	assert(v.hint == "Type a command" and v.header == nil)
	assert(v.status.action == "Run /who" and v.status.right[1] == "Space")
end)

test("a plain search leaves commands out", function()
	local s = fresh()
	typed(s, "who")
	assert(#s:view().rows == 0, names(s:view()))
end)

test("an exact alias goes first", function()
	local s = fresh()
	typed(s, "/w")
	assert(s:view().rows[1].entry.name == "/whisper", names(s:view()))
	s:backspace()
	typed(s, "atr")
	assert(s:view().rows[1].entry.name == "/auctionator", names(s:view()))
end)

test("Space on a command makes it the token, and the argument runs as typed and is remembered", function()
	local s, db = fresh()
	typed(s, "/atr ")
	local v = s:view()
	assert(v.token == "/auctionator" and v.query == "" and v.hint == "Type text or pick")
	assert(names(v) == "/auctionator" and v.rows[1].entry.line == "/auctionator")
	assert(v.status.right[1] == "Backspace")
	typed(s, "post")
	v = s:view()
	assert(names(v) == "/auctionator post" and v.rows[1].entry.cat == "As typed")
	assert(v.status.action == "Run /auctionator post")
	s:pick(v.rows[1].entry)
	assert(db.args["/auctionator"].post.count == 1 and db.history["slash:/auctionator"].count == 1)
end)

test("a used argument comes back as a Recent row and matches as you type", function()
	local s, _, entries = fresh()
	runAsTyped(s, entries, "/atr post")
	s:open(entries)
	typed(s, "/atr ")
	local v = s:view()
	assert(names(v) == "post,/auctionator", names(v))
	assert(v.rows[1].entry.cat == "Recent" and v.rows[1].entry.line == "/auctionator post")
	typed(s, "po")
	v = s:view()
	assert(names(v) == "post,/auctionator po" and v.rows[1].hl, names(v))
end)

test("an exact argument match needs no As typed row", function()
	local s, _, entries = fresh()
	runAsTyped(s, entries, "/atr post")
	s:open(entries)
	typed(s, "/atr post")
	assert(names(s:view()) == "post", names(s:view()))
end)

test("Backspace on an empty argument puts the command back as text", function()
	local s = fresh()
	typed(s, "/atr ")
	s:backspace()
	local v = s:view()
	assert(v.token == nil and v.query == "/auctionator")
end)

test("a line that matches no command runs as typed and is not remembered", function()
	local s, db = fresh()
	typed(s, "/foo bar")
	local v = s:view()
	local row = v.rows[#v.rows].entry
	assert(row.cat == "As typed" and row.line == "/foo bar")
	s:pick(row)
	assert(next(db.history) == nil)
end)

test("a command keeps at most 20 arguments, and the oldest go", function()
	local s, db, entries = fresh()
	for i = 1, 25 do
		t = t + 1
		runAsTyped(s, entries, "/who name" .. i)
	end
	assert(size(db.args["/who"]) == 20 and db.args["/who"].name1 == nil and db.args["/who"].name25)
end)

test("reset forgets entries and arguments", function()
	local s, db, entries = fresh()
	runAsTyped(s, entries, "/atr post")
	ns.forget(db)
	assert(next(db.history) == nil and next(db.args) == nil)
end)

test("more matches than rows shows the count", function()
	local many = {}
	for i = 1, 12 do many[i] = { name = "Item " .. i, cat = "Item", rank = 8, key = "item:" .. i, call = noop } end
	local s = fresh(many)
	typed(s, "item")
	assert(s:view().count == "8 of 12", s:view().count)
end)

test("a line too long to run says so, and picking it stores nothing", function()
	for _, line in ipairs({ "/atr " .. string.rep("a", 260), "/foo " .. string.rep("b", 260) }) do
		local s, db = fresh()
		typed(s, line)
		local v = s:view()
		local row = v.rows[#v.rows].entry
		assert(row.cat == "As typed" and v.rows[v.selected].entry == row, names(v))
		assert(v.status.message == "Too long to run: at most 255 characters", tostring(v.status.message))
		assert(s:pick(row) == true and next(db.history) == nil and next(db.args) == nil)
	end
end)

done()
