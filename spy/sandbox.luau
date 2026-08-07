local Proxy = require("./proxy")
local Logger = require("./logger")
local task = require("@lune/task")

local Sandbox = {}

function Sandbox.create()
	local env = {}

	env.game = Proxy.new("game")
	env.workspace = Proxy.new("workspace")
	env.script = Proxy.new("script")

	env.print = function(...: any)
		local args = table.pack(...)
		local parts = {}
		for i = 1, args.n do
			parts[i] = Proxy.stringify(args[i])
		end
		Logger:add(`print({table.concat(parts, ", ")})`)
	end

	env.warn = function(...: any)
		local args = table.pack(...)
		local parts = {}
		for i = 1, args.n do
			parts[i] = Proxy.stringify(args[i])
		end
		Logger:warn(`warn({table.concat(parts, ", ")})`)
	end

	env.error = function(...: any)
		local args = table.pack(...)
		local parts = {}
		for i = 1, args.n do
			parts[i] = Proxy.stringify(args[i])
		end
		Logger:error(`error({table.concat(parts, ", ")})`)
	end

	env.getgenv = function()
		Logger:add("getgenv()")
		return Proxy.new("getgenv()")
	end

	env.getrenv = function()
		Logger:add("getrenv()")
		return Proxy.new("getrenv()")
	end

	env.identifyexecutor = function()
		Logger:add("identifyexecutor()")
		return "Tracer", "1.0"
	end

	env.hookfunction = function(old, new)
		Logger:add(`hookfunction({Proxy.stringify(old)}, {Proxy.stringify(new)})`)
		return Proxy.new(`hookfunction({Proxy.stringify(old)}, {Proxy.stringify(new)})`)
	end

	env.hookmetamethod = function(obj, method, hook)
		Logger:add(`hookmetamethod({Proxy.stringify(obj)}, {Proxy.stringify(method)}, {Proxy.stringify(hook)})`)
		return Proxy.new(`hookmetamethod({Proxy.stringify(obj)}, {Proxy.stringify(method)}, {Proxy.stringify(hook)})`)
	end

	env.newcclosure = function(fn)
		Logger:add(`newcclosure({Proxy.stringify(fn)})`)
		return Proxy.new(`newcclosure({Proxy.stringify(fn)})`)
	end

	env.checkcaller = function()
		Logger:add("checkcaller()")
		return false
	end

	env.getnamecallmethod = function()
		Logger:add("getnamecallmethod()")
		return Proxy.new("getnamecallmethod()")
	end

	env.getrawmetatable = function(obj)
		Logger:add(`getrawmetatable({Proxy.stringify(obj)})`)
		return Proxy.new(`getrawmetatable({Proxy.stringify(obj)})`)
	end

	env.setreadonly = function(t, readonly)
		Logger:add(`setreadonly({Proxy.stringify(t)}, {Proxy.stringify(readonly)})`)
	end

	env.isreadonly = function(t)
		Logger:add(`isreadonly({Proxy.stringify(t)})`)
		return false
	end

	env.getconnections = function(signal)
		Logger:add(`getconnections({Proxy.stringify(signal)})`)
		return Proxy.new(`getconnections({Proxy.stringify(signal)})`)
	end

	env.Instance = {
		new = function(class: any, parent: any?)
			local args = Proxy.stringify(class)
			if parent then
				args ..= `, {Proxy.stringify(parent)}`
			end
			Logger:add(`Instance.new({args})`)
			return Proxy.new(`Instance.new({args})`)
		end,
	}

	env.pairs = Proxy.pairs
	env.ipairs = Proxy.ipairs

	env.task = setmetatable({
		wait = function(t: any?)
			local arg = if t then Proxy.stringify(t) else ""
			Logger:add(`task.wait({arg})`)
			task.wait(tonumber(t) or 0)
			return Proxy.new(`task.wait({arg})`)
		end,
		spawn = function(f: any, ...: any)
			local args = { Proxy.stringify(f) }
			for _, v in { ... } do
				table.insert(args, Proxy.stringify(v))
			end
			Logger:add(`task.spawn({table.concat(args, ", ")})`)
			return Proxy.new(`task.spawn({table.concat(args, ", ")})`)
		end,
	}, {
		__index = function(_, key)
			return Proxy.new(`task.{key}`)
		end,
	})

	setmetatable(env, {
		__index = function(_, key)
			return Proxy.new(tostring(key))
		end,
		__newindex = function(_, key, value)
			Logger:add(`{tostring(key)} = {Proxy.stringify(value)}`)
		end,
	})

	return env
end

return Sandbox
