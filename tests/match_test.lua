local ns = {}
assert(loadfile("Lookup/Match.lua"))("Lookup", ns)

assert(ns.normalize("Damage Me-") == "damage me", ns.normalize("Damage Me-"))
assert(ns.normalize("Ahn'Qiraj") == "ahnqiraj")
assert(ns.normalize("Kel\226\128\153Thuzad") == "kelthuzad")
assert(ns.normalize("Zul'Gurub Caf\195\169 \195\133land") == "zulgurub cafe aland", ns.normalize("Zul'Gurub Caf\195\169 \195\133land"))

local function e(name, rank, key) return { name = name, rank = rank or 1, key = key or name } end
local entries = {
	e("Damage Meter", 2), e("Currency", 1), e("Ashenvale", 3), e("Quests in Ashenvale (3)", 4),
	e("Blackfathom Deeps", 3), e("Reputation", 1), e("Mage Armor", 6), e("Dungeon Finder", 1),
}
local function names(list)
	local t = {}
	for i, x in ipairs(list) do t[i] = x.name end
	return table.concat(t, ",")
end
local now = 1000000

-- word prefix
assert(ns.rank(entries, "Damage me-", {}, now, 8)[1].name == "Damage Meter")
assert(ns.rank(entries, "curr", {}, now, 8)[1].name == "Currency")
assert(names(ns.rank(entries, "ashen", {}, now, 8)) == "Ashenvale,Quests in Ashenvale (3)", names(ns.rank(entries, "ashen", {}, now, 8)))
-- initials, alias
assert(ns.rank(entries, "bd", {}, now, 8)[1].name == "Blackfathom Deeps")
assert(ns.rank(entries, "rep", {}, now, 8)[1].name == "Reputation")
assert(ns.rank(entries, "lfg", {}, now, 8)[1].name == "Dungeon Finder")
-- fuzzy ranks below prefix: "ma" prefixes Mage Armor and Meter's second word? "meter" no; fuzzy hits Damage
local r = ns.rank(entries, "ma", {}, now, 8)
assert(r[1].name == "Mage Armor", names(r))
-- empty query matches nothing; no match
assert(#ns.rank(entries, "", {}, now, 8) == 0)
assert(#ns.rank(entries, "zzz", {}, now, 8) == 0)
-- limit, and the full match count
local cut, total = ns.rank(entries, "a", {}, now, 2)
assert(#cut == 2 and total > 2, total)

-- highlight: matched parts of the original name, in a colour code
local function hl(q, name)
	local _, ranges = ns.score(ns.normalize(q), (ns.normalize(name)))
	return ns.highlight(name, ranges, "<")
end
assert(hl("seal", "Seal of Light") == "<Seal|r of Light", hl("seal", "Seal of Light"))
assert(hl("bd", "Blackfathom Deeps") == "<B|rlackfathom <D|reeps")
assert(hl("ahnq", "Ahn'Qiraj") == "<Ahn|r'<Q|riraj", hl("ahnq", "Ahn'Qiraj"))
assert(hl("cafe", "Caf\195\169") == "<Caf\195\169|r")
assert(hl("dmg", "Damage Meter") == "<Damage|r Meter") -- alias
assert(ns.highlight("a|b", nil, "<") == "a||b")

-- history lifts a fuzzy hit within its tier, never above a prefix hit
local hist = {}
for _ = 1, 10 do ns.remember(hist, "Damage Meter", now) end
r = ns.rank(entries, "ma", hist, now, 8)
assert(r[1].name == "Mage Armor" and r[2].name == "Damage Meter", names(r))
-- recent
ns.remember(hist, "Currency", now + 5)
ns.remember(hist, "Gone", now + 9)
assert(names(ns.recent(entries, hist, 5)) == "Currency,Damage Meter")
assert(ns.boost(hist["Currency"], now + 5) > ns.boost(hist["Currency"], now + 5 + 30 * 86400))

-- calculator
local function calc(q) local v = ns.calc(q) return v and ns.formatNumber(v) end
assert(calc("1+10") == "11")
assert(calc(" 2 * (3 + 4) ") == "14")
assert(calc("2^3^2") == "512") -- right associative
assert(calc("-3 + 5") == "2")
assert(calc("10 / 4") == "2.5")
assert(calc("1/3") == "0.3333333333", calc("1/3"))
assert(calc("10 % 3") == "1")
assert(calc("3x4") == "12")
assert(calc(".5*4") == "2")
assert(calc("12") == nil) -- a number alone is not a sum
assert(calc("1/0") == nil and calc("(1+2") == nil and calc("1++") == nil and calc("1..2+1") == nil)
assert(calc("seal") == nil and calc("rank 2") == nil and calc("os.exit()") == nil)
print("ok")
