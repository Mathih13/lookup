-- Shared stand-ins for WoW globals, for tests in plain lua5.1. Grow it as tests need more.
-- Usage: local load = dofile("tests/stubs.lua"); local ns = load({ "Lookup/Action.lua" })

function issecretvalue(v) return v == "SECRET" end

---Load addon files into one namespace, as the client does. Logs go to ns.logged.
return function(files, ns)
	ns = ns or {}
	ns.logged = {}
	ns.log = ns.log or function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		ns.logged[#ns.logged + 1] = table.concat(parts, " ")
	end
	for _, file in ipairs(files) do assert(loadfile(file))("Lookup", ns) end
	return ns
end
