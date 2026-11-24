-- The Query session against docs/design.md "Command mode", "Calculator" and "Pick memory".
local load = dofile("tests/stubs.lua")
local ns = load({ "Lookup/Match.lua", "Lookup/Session.lua" })
local noop = function() end

local t = 1000000
local function now() return t end
local function command(slash, addon, aliases)
	return { name = slash, cat = "Command", rank = 10, key = "slash:" .. slash, slash = slash, addon = addon,
		aliases = aliases or {}, line = slash }
end
local entries = {
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
local function names(view)
	local out = {}
	for i, r in ipairs(view.rows) do out[i] = r.entry.name end
	return table.concat(out, ",")
end
local function typed(s, text)
	for c in text:gmatch(".") do s:type(c) end
end

local db = {}
local s = ns.newSession(db, now)
s:open(entries)

-- Empty box, nothing picked yet: example searches under "Try", and the search hint.
local v = s:view()
assert(v.header == "Try" and v.rows[1].entry.name == "map" and v.hint:find("^Search"), names(v))
assert(v.status.action == "Search for map")
-- Picking an example types it into the box, and is not a pick to remember.
assert(s:pick(v.rows[1].entry) == true and s:view().query == "map" and next(db.history) == nil)
s:open(entries)
-- The "/" example opens command mode.
s:pick(s:view().rows[4].entry)
assert(s:view().hint == "Type a command")
s:open(entries)
-- The Shift+Space that opened the box is not typed.
s:type(" ")
assert(s:view().query == "")

-- Search: ranked rows with matched ranges, and the status line for the selected row.
typed(s, "seal")
v = s:view()
assert(names(v) == "Seal of Light" and v.rows[1].hl and v.hint == nil)
assert(v.status.action == "Open" and v.status.right[1] == "Drag" and v.status.right[2] == "Rank 1 to your bars")
-- A second action shows instead of the drag hint.
entries[3].alt = { binding = "TOGGLESPELLBOOK", action = "Open spellbook" }
assert(s:view().status.right[1] == "Shift-Enter" and s:view().status.right[2] == "Open spellbook")
entries[3].alt = nil
-- Ranking does not write onto entries.
assert(entries[3].hl == nil)
s:backspace(true)
typed(s, "auto")
assert(s:view().status.action == "Turn off" and s:view().status.right[1] == "Shift-Enter")
s:backspace(true)
typed(s, "zzz")
assert(#s:view().rows == 0 and s:view().status.message == "No matches")
s:backspace(true)

-- Calculator: first row, and picking it puts the result in the box.
typed(s, "1+10")
v = s:view()
assert(v.rows[1].entry.calc and v.rows[1].entry.name == "11")
assert(s:pick(v.rows[1].entry) == true and s:view().query == "11")
assert(next(db.history) == nil) -- not a pick to remember

-- After three picks, the empty box shows recent picks, newest first.
s:open(entries)
s:pick(entries[1])
t = t + 1
s:pick(entries[3])
s:open(entries)
assert(s:view().header == "Try") -- two picks: still examples
t = t + 1
s:pick(entries[4])
s:open(entries)
v = s:view()
assert(v.header == "Recent" and names(v) == "/who,Seal of Light,Currency", names(v))

-- Command mode: "/" lists only commands, most used first, then addon commands, then by name.
ns.forget(db)
s:open(entries)
s:pick(entries[4]) -- /who
s:open(entries)
s:type("/")
v = s:view()
assert(names(v) == "/who,/atlasloot,/auctionator,/whisper", names(v))
assert(v.hint == "Type a command" and v.header == nil)
assert(v.status.action == "Run /who" and v.status.right[1] == "Space")

-- A plain search leaves commands out: they show only in command mode.
s:open(entries)
typed(s, "who")
assert(#s:view().rows == 0, names(s:view()))

-- An exact alias goes first.
s:open(entries)
typed(s, "/w")
assert(s:view().rows[1].entry.name == "/whisper", names(s:view()))
s:backspace()
typed(s, "atr")
assert(s:view().rows[1].entry.name == "/auctionator", names(s:view()))

-- Space on a command makes it the token; the rows are its arguments, then the line as typed.
s:type(" ")
v = s:view()
assert(v.token == "/auctionator" and v.query == "" and v.hint == "Type text or pick")
assert(names(v) == "/auctionator" and v.rows[1].entry.line == "/auctionator")
assert(v.status.right[1] == "Backspace")
typed(s, "post")
v = s:view()
assert(names(v) == "/auctionator post" and v.rows[1].entry.cat == "As typed")
assert(v.status.action == "Run /auctionator post")
s:pick(v.rows[1].entry)
assert(db.args["/auctionator"].post.count == 1 and db.history["slash:/auctionator"].count == 1)

-- Next time the argument is a Recent row, and matches as you type.
s:open(entries)
typed(s, "/atr ")
v = s:view()
assert(names(v) == "post,/auctionator", names(v))
assert(v.rows[1].entry.cat == "Recent" and v.rows[1].entry.line == "/auctionator post")
typed(s, "po")
v = s:view()
assert(names(v) == "post,/auctionator po" and v.rows[1].hl, names(v))
-- An exact match needs no "as typed" row.
typed(s, "st")
assert(names(s:view()) == "post", names(s:view()))

-- Backspace on an empty argument puts the command back as text.
for _ = 1, 4 do s:backspace() end
s:backspace()
v = s:view()
assert(v.token == nil and v.query == "/auctionator")

-- A line that matches no command, or has a space, runs as typed and is not remembered.
s:open(entries)
typed(s, "/foo bar")
v = s:view()
local row = v.rows[#v.rows].entry
assert(row.cat == "As typed" and row.line == "/foo bar")
local before = 0
for _ in pairs(db.history) do before = before + 1 end
s:pick(row)
local after = 0
for _ in pairs(db.history) do after = after + 1 end
assert(before == after)

-- At most 20 arguments per command: the oldest go.
for i = 1, 25 do
	t = t + 1
	s:open(entries)
	typed(s, "/who name" .. i)
	local rows = s:view().rows
	s:pick(rows[#rows].entry) -- the line as typed
end
local n = 0
for _ in pairs(db.args["/who"]) do n = n + 1 end
assert(n == 20 and db.args["/who"].name1 == nil and db.args["/who"].name25)

-- Reset forgets entries and arguments.
ns.forget(db)
assert(next(db.history) == nil and next(db.args) == nil)

-- More matches than rows: the count shows.
local many = {}
for i = 1, 12 do many[i] = { name = "Item " .. i, cat = "Item", rank = 8, key = "item:" .. i, call = noop } end
s:open(many)
typed(s, "item")
assert(s:view().count == "8 of 12", s:view().count)

print("ok")
