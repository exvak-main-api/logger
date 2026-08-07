--[[
  runner.luau — execute user Lua through either:
    1) the lightweight expression-tree tracer (default)
    2) Aspect full environment dumper (--aspect)

  Usage:
    lune run runner.luau <input.lua> [output.lua]
    lune run runner.luau --aspect <input.lua> [output.lua]
    lune run runner.luau --tracer <input.lua> [output.lua]   (explicit default)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")

local Logger = require("./logger")
local Sandbox = require("./sandbox")

local args = process.args
local mode = "tracer" -- tracer | aspect
local positional = {}

for _, a in args do
	if a == "--aspect" or a == "-a" or a == "aspect" then
		mode = "aspect"
	elseif a == "--tracer" or a == "-t" or a == "tracer" then
		mode = "tracer"
	else
		table.insert(positional, a)
	end
end

if #positional < 1 then
	warn("usage: lune run runner.luau [--aspect|--tracer] <input.lua> [output.lua]")
	process.exit(1)
end

local inputPath = positional[1]
local outputPath = positional[2]

if not fs.isFile(inputPath) then
	warn("input file not found: " .. inputPath)
	process.exit(1)
end

---------------------------------------------------------------------------
-- Aspect path
---------------------------------------------------------------------------
if mode == "aspect" then
	local Bridge = require("./aspect_bridge")
	local okAvail, availErr = Bridge.available()
	if not okAvail then
		warn("aspect unavailable: " .. tostring(availErr))
		process.exit(1)
	end

	local out = outputPath or (inputPath:gsub("%.lua[u]?$", "") .. "_aspect.lua")
	local ok, pathOrErr, stats = Bridge.dumpFile(inputPath, out)
	if not ok then
		warn("aspect failed: " .. tostring(pathOrErr))
		process.exit(1)
	end

	print("success")
	print(pathOrErr)
	if stats then
		print(string.format("lines=%s remotes=%s proxies=%s", tostring(stats.lines), tostring(stats.remotes), tostring(stats.proxies)))
	end
	process.exit(0)
end

---------------------------------------------------------------------------
-- Default tracer path (original behaviour)
---------------------------------------------------------------------------
outputPath = outputPath or (inputPath:gsub("%.lua[u]?$", "") .. "_reconstructed.lua")

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
table.insert(lines, "-- reconstructed by logger/spy (tracer)")
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
