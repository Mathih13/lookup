-- The Action plan: how Enter and a click run an entry. See docs/design.md "Terms" and
-- "Panel-opening architecture". Pure (no frames), so tests run it in plain Lua.
--
-- An entry sets exactly one action kind:
--   binding = "TOGGLESPELLBOOK"  a binding command. Enter runs it through an override binding,
--                                which is secure. button = "SpellbookMicroButton" gives the mouse
--                                a "/click" path. tab = function returning a tab button to click
--                                after the panel opens (needs button).
--   line = "/macro"              one macro line, run by the secure LookupRun button.
--   call = function              plain code: only calls proven clean (no panel opens).
--   toggle = { get, set }        flips a boolean setting in place.
-- after = function runs as plain code after the secure part of a binding or a line.
-- Panel opens must not run from plain addon code: they taint the action bars.
local _, ns = ...

local KINDS = { "binding", "line", "call", "toggle" }
local MAX_LINE = 255 -- the macrotext limit

---The entry's action kind, or nil and the reason it is not valid.
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
	if kind == "line" and (type(v) ~= "string" or v:find("\n") or #v > MAX_LINE) then
		return nil, "line must be one line of at most " .. MAX_LINE .. " characters"
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
	return kind
end

---How to run an entry.
---  enter: "binding" (the override binding runs `command`), "click" (the override binding
---         clicks LookupRun), or "plain" (no secure part: run `after` at once).
---  macrotext: LookupRun's macro, for the mouse and for an Enter that clicks. Nil: no secure part.
---  clickTab: LookupTab must hold the tab button, and the macro clicks it.
---  after: plain code to run after the secure part, or nil.
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
		-- Open the panel unless it is open (the click would close it), then click the tab.
		local macrotext = (tabVisible and "" or open .. "\n") .. "/click LookupTab"
		return { enter = "click", macrotext = macrotext, clickTab = true, after = entry.after }
	end
	return { enter = "binding", command = entry.binding, macrotext = open, after = entry.after }
end
