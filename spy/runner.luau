--[[
  runner.luau — reconstruct Lua via Aspect (default) or tracer.

  Usage:
    lune run runner.luau <input.lua> [output.lua]          -- Aspect first, tracer fallback
    lune run runner.luau --aspect <input.lua> [output.lua]
    lune run runner.luau --tracer <input.lua> [output.lua]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")

local Logger = require("./logger")
local Sandbox = require("./sandbox")

local OSE_HEADER = table.concat({
	"-- [[",
	"this file was constructed by OSE env logger",
	"@ discord.gg/uEWVqpnyf2",
	"]] --",
	"",
}, "\n")

local function writeOse(path: string, body: string)
	local core = (body or ""):gsub("%s+$", "")
	if core == "" then
		core = "-- (empty dump)"
	end
	fs.writeFile(path, OSE_HEADER .. core .. "\n")
end

local args = process.args
local mode = "auto" -- auto | aspect | tracer
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
local outputPath = positional[2] or (inputPath:gsub("%.lua[u]?$", "") .. "_reconstructed.lua")

if not fs.isFile(inputPath) then
	warn("input file not found: " .. inputPath)
	process.exit(1)
end

local function runAspect(): boolean
	local Bridge = require("./aspect_bridge")
	local okAvail, availErr = Bridge.available()
	if not okAvail then
		warn("aspect unavailable: " .. tostring(availErr))
		return false
	end
	local ok, pathOrErr, stats = Bridge.dumpFile(inputPath, outputPath)
	if not ok then
		warn("aspect failed: " .. tostring(pathOrErr))
		return false
	end
	print("success")
	print(pathOrErr)
	if stats then
		print(string.format("lines=%s remotes=%s proxies=%s", tostring(stats.lines), tostring(stats.remotes), tostring(stats.proxies)))
	end
	return true
end

local function runTracer(): boolean
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
			if #src < 200000 then
				for line in (src .. "\n"):gmatch("(.-)\n") do
					if line ~= "" then
						Logger:add(line)
					end
				end
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
		chunk, err = luau.load(source, { debugName = inputPath })
	end)

	if not ok or not chunk then
		local msg = tostring(err or compileErr or "compile failed")
		writeOse(outputPath, "-- reconstruction failed\n-- " .. msg)
		print("error")
		print(msg)
		return false
	end

	local bound = setmetatable({}, {
		__index = function(_, k)
			return env[k]
		end,
		__newindex = function(_, k, v)
			env[k] = v
		end,
	})

	pcall(function()
		local fn = chunk
		if type(fn) == "function" then
			local setfenv = rawget(_G, "setfenv")
			if type(setfenv) == "function" then
				setfenv(fn, bound)
			end
			fn()
		end
	end)

	local dump = Logger:dumpExpressions()
	writeOse(outputPath, dump)
	print("success")
	print(outputPath)
	print(tostring(Logger:count()))
	return true
end

if mode == "aspect" then
	if not runAspect() then
		process.exit(1)
	end
	process.exit(0)
elseif mode == "tracer" then
	if not runTracer() then
		process.exit(1)
	end
	process.exit(0)
else
	-- auto: Aspect first, tracer fallback
	if not runAspect() then
		warn("falling back to tracer")
		if not runTracer() then
			process.exit(1)
		end
	end
	process.exit(0)
end
