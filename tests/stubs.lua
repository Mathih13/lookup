-- Shared stand-ins for WoW globals, for tests in plain lua5.1. Grow it as tests need more.
-- Usage: local load = dofile("tests/stubs.lua"); local ns = load({ "Lookup/Action.lua" })

function issecretvalue(v) return v == "SECRET" end

-- A clock tests move by hand: clock = clock + 7.
clock = 0
function debugprofilestop() return clock end

-- Taint: which addon set a variable, by key (in any table). Unlisted keys are Blizzard's.
taint = {}
function issecurevariable(t, k)
	if k == nil then k = t end
	local by = taint[k]
	return by == nil, by
end

-- Installed addons by folder: { Title =, IconTexture =, IconAtlas = }.
addons = {}
C_AddOns = {
	GetAddOnMetadata = function(folder, field) return addons[folder] and addons[folder][field] end,
	DoesAddOnExist = function(folder) return addons[folder] ~= nil end,
}

function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

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
