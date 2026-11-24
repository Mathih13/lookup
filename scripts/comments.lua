#!/usr/bin/env lua5.1
local USAGE = [[
Usage:
  lua5.1 scripts/comments.lua check FILE...   fail when a file's comment count differs from the baseline
  lua5.1 scripts/comments.lua lower FILE...   write the current counts into the baseline; never raises one
  lua5.1 scripts/comments.lua list FILE...    print every counted comment as path:line: text
See docs/adr/0001-no-code-comments.md.]]

local BASELINE = ".comments-baseline"

local function isAllowed(body)
	return body:find("^%-@") or body:find("^@[%w%-]+@") or body:find("^%[=*%[@")
end

local function comments(source)
	local found, i, line, n = {}, 1, 1, #source
	local function advance(to)
		local _, newlines = source:sub(i, to - 1):gsub("\n", "")
		line, i = line + newlines, to
	end
	local function longBracketEnd(at)
		local equals = source:match("^%[(=*)%[", at)
		if not equals then return nil end
		local _, close = source:find("]" .. equals .. "]", at, true)
		return close or n
	end
	while i <= n do
		local c = source:sub(i, i)
		if source:sub(i, i + 1) == "--" then
			local startLine, close = line, longBracketEnd(i + 2)
			local stop = close or (source:find("\n", i, true) or n + 1) - 1
			local body = source:sub(i + 2, stop)
			if not isAllowed(body) then found[#found + 1] = { line = startLine, text = source:sub(i, stop) } end
			advance(stop + 1)
		elseif c == "\"" or c == "'" then
			local j = i + 1
			while j <= n and source:sub(j, j) ~= c and source:sub(j, j) ~= "\n" do
				j = j + (source:sub(j, j) == "\\" and 2 or 1)
			end
			advance(j + 1)
		elseif c == "[" and longBracketEnd(i) then
			advance(longBracketEnd(i) + 1)
		else
			if c == "\n" then line = line + 1 end
			i = i + 1
		end
	end
	return found
end

local function count(path)
	local f = assert(io.open(path, "rb"))
	local source = f:read("*a")
	f:close()
	return comments(source)
end

local function readBaseline()
	local t = {}
	local f = io.open(BASELINE, "r")
	if not f then return nil end
	for path, n in f:read("*a"):gmatch("(%S+)%s+(%d+)") do t[path] = tonumber(n) end
	f:close()
	return t
end

local mode = arg[1]
local files = { select(2, unpack(arg)) }
if #files == 0 or not (mode == "check" or mode == "lower" or mode == "list") then
	io.stderr:write(USAGE, "\n")
	os.exit(2)
end

local baseline, failed = readBaseline(), false
local bootstrap = baseline == nil
baseline = baseline or {}

if mode == "list" then
	for _, path in ipairs(files) do
		for _, c in ipairs(count(path)) do print(path .. ":" .. c.line .. ": " .. c.text) end
	end
elseif mode == "check" then
	for _, path in ipairs(files) do
		local found, allowed = count(path), baseline[path] or 0
		if #found > allowed then
			failed = true
			io.stderr:write(("%s: %d comments, baseline %d. Delete the new ones; record a decision in docs/adr/.\n")
				:format(path, #found, allowed))
			for _, c in ipairs(found) do io.stderr:write(("  %s:%d: %s\n"):format(path, c.line, c.text)) end
		elseif #found < allowed then
			failed = true
			io.stderr:write(("%s: %d comments, baseline %d. Run `make comments-baseline` to lock in the drop.\n")
				:format(path, #found, allowed))
		end
	end
else
	local out = {}
	for _, path in ipairs(files) do
		local n = #count(path)
		local allowed = bootstrap and n or baseline[path] or 0
		if n > allowed then
			failed = true
			io.stderr:write(("%s: %d comments, baseline %d. The baseline only goes down.\n"):format(path, n, allowed))
		end
		if n > 0 then out[#out + 1] = path .. " " .. math.min(n, allowed) end
	end
	table.sort(out)
	local f = assert(io.open(BASELINE, "w"))
	f:write(table.concat(out, "\n"), #out > 0 and "\n" or "")
	f:close()
end

os.exit(failed and 1 or 0)
