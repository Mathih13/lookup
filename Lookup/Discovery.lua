local addonName, ns = ...
ns.discover = {}

function ns.addonOf(tbl, key)
	local secure, by = issecurevariable(tbl, key)
	if secure or not by or by == addonName then return nil end
	return ns.addonTitle(by), by
end

function ns.addonTitle(folder)
	local title = C_AddOns.GetAddOnMetadata(folder, "Title") or folder
	return strtrim((title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")))
end

local function addonIcon(folder)
	if not folder then return nil, nil end
	local icon = C_AddOns.GetAddOnMetadata(folder, "IconTexture")
	return icon, not icon and C_AddOns.GetAddOnMetadata(folder, "IconAtlas") or nil
end

function ns.discover.slash()
	local out, seen = {}, {}
	local hidden = getmetatable(SlashCmdList)
	for _, list in ipairs({ SlashCmdList, hidden and type(hidden.__index) == "table" and hidden.__index or {} }) do
		for key in pairs(list) do
			local command = _G["SLASH_" .. key .. "1"]
			if type(command) == "string" and not seen[command] then
				seen[command] = true
				local aliases, spelled, i = {}, { [command:lower()] = true }, 2
				while type(_G["SLASH_" .. key .. i]) == "string" do
					local alias = _G["SLASH_" .. key .. i]
					if not spelled[alias:lower()] then
						spelled[alias:lower()] = true
						aliases[#aliases + 1] = alias
					end
					i = i + 1
				end
				local title, folder = ns.addonOf(_G, "SLASH_" .. key .. "1")
				local icon, atlas = addonIcon(folder)
				out[#out + 1] = { command = command, aliases = aliases, title = title, folder = folder,
					icon = icon, atlas = atlas }
			end
		end
	end
	return out
end

function ns.discover.bindings()
	local out = {}
	for i = 1, GetNumBindings() do
		local command, header, key1 = GetBinding(i)
		local name = command and _G["BINDING_NAME_" .. command]
		if type(name) == "string" then
			local title, folder = ns.addonOf(_G, "BINDING_NAME_" .. command)
			local headerName = header and _G[header]
			out[#out + 1] = { command = command, name = name, header = type(headerName) == "string" and headerName or nil,
				bound = key1 ~= nil, title = title, folder = folder }
		end
	end
	return out
end

local function libStub(major)
	return _G.LibStub and _G.LibStub(major, true)
end

function ns.discover.launchers()
	local out = {}
	local ldb = libStub("LibDataBroker-1.1")
	if not ldb then return out end
	for name, obj in ldb:DataObjectIterator() do
		if obj.type == "launcher" and type(obj.OnClick) == "function" then
			local title, folder
			if C_AddOns.DoesAddOnExist(name) then
				title, folder = ns.addonTitle(name), name
			else
				title, folder = ns.addonOf(ldb.attributestorage and ldb.attributestorage[obj] or obj, "OnClick")
			end
			local icon, atlas = addonIcon(folder)
			out[#out + 1] = { name = name, label = type(obj.label) == "string" and obj.label or name,
				icon = obj.icon or icon, atlas = not obj.icon and atlas or nil, onClick = obj.OnClick,
				title = title, folder = folder }
		end
	end
	return out
end

function ns.discover.minimapButton(name)
	local icon = libStub("LibDBIcon-1.0")
	return icon and type(icon.GetMinimapButton) == "function" and icon:GetMinimapButton(name) or nil
end

function ns.probe()
	local n, lines = {}, {}
	local function count(k, line)
		n[k] = (n[k] or 0) + 1
		if line then lines[#lines + 1] = k .. " " .. line end
	end
	for _, r in ipairs(ns.discover.slash()) do
		count(r.title and "slash.addon" or "slash.blizzard", r.title and r.command .. " (" .. r.title .. ")")
	end
	for _, r in ipairs(ns.discover.bindings()) do
		count(r.title and "binding.addon" or "binding.blizzard", r.title and r.command .. " (" .. r.title .. ")")
	end
	for _, r in ipairs(ns.discover.launchers()) do count("launcher", r.name .. " (" .. tostring(r.title) .. ")") end
	for _, data in ipairs(AddonCompartmentFrame and AddonCompartmentFrame.registeredAddons or {}) do
		count("compartment", tostring(data.text))
	end
	local ldb = libStub("LibDataBroker-1.1")
	if ldb then
		for name, obj in ldb:DataObjectIterator() do
			if obj.type ~= "launcher" then count("ldb." .. tostring(obj.type), name) end
		end
	end
	local ace = libStub("AceConfigRegistry-3.0")
	if ace then
		for app in ace:IterateOptionsTables() do count("aceconfig", app) end
	end
	for _, line in ipairs(lines) do ns.log("probe", line) end
	local parts = {}
	for k, v in pairs(n) do parts[#parts + 1] = k .. "=" .. v end
	table.sort(parts)
	local _, perProvider = ns.collect()
	local providers = {}
	for id, v in pairs(perProvider) do providers[#providers + 1] = id .. "=" .. v end
	table.sort(providers)
	ns.log("probe counts", table.concat(parts, " "))
	ns.log("probe providers", table.concat(providers, " "))
	print("Lookup probe: " .. table.concat(parts, ", "))
end
