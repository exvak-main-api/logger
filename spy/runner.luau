--[[
  runner.luau — execute user Lua inside the tracer sandbox and emit reconstructed source.
  Usage: lune run runner.luau <input.lua> [output.lua]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")
local luau = require("@lune/luau")

local Logger = require("./logger")
local Sandbox = require("./sandbox")

local args = process.args
if #args < 1 then
	warn("usage: lune run runner.luau <input.lua> [output.lua]")
	process.exit(1)
end

local inputPath = args[1]
local outputPath = args[2] or (inputPath:gsub("%.lua[u]?$", "") .. "_reconstructed.lua")

if not fs.isFile(inputPath) then
	warn("input file not found: " .. inputPath)
	process.exit(1)
end

local source = fs.readFile(inputPath)
Logger:clear()
Logger:enable()

local env = Sandbox.create()

env.wait = function(t)
	Logger:add(`wait({t and tostring(t) or ""})`)
	return t or 0
end
if env.task then
	env.task.wait = function(t)
		Logger:add(`task.wait({t and tostring(t) or ""})`)
		return t or 0
	end
end

local originalLoadstring = env.loadstring
env.loadstring = function(src, chunk)
	if type(src) == "string" then
		Logger:add(`-- loadstring body ({#src} bytes)`)
		if #src < 200000 then
			for line in (src .. "\n"):gmatch("(.-)\n") do
				if line ~= "" then
					Logger:add(line)
				end
			end
		else
			Logger:add(`-- [loadstring truncated, {#src} bytes]`)
		end
	end
	if originalLoadstring then
		return originalLoadstring(src, chunk)
	end
	return function() end
end
env.load = env.loadstring

local chunk, err
local ok, compileErr = pcall(function()
	chunk, err = luau.load(source, {
		debugName = inputPath,
	end)
end)

if not ok or not chunk then
	local msg = tostring(err or compileErr or "compile failed")
	fs.writeFile(outputPath, "-- reconstruction failed\n-- " .. msg .. "\n")
	print("error")
	print(msg)
	process.exit(1)
end

local bound = setmetatable({}, {
	__index = function(_, k)
		return env[k]
	end,
	__newindex = function(_, k, v)
		env[k] = v
	end,
})

local ran, runErr = pcall(function()
	local fn = chunk
	if type(fn) == "function" then
		local setfenv = rawget(_G, "setfenv")
		if type(setfenv) == "function" then
			setfenv(fn, bound)
		end
		fn()
	end
end)

local lines = {}
table.insert(lines, "-- reconstructed by logger/spy")
table.insert(lines, "-- source: " .. inputPath)
table.insert(lines, "")

if not ran then
	table.insert(lines, "-- runtime note: " .. tostring(runErr))
	table.insert(lines, "")
end

local dump = Logger:dumpExpressions()
if dump == "" then
	table.insert(lines, "-- no traced expressions (script may be pure data or failed early)")
	table.insert(lines, "-- original size: " .. tostring(#source) .. " bytes")
else
	table.insert(lines, dump)
end

local out = table.concat(lines, "\n") .. "\n"
fs.writeFile(outputPath, out)
print("success")
print(outputPath)
print(tostring(Logger:count()))
