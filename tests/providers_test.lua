local load = dofile("tests/stubs.lua")
local ns = load({ "Lookup/Action.lua", "Lookup/Providers.lua" })
local noop = function() end
local function has(pattern)
	for _, line in ipairs(ns.logged) do
		if line:find(pattern) then return true end
	end
	return false
end

-- Entries get their provider's rank; rows without a readable name are skipped quietly.
ns.provide("panels", 1, function(add)
	add({ name = "Currency", binding = "TOGGLECURRENCY" })
	add({ name = nil, call = noop })
	add({ name = "SECRET", call = noop })
end)
local entries, counts = ns.collect()
assert(#entries == 1 and entries[1].rank == 1 and counts.panels == 1)
assert(#ns.logged == 0, ns.logged[1])

-- One provider failing does not stop the others, and it is off after three failures.
local builds = 0
ns.provide("broken", 2, function(add)
	builds = builds + 1
	add({ name = "Before the error", call = noop })
	error("boom")
end)
ns.provide("people", 3, function(add) add({ name = "Ashkara", call = noop }) end)
for _ = 1, 4 do entries, counts = ns.collect() end
assert(builds == 3, builds)
assert(counts.people == 1 and counts.broken == nil)
assert(has("provider broken failed:.*boom") and has("provider broken off for this session"))

-- Invalid actions are dropped and count as failures.
ns = load({ "Lookup/Action.lua", "Lookup/Providers.lua" })
ns.provide("bad", 1, function(add)
	add({ name = "Two", line = "/a", call = noop })
	add({ name = "Fine", call = noop })
end)
entries, counts = ns.collect()
assert(counts.bad == 1 and has("provider bad dropped Two two actions"))
ns.collect()
ns.collect()
entries, counts = ns.collect()
assert(counts.bad == nil and has("provider bad off"))

-- At most 500 entries per provider; slow builds are logged, not punished.
ns = load({ "Lookup/Action.lua", "Lookup/Providers.lua" })
ns.provide("many", 1, function(add)
	for i = 1, 600 do add({ name = "n" .. i, call = noop }) end
	clock = clock + 7
end)
for _ = 1, 4 do entries, counts = ns.collect() end
assert(counts.many == 500 and has("provider many cut at 500") and has("provider many slow: 7 ms"))

print("ok")
