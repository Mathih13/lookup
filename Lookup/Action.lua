local _, ns = ...

local KINDS = { "binding", "line", "call", "toggle" }
local MACROTEXT_LIMIT = 255

---@return string? kind, string? err
function ns.actionKind(entry)
	local kind
	for _, k in ipairs(KINDS) do
		if entry[k] ~= nil then
			if kind then return nil, "two actions: " .. kind .. " and " .. k end
			kind = k
		end
	end
	if not kind then return nil, "no action" end
	local v = entry[kind]
	if kind == "binding" and type(v) ~= "string" then return nil, "binding is not a string" end
	if kind == "line" and (type(v) ~= "string" or v:find("\n") or #v > MACROTEXT_LIMIT) then
		return nil, "line must be one line of at most " .. MACROTEXT_LIMIT .. " characters"
	end
	if kind == "call" and type(v) ~= "function" then return nil, "call is not a function" end
	if kind == "toggle" and (type(v) ~= "table" or type(v.get) ~= "function" or type(v.set) ~= "function") then
		return nil, "toggle needs get and set functions"
	end
	if entry.button ~= nil and (kind ~= "binding" or type(entry.button) ~= "string") then
		return nil, "button needs a binding"
	end
	if entry.tab ~= nil and (entry.button == nil or type(entry.tab) ~= "function") then
		return nil, "tab needs a binding with a button"
	end
	if entry.after ~= nil and ((kind ~= "binding" and kind ~= "line") or type(entry.after) ~= "function") then
		return nil, "after needs a binding or a line"
	end
	if entry.alt ~= nil then
		local alt = entry.alt
		if type(alt) ~= "table" or alt.alt ~= nil then return nil, "alt must be one action, with no alt" end
		if entry.tab and alt.tab then return nil, "tab on both actions" end
		local _, altErr = ns.actionKind(alt)
		if altErr then return nil, "alt: " .. altErr end
	end
	return kind
end

---@param tabVisible boolean? nil when the entry has no tab button now, else whether it is visible
---@return table? plan, string? err
function ns.plan(entry, tabVisible)
	local kind, err = ns.actionKind(entry)
	if not kind then return nil, err end
	if kind == "line" then
		return { enter = "click", macrotext = entry.line, after = entry.after }
	elseif kind == "call" then
		return { enter = "plain", after = entry.call }
	elseif kind == "toggle" then
		local t = entry.toggle
		return { enter = "plain", after = function()
			local v = not t.get()
			t.set(v)
			print(entry.name .. ": " .. (v and "On" or "Off"))
		end }
	end
	local open = entry.button and "/click " .. entry.button
	if tabVisible ~= nil and open then
		local macrotext = (tabVisible and "" or open .. "\n") .. "/click LookupTab"
		return { enter = "click", macrotext = macrotext, clickTab = true, after = entry.after }
	end
	return { enter = "binding", command = entry.binding, macrotext = open, after = entry.after }
end
