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
		for i = 1, args.n do parts[i] = Proxy.stringify(args[i]) end
		Logger:add(`print({table.concat(parts, ", ")})`)
	end

	env.warn = function(...: any)
		local args = table.pack(...)
		local parts = {}
		for i = 1, args.n do parts[i] = Proxy.stringify(args[i]) end
		Logger:warn(`warn({table.concat(parts, ", ")})`)
	end

	env.error = function(...: any)
		local args = table.pack(...)
		local parts = {}
		for i = 1, args.n do parts[i] = Proxy.stringify(args[i]) end
		Logger:error(`error({table.concat(parts, ", ")})`)
	end

	env.getgenv = function() Logger:add("getgenv()") return Proxy.new("getgenv()") end
	env.getrenv = function() Logger:add("getrenv()") return Proxy.new("getrenv()") end
	env.identifyexecutor = function() Logger:add("identifyexecutor()") return "Tracer", "1.0" end

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
	env.checkcaller = function() Logger:add("checkcaller()") return false end
	env.getnamecallmethod = function() Logger:add("getnamecallmethod()") return Proxy.new("getnamecallmethod()") end
	env.getrawmetatable = function(obj)
		Logger:add(`getrawmetatable({Proxy.stringify(obj)})`)
		return Proxy.new(`getrawmetatable({Proxy.stringify(obj)})`)
	end
	env.setreadonly = function(t, ro) Logger:add(`setreadonly({Proxy.stringify(t)}, {Proxy.stringify(ro)})`) end
	env.isreadonly = function(t) Logger:add(`isreadonly({Proxy.stringify(t)})`) return false end

	env.Instance = {
		new = function(class: any, parent: any?)
			local args = Proxy.stringify(class)
			if parent then args ..= `, {Proxy.stringify(parent)}` end
			Logger:add(`Instance.new({args})`)
			return Proxy.new(`Instance.new({args})`)
		end,
	}

	env.pairs = Proxy.pairs
	env.ipairs = Proxy.ipairs

	env.debug = setmetatable({
		traceback = function(...: any)
			local a = {} for _, v in {...} do table.insert(a, Proxy.stringify(v)) end
			Logger:add(`debug.traceback({table.concat(a, ", ")})`)
			return Proxy.new(`debug.traceback({table.concat(a, ", ")})`)
		end,
		info = function(...: any)
			local a = {} for _, v in {...} do table.insert(a, Proxy.stringify(v)) end
			Logger:add(`debug.info({table.concat(a, ", ")})`)
			return Proxy.new(`debug.info({table.concat(a, ", ")})`)
		end,
		getinfo = function(...: any)
			local a = {} for _, v in {...} do table.insert(a, Proxy.stringify(v)) end
			Logger:add(`debug.getinfo({table.concat(a, ", ")})`)
			return Proxy.new(`debug.getinfo({table.concat(a, ", ")})`)
		end,
		getupvalue = function(fn, idx)
			Logger:add(`debug.getupvalue({Proxy.stringify(fn)}, {Proxy.stringify(idx)})`)
			return Proxy.new(`debug.getupvalue({Proxy.stringify(fn)}, {Proxy.stringify(idx)})`)
		end,
		setupvalue = function(fn, idx, val)
			Logger:add(`debug.setupvalue({Proxy.stringify(fn)}, {Proxy.stringify(idx)}, {Proxy.stringify(val)})`)
		end,
		getupvalues = function(fn)
			Logger:add(`debug.getupvalues({Proxy.stringify(fn)})`)
			return Proxy.new(`debug.getupvalues({Proxy.stringify(fn)})`)
		end,
		getconstant = function(fn, idx)
			Logger:add(`debug.getconstant({Proxy.stringify(fn)}, {Proxy.stringify(idx)})`)
			return Proxy.new(`debug.getconstant({Proxy.stringify(fn)}, {Proxy.stringify(idx)})`)
		end,
		setconstant = function(fn, idx, val)
			Logger:add(`debug.setconstant({Proxy.stringify(fn)}, {Proxy.stringify(idx)}, {Proxy.stringify(val)})`)
		end,
		getconstants = function(fn)
			Logger:add(`debug.getconstants({Proxy.stringify(fn)})`)
			return Proxy.new(`debug.getconstants({Proxy.stringify(fn)})`)
		end,
		getproto = function(fn, idx, active)
			local args = `{Proxy.stringify(fn)}, {Proxy.stringify(idx)}`
			if active ~= nil then args ..= `, {Proxy.stringify(active)}` end
			Logger:add(`debug.getproto({args})`)
			return Proxy.new(`debug.getproto({args})`)
		end,
		getprotos = function(fn)
			Logger:add(`debug.getprotos({Proxy.stringify(fn)})`)
			return Proxy.new(`debug.getprotos({Proxy.stringify(fn)})`)
		end,
		getstack = function(lvl, idx)
			local args = Proxy.stringify(lvl)
			if idx ~= nil then args ..= `, {Proxy.stringify(idx)}` end
			Logger:add(`debug.getstack({args})`)
			return Proxy.new(`debug.getstack({args})`)
		end,
		setstack = function(lvl, idx, val)
			Logger:add(`debug.setstack({Proxy.stringify(lvl)}, {Proxy.stringify(idx)}, {Proxy.stringify(val)})`)
		end,
		getregistry = function() Logger:add("debug.getregistry()") return Proxy.new("debug.getregistry()") end,
		getmetatable = function(obj)
			Logger:add(`debug.getmetatable({Proxy.stringify(obj)})`)
			return Proxy.new(`debug.getmetatable({Proxy.stringify(obj)})`)
		end,
		setmetatable = function(obj, mt)
			Logger:add(`debug.setmetatable({Proxy.stringify(obj)}, {Proxy.stringify(mt)})`)
			return Proxy.new(`debug.setmetatable({Proxy.stringify(obj)}, {Proxy.stringify(mt)})`)
		end,
	}, { __index = function(_, k) return Proxy.new(`debug.{k}`) end })

	env.gethwid = function() Logger:add("gethwid()") return "00000000-0000-0000-0000-000000000000" end
	env.getexecutorname = function() Logger:add("getexecutorname()") return "Tracer" end
	env.setfpscap = function(cap) Logger:add(`setfpscap({Proxy.stringify(cap)})`) end
	env.getfpscap = function() Logger:add("getfpscap()") return 60 end
	env.setclipboard = function(t) Logger:add(`setclipboard({Proxy.stringify(t)})`) end
	env.toclipboard = env.setclipboard
	env.getclipboard = function() Logger:add("getclipboard()") return "" end

	env.isfile = function(p) Logger:add(`isfile({Proxy.stringify(p)})`) return false end
	env.isfolder = function(p) Logger:add(`isfolder({Proxy.stringify(p)})`) return false end
	env.readfile = function(p) Logger:add(`readfile({Proxy.stringify(p)})`) return "" end
	env.writefile = function(p, d) Logger:add(`writefile({Proxy.stringify(p)}, {Proxy.stringify(d)})`) end
	env.appendfile = function(p, d) Logger:add(`appendfile({Proxy.stringify(p)}, {Proxy.stringify(d)})`) end
	env.listfiles = function(p) Logger:add(`listfiles({Proxy.stringify(p)})`) return {} end
	env.makefolder = function(p) Logger:add(`makefolder({Proxy.stringify(p)})`) end
	env.delfile = function(p) Logger:add(`delfile({Proxy.stringify(p)})`) end
	env.delfolder = function(p) Logger:add(`delfolder({Proxy.stringify(p)})`) end
	env.loadfile = function(p) Logger:add(`loadfile({Proxy.stringify(p)})`) return Proxy.new(`loadfile({Proxy.stringify(p)})`) end
	env.getcustomasset = function(p) Logger:add(`getcustomasset({Proxy.stringify(p)})`) return Proxy.new(`getcustomasset({Proxy.stringify(p)})`) end

	env.getgc = function(t) Logger:add(`getgc({Proxy.stringify(t)})`) return {} end
	env.getreg = function() Logger:add("getreg()") return Proxy.new("getreg()") end
	env.getinstances = function() Logger:add("getinstances()") return Proxy.new("getinstances()") end
	env.getnilinstances = function() Logger:add("getnilinstances()") return Proxy.new("getnilinstances()") end
	env.getscripts = function() Logger:add("getscripts()") return Proxy.new("getscripts()") end
	env.getrunningscripts = function() Logger:add("getrunningscripts()") return Proxy.new("getrunningscripts()") end
	env.getloadedmodules = function() Logger:add("getloadedmodules()") return Proxy.new("getloadedmodules()") end
	env.getconnections = function(s) Logger:add(`getconnections({Proxy.stringify(s)})`) return {} end

	env.queue_on_teleport = function(s) Logger:add(`queue_on_teleport({Proxy.stringify(s)})`) end
	env.queueonteleport = env.queue_on_teleport
	env.request = function(o) Logger:add(`request({Proxy.stringify(o)})`) return Proxy.new(`request({Proxy.stringify(o)})`) end
	env.http_request = env.request

	env.setfflag = function(n, v) Logger:add(`setfflag({Proxy.stringify(n)}, {Proxy.stringify(v)})`) end
	env.getfflag = function(n) Logger:add(`getfflag({Proxy.stringify(n)})`) return Proxy.new(`getfflag({Proxy.stringify(n)})`) end

	env.mouse1click = function() Logger:add("mouse1click()") end
	env.mouse1press = function() Logger:add("mouse1press()") end
	env.mouse1release = function() Logger:add("mouse1release()") end
	env.mouse2click = function() Logger:add("mouse2click()") end
	env.mousemoverel = function(x, y) Logger:add(`mousemoverel({Proxy.stringify(x)}, {Proxy.stringify(y)})`) end
	env.mousemoveabs = function(x, y) Logger:add(`mousemoveabs({Proxy.stringify(x)}, {Proxy.stringify(y)})`) end
	env.keypress = function(k) Logger:add(`keypress({Proxy.stringify(k)})`) end
	env.keyrelease = function(k) Logger:add(`keyrelease({Proxy.stringify(k)})`) end

	env.task = setmetatable({
		wait = function(t: any?)
			local arg = if t then Proxy.stringify(t) else ""
			Logger:add(`task.wait({arg})`)
			task.wait(tonumber(t) or 0)
			return Proxy.new(`task.wait({arg})`)
		end,
		spawn = function(f: any, ...: any)
			local args = { Proxy.stringify(f) }
			for _, v in {...} do table.insert(args, Proxy.stringify(v)) end
			Logger:add(`task.spawn({table.concat(args, ", ")})`)
			return Proxy.new(`task.spawn({table.concat(args, ", ")})`)
		end,
	}, { __index = function(_, k) return Proxy.new(`task.{k}`) end })

	env.Drawing = setmetatable({
		new = function(c) Logger:add(`Drawing.new({Proxy.stringify(c)})`) return Proxy.new(`Drawing.new({Proxy.stringify(c)})`) end,
	}, { __index = function(_, k) return Proxy.new(`Drawing.{k}`) end })

	env.table = setmetatable({
		new = function(...: any) return Proxy.table({...}) end,
	}, { __index = function(_, k) return Proxy.new(`table.{k}`) end })

	env.string = setmetatable({}, { __index = function(_, k) return Proxy.new(`string.{k}`) end })
	env.math = setmetatable({}, { __index = function(_, k) return Proxy.new(`math.{k}`) end })
	env.bit32 = setmetatable({}, { __index = function(_, k) return Proxy.new(`bit32.{k}`) end })
	env.coroutine = setmetatable({}, { __index = function(_, k) return Proxy.new(`coroutine.{k}`) end })
	env.os = setmetatable({}, { __index = function(_, k) return Proxy.new(`os.{k}`) end })
	env.crypt = setmetatable({}, { __index = function(_, k) return Proxy.new(`crypt.{k}`) end })
	env.syn = setmetatable({}, { __index = function(_, k) return Proxy.new(`syn.{k}`) end })
	env.fluxus = setmetatable({}, { __index = function(_, k) return Proxy.new(`fluxus.{k}`) end })
	env.Krnl = setmetatable({}, { __index = function(_, k) return Proxy.new(`Krnl.{k}`) end })

	setmetatable(env, {
		__index = function(_, key) return Proxy.new(tostring(key)) end,
		__newindex = function(_, key, value) Logger:add(`{tostring(key)} = {Proxy.stringify(value)}`) end,
	})

	return env
end

return Sandbox
