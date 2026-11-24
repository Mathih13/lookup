local ns = dofile("tests/stubs.lua")({ "Lookup/Match.lua" })

local function e(name, rank, key) return { name = name, rank = rank or 1, key = key or name } end
local entries = {
	e("Damage Meter", 2), e("Currency", 1), e("Ashenvale", 3), e("Quests in Ashenvale (3)", 4),
	e("Blackfathom Deeps", 3), e("Reputation", 1), e("Mage Armor", 6), e("Dungeon Finder", 1),
}
local function names(list)
	local t = {}
	for i, x in ipairs(list) do t[i] = x.entry and x.entry.name or x.name end
	return table.concat(t, ",")
end
local now = 1000000
local function first(query, history) return ns.rank(entries, query, history or {}, now, 8)[1].entry.name end
local function hl(q, name)
	local _, ranges = ns.score(ns.normalize(q), (ns.normalize(name)))
	return ns.highlight(name, ranges, "<")
end
local function calc(q)
	local v = ns.calc(q)
	return v and ns.formatNumber(v)
end

test("normalizing drops case, accents, apostrophes and other punctuation", function()
	assert(ns.normalize("Damage Me-") == "damage me", ns.normalize("Damage Me-"))
	assert(ns.normalize("Ahn'Qiraj") == "ahnqiraj")
	assert(ns.normalize("Kel\226\128\153Thuzad") == "kelthuzad")
	assert(ns.normalize("Zul'Gurub Caf\195\169 \195\133land") == "zulgurub cafe aland")
end)

test("a word prefix matches", function()
	assert(first("Damage me-") == "Damage Meter")
	assert(first("curr") == "Currency")
	local r = ns.rank(entries, "ashen", {}, now, 8)
	assert(names(r) == "Ashenvale,Quests in Ashenvale (3)", names(r))
end)

test("initials and aliases match", function()
	assert(first("bd") == "Blackfathom Deeps")
	assert(first("rep") == "Reputation")
	assert(first("lfg") == "Dungeon Finder")
end)

test("a prefix match ranks above a fuzzy match", function()
	local r = ns.rank(entries, "ma", {}, now, 8)
	assert(r[1].entry.name == "Mage Armor" and r[2].entry.name == "Damage Meter", names(r))
end)

test("an empty query or no match gives no rows", function()
	assert(#ns.rank(entries, "", {}, now, 8) == 0)
	assert(#ns.rank(entries, "zzz", {}, now, 8) == 0)
end)

test("ranking stops at the limit and counts every match", function()
	local cut, total = ns.rank(entries, "a", {}, now, 2)
	assert(#cut == 2 and total > 2, total)
end)

test("highlight wraps the matched parts of the original name", function()
	assert(hl("seal", "Seal of Light") == "<Seal|r of Light", hl("seal", "Seal of Light"))
	assert(hl("bd", "Blackfathom Deeps") == "<B|rlackfathom <D|reeps")
	assert(hl("ahnq", "Ahn'Qiraj") == "<Ahn|r'<Q|riraj", hl("ahnq", "Ahn'Qiraj"))
	assert(hl("cafe", "Caf\195\169") == "<Caf\195\169|r")
	assert(ns.highlight("a|b", nil, "<") == "a||b")
end)

test("an alias highlights the word it stands for", function()
	assert(hl("dmg", "Damage Meter") == "<Damage|r Meter")
end)

test("history lifts a fuzzy hit within its tier, never above a prefix hit", function()
	local history = {}
	for _ = 1, 10 do ns.remember(history, "Damage Meter", now) end
	local r = ns.rank(entries, "ma", history, now, 8)
	assert(r[1].entry.name == "Mage Armor" and r[2].entry.name == "Damage Meter", names(r))
end)

test("recent picks that still exist come newest first, and old picks weigh less", function()
	local history = {}
	ns.remember(history, "Damage Meter", now)
	ns.remember(history, "Currency", now + 5)
	ns.remember(history, "Gone", now + 9)
	assert(names(ns.recent(entries, history, 5)) == "Currency,Damage Meter")
	assert(ns.boost(history["Currency"], now + 5) > ns.boost(history["Currency"], now + 5 + 30 * 86400))
end)

test("the calculator does arithmetic", function()
	assert(calc("1+10") == "11")
	assert(calc(" 2 * (3 + 4) ") == "14")
	assert(calc("-3 + 5") == "2")
	assert(calc("10 / 4") == "2.5")
	assert(calc("1/3") == "0.3333333333", calc("1/3"))
	assert(calc("10 % 3") == "1")
	assert(calc("3x4") == "12")
	assert(calc(".5*4") == "2")
end)

test("powers are right associative", function()
	assert(calc("2^3^2") == "512")
end)

test("a number alone, a broken sum or text is not arithmetic", function()
	assert(calc("12") == nil)
	assert(calc("1/0") == nil and calc("(1+2") == nil and calc("1++") == nil and calc("1..2+1") == nil)
	assert(calc("seal") == nil and calc("rank 2") == nil and calc("os.exit()") == nil)
end)

done()
