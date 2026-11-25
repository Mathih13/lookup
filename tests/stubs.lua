local failures = 0

function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		failures = failures + 1
		io.stderr:write("FAIL ", name, "\n", tostring(err), "\n")
	end
end

function done()
	if failures > 0 then os.exit(1) end
	print("ok")
end

function issecretvalue(v) return v == "SECRET" end

clock = 0
function debugprofilestop() return clock end

taint = {}
function issecurevariable(t, k)
	if k == nil then k = t end
	local by = taint[k]
	return by == nil, by
end

addons = {}
C_AddOns = {
	GetAddOnMetadata = function(folder, field) return addons[folder] and addons[folder][field] end,
	DoesAddOnExist = function(folder) return addons[folder] ~= nil end,
}

function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

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
