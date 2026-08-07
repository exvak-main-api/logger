-- spy/init.luau
local Sandbox = require("@self/sandbox")
local Logger = require("@self/logger")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local env = Sandbox.create()

stdio.write(stdio.color("cyan") .. "Tracer sandbox ready (Lune)\n" .. stdio.color("reset"))

if process.args[1] then
	local src = process.args[1]
	local fn, err = loadstring(src)
	if not fn then
		Logger:error(`loadstring failed: {err}`)
		process.exit(1)
	end
	setfenv(fn, env)
	local ok, result = pcall(fn)
	if not ok then
		Logger:error(tostring(result))
		process.exit(1)
	end
else
	stdio.write("Usage: lune run spy -- <code>\n")
end

stdio.write(stdio.color("green") .. "\n--- Log dump ---\n" .. stdio.color("reset"))
print(Logger:dump())
