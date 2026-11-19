-- The provider registry. Providers build entries; the registry keeps a bad one from breaking
-- the box. See docs/design.md "Other addons" (Providers, Isolation).
local _, ns = ...

local MAX_ENTRIES = 500 -- per provider and open
local SLOW_MS = 5 -- logged, not punished: the settings walk can take this long
local MAX_FAILURES = 3 -- a provider that throws or gives invalid actions this often is off for the session

local providers = {}

---Register a provider. build(add) calls add(entry) for each entry, and each entry gets `rank`.
---Built-ins, addon discovery and (later) outside addons all register here.
---@param id string for log lines and counts
---@param rank number category order: lower ranks first among equal matches
---@param build fun(add: fun(entry: table))
function ns.provide(id, rank, build)
	providers[#providers + 1] = { id = id, rank = rank, build = build, failures = 0 }
end

---Build every provider that is still on.
---@return table[] entries, table<string, number> counts entries per provider id
function ns.collect()
	local out, counts = {}, {}
	for _, p in ipairs(providers) do
		if p.failures < MAX_FAILURES then
			local n, dropped, cut = 0, 0, false
			local function add(e)
				-- Rows without a readable name are skipped quietly: they happen in normal data.
				if type(e) ~= "table" or type(e.name) ~= "string" or issecretvalue(e.name) then return end
				local kind, err = ns.actionKind(e)
				if not kind then
					dropped = dropped + 1
					if dropped == 1 then ns.log("provider", p.id, "dropped", e.name, err) end
				elseif n >= MAX_ENTRIES then
					cut = true
				else
					n = n + 1
					e.rank = p.rank
					out[#out + 1] = e
				end
			end
			local start = debugprofilestop()
			local ok, err = pcall(p.build, add)
			local ms = debugprofilestop() - start
			if ms > SLOW_MS then ns.log("provider", p.id, "slow:", math.floor(ms), "ms") end
			if cut then ns.log("provider", p.id, "cut at", MAX_ENTRIES, "entries") end
			if not ok then ns.log("provider", p.id, "failed:", err) end
			if not ok or dropped > 0 then
				p.failures = p.failures + 1
				if p.failures >= MAX_FAILURES then ns.log("provider", p.id, "off for this session") end
			end
			counts[p.id] = n
		end
	end
	return out, counts
end
