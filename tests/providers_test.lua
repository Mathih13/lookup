local load = dofile("tests/stubs.lua")
local noop = function() end
local function registry() return load({ "Lookup/Action.lua", "Lookup/Providers.lua" }) end
local function logged(ns, pattern)
	for _, line in ipairs(ns.logged) do
		if line:find(pattern) then return true end
	end
	return false
end

test("entries get their provider's rank, and rows without a readable name are skipped quietly", function()
	local ns = registry()
	ns.provide("panels", 1, function(add)
		add({ name = "Currency", binding = "TOGGLECURRENCY" })
		add({ name = nil, call = noop })
		add({ name = "SECRET", call = noop })
	end)
	local entries, counts = ns.collect()
	assert(#entries == 1 and entries[1].rank == 1 and counts.panels == 1)
	assert(#ns.logged == 0, ns.logged[1])
end)

test("a failing provider does not stop the others, and is off after three failures", function()
	local ns = registry()
	local builds = 0
	ns.provide("broken", 2, function(add)
		builds = builds + 1
		add({ name = "Before the error", call = noop })
		error("boom")
	end)
	ns.provide("people", 3, function(add) add({ name = "Ashkara", call = noop }) end)
	local counts
	for _ = 1, 4 do _, counts = ns.collect() end
	assert(builds == 3, builds)
	assert(counts.people == 1 and counts.broken == nil)
	assert(logged(ns, "provider broken failed:.*boom") and logged(ns, "provider broken off for this session"))
end)

test("invalid actions are dropped and count as failures", function()
	local ns = registry()
	ns.provide("bad", 1, function(add)
		add({ name = "Two", line = "/a", call = noop })
		add({ name = "Fine", call = noop })
	end)
	local _, counts = ns.collect()
	assert(counts.bad == 1 and logged(ns, "provider bad dropped Two two actions"))
	ns.collect()
	ns.collect()
	_, counts = ns.collect()
	assert(counts.bad == nil and logged(ns, "provider bad off"))
end)

test("a provider gets at most 500 entries, and a slow build is logged, not punished", function()
	local ns = registry()
	ns.provide("many", 1, function(add)
		for i = 1, 600 do add({ name = "n" .. i, call = noop }) end
		clock = clock + 7
	end)
	local counts
	for _ = 1, 4 do _, counts = ns.collect() end
	assert(counts.many == 500 and logged(ns, "provider many cut at 500") and logged(ns, "provider many slow: 7 ms"))
end)

done()
