--[[
  aspect_bridge.luau
  Thin adapter so the rest of logger/spy can call Aspect with a stable API.

  Aspect itself is a full Lune-based Roblox environment emulator / dumper.
  This module normalizes dumpfile / dumpstring usage and recovers output.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local Bridge = {}

local function safeRequireAspect()
	local ok, mod = pcall(require, "./aspect")
	if not ok then
		return nil, tostring(mod)
	end
	return mod, nil
end

function Bridge.available(): (boolean, string?)
	local mod, err = safeRequireAspect()
	if not mod then
		return false, err
	end
	if type(mod.dumpfile) ~= "function" and type(mod.dumpstring) ~= "function" then
		return false, "aspect module loaded but missing dumpfile/dumpstring"
	end
	return true, nil
end

--- Run Aspect against a file. Returns success, outputPathOrErr, optional stats table.
function Bridge.dumpFile(inputPath: string, outputPath: string?): (boolean, string, any?)
	local aspect, err = safeRequireAspect()
	if not aspect then
		return false, err or "aspect require failed", nil
	end

	if not fs.isFile(inputPath) then
		return false, "input file not found: " .. inputPath, nil
	end

	local out = outputPath or (inputPath:gsub("%.lua[u]?$", "") .. "_aspect.lua")

	if type(aspect.reset) == "function" then
		pcall(aspect.reset)
	end

	local ok, result = pcall(function()
		if type(aspect.dumpfile) == "function" then
			return aspect.dumpfile(inputPath, out)
		end
		-- fallback: dumpstring path
		local src = fs.readFile(inputPath)
		return aspect.dumpstring(src, out)
	end)

	if not ok then
		return false, "aspect runtime error: " .. tostring(result), nil
	end

	if fs.isFile(out) then
		local stats = nil
		if type(aspect.stats) == "function" then
			local sOk, s = pcall(aspect.stats)
			if sOk then
				stats = s
			end
		end
		return true, out, stats
	end

	-- Some Aspect builds only expose getout()
	if type(aspect.getout) == "function" then
		local gOk, body = pcall(aspect.getout)
		if gOk and type(body) == "string" and #body > 0 then
			fs.writeFile(out, body)
			return true, out, nil
		end
	end

	return false, "aspect finished but produced no output at " .. out, nil
end

--- Run Aspect against an in-memory source string.
function Bridge.dumpString(source: string, outputPath: string): (boolean, string, any?)
	local aspect, err = safeRequireAspect()
	if not aspect then
		return false, err or "aspect require failed", nil
	end

	if type(aspect.reset) == "function" then
		pcall(aspect.reset)
	end

	local ok, result = pcall(function()
		if type(aspect.dumpstring) == "function" then
			return aspect.dumpstring(source, outputPath)
		end
		-- write temp then dumpfile
		local tmp = outputPath:gsub("%.lua[u]?$", "") .. "_tmp_in.lua"
		fs.writeFile(tmp, source)
		local r = aspect.dumpfile(tmp, outputPath)
		pcall(function()
			fs.removeFile(tmp)
		end)
		return r
	end)

	if not ok then
		return false, "aspect runtime error: " .. tostring(result), nil
	end

	if fs.isFile(outputPath) then
		return true, outputPath, nil
	end

	if type(aspect.getout) == "function" then
		local gOk, body = pcall(aspect.getout)
		if gOk and type(body) == "string" and #body > 0 then
			fs.writeFile(outputPath, body)
			return true, outputPath, nil
		end
	end

	return false, "aspect finished but produced no output", nil
end

return Bridge
