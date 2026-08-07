local Proxy = require("./proxy")
local Logger = require("./logger")
local task = require("@lune/task")

local Sandbox = {}

function Sandbox.create()
	local env = {}
	env.game = Proxy.new("game")
	env.workspace = Proxy.new("workspace")
	env.script = Proxy.new("script")

	local function W(name)
		return function(...)
			local a = {}
			for i, v in { ... } do a[i] = Proxy.stringify(v) end
			Logger:add(name .. "(" .. table.concat(a, ", ") .. ")")
			return Proxy.new(name .. "(...)")
		end
	end

	env.print = function(...)
		local a = table.pack(...)
		local p = {}
		for i = 1, a.n do p[i] = Proxy.stringify(a[i]) end
		Logger:add("print(" .. table.concat(p, ", ") .. ")")
	end
	env.warn = function(...)
		local a = table.pack(...)
		local p = {}
		for i = 1, a.n do p[i] = Proxy.stringify(a[i]) end
		Logger:warn("warn(" .. table.concat(p, ", ") .. ")")
	end

	-- Core UNC
	for _, n in {
		"getgenv", "getrenv", "getreg", "getgc", "filtergc", "getsenv", "gettenv", "getmenv",
		"getfenv", "setfenv", "hookfunction", "hookmetamethod", "newcclosure", "clonefunction",
		"restorefunction", "isfunctionhooked", "iscclosure", "islclosure", "isexecutorclosure",
		"checkclosure", "isourclosure", "comparefunctions", "getfunctionhash", "checkcaller",
		"getcallingscript", "getrawmetatable", "setrawmetatable", "setreadonly", "isreadonly",
		"getnamecallmethod", "setnamecallmethod", "getthreadidentity", "setthreadidentity",
		"getidentity", "setidentity", "gethui", "cloneref", "compareinstances",
		"gethiddenproperty", "sethiddenproperty", "setscriptable", "isscriptable",
		"getcallbackvalue", "firesignal", "replicatesignal", "fireclickdetector",
		"fireproximityprompt", "firetouchinterest", "isnetworkowner", "setsimulationradius",
		"getscriptbytecode", "getscriptclosure", "getscripthash", "getscripts",
		"getrunningscripts", "getloadedmodules", "getinstances", "getnilinstances",
		"getconnections", "protectgui", "unprotectgui", "gethwid", "setfpscap", "getfpscap",
		"setclipboard", "toclipboard", "getclipboard", "isfile", "isfolder", "readfile",
		"writefile", "appendfile", "listfiles", "makefolder", "delfile", "delfolder",
		"loadfile", "getcustomasset", "request", "http_request", "queue_on_teleport",
		"setfflag", "getfflag", "saveinstance", "messagebox", "isrbxactive", "iswindowactive",
		"mouse1click", "mouse1press", "mouse1release", "mouse2click", "mousemoverel",
		"mousemoveabs", "mousescroll", "keypress", "keyrelease", "keytap",
		"lz4compress", "lz4decompress", "zstdcompress", "zstddecompress",
		"rconsoleclear", "rconsolecreate", "rconsoledestroy", "rconsoleprint", "rconsoleinput",
		"rconsolesettitle", "cleardrawcache", "getrenderproperty", "setrenderproperty",
		"isrenderobj", "decompile", "protectfunction", "newlclosure", "clear_teleport_queue",
		"getactors", "getcurrentactor", "run_on_actor", "hooksignal", "restoresignal",
		"getobjects", "HttpGet", "loadstring", "identifyexecutor", "getexecutorname",
	} do
		env[n] = W(n)
	end

	env.identifyexecutor = function() Logger:add("identifyexecutor()") return "Tracer", "1.0" end
	env.gethwid = function() Logger:add("gethwid()") return "00000000-0000-0000-0000-000000000000" end
	env.checkcaller = function() Logger:add("checkcaller()") return false end
	env.iscclosure = function(f) Logger:add("iscclosure(...)") return false end
	env.islclosure = function(f) Logger:add("islclosure(...)") return true end
	env.isexecutorclosure = function(f) Logger:add("isexecutorclosure(...)") return true end
	env.getthreadidentity = function() Logger:add("getthreadidentity()") return 8 end
	env.getfpscap = function() Logger:add("getfpscap()") return 60 end
	env.isreadonly = function(t) Logger:add("isreadonly(...)") return false end
	env.isrbxactive = function() Logger:add("isrbxactive()") return true end
	env.getclipboard = function() Logger:add("getclipboard()") return "" end
	env.isfile = function(p) Logger:add("isfile(...)") return false end
	env.getgc = function(t) Logger:add("getgc(...)") return {} end
	env.getconnections = function(s) Logger:add("getconnections(...)") return {} end
	env.decompile = function(s) Logger:add("decompile(...)") return "-- decompiled" end
	env.messagebox = function(...) Logger:add("messagebox(...)") return 1 end

	env.hookfunc = env.hookfunction
	env.replaceclosure = env.hookfunction
	env.clonefunc = env.clonefunction
	env.getidentity = env.getthreadidentity
	env.setidentity = env.setthreadidentity
	env.protect_gui = env.protectgui
	env.queueonteleport = env.queue_on_teleport
	env.oth = { hook = env.hookfunction, hook_metamethod = env.hookmetamethod }

	env.Instance = {
		new = function(class, parent)
			local a = Proxy.stringify(class)
			if parent then a ..= ", " .. Proxy.stringify(parent) end
			Logger:add("Instance.new(" .. a .. ")")
			return Proxy.new("Instance.new(" .. a .. ")")
		end,
	}

	env.cache = setmetatable({
		iscached = function(o) Logger:add("cache.iscached(...)") return false end,
		invalidate = function(o) Logger:add("cache.invalidate(...)") end,
		replace = function(a, b) Logger:add("cache.replace(...)") end,
	}, { __index = function(_, k) return Proxy.new("cache." .. k) end })

	env.debug = setmetatable({}, {
		__index = function(_, k)
			return function(...)
				local a = {}
				for i, v in { ... } do a[i] = Proxy.stringify(v) end
				Logger:add("debug." .. k .. "(" .. table.concat(a, ", ") .. ")")
				return Proxy.new("debug." .. k .. "(...)")
			end
		end,
	})

	env.Drawing = setmetatable({
		new = function(c)
			Logger:add("Drawing.new(" .. Proxy.stringify(c) .. ")")
			return Proxy.new("Drawing.new(...)")
		end,
	}, { __index = function(_, k) return Proxy.new("Drawing." .. k) end })

	env.WebSocket = setmetatable({
		connect = function(u)
			Logger:add("WebSocket.connect(" .. Proxy.stringify(u) .. ")")
			return Proxy.new("WebSocket.connect(...)")
		end,
	}, { __index = function(_, k) return Proxy.new("WebSocket." .. k) end })

	env.crypt = setmetatable({}, {
		__index = function(_, k)
			return function(...)
				Logger:add("crypt." .. k .. "(...)")
				return Proxy.new("crypt." .. k .. "(...)")
			end
		end,
	})

	env.syn = setmetatable({
		request = env.request,
		queue_on_teleport = env.queue_on_teleport,
		protect_gui = env.protectgui,
		oth = env.oth,
		crypt = env.crypt,
	}, { __index = function(_, k) return Proxy.new("syn." .. k) end })

	env.pairs = Proxy.pairs
	env.ipairs = Proxy.ipairs
	env.task = setmetatable({
		wait = function(t)
			local arg = if t then Proxy.stringify(t) else ""
			Logger:add("task.wait(" .. arg .. ")")
			task.wait(tonumber(t) or 0)
			return Proxy.new("task.wait(" .. arg .. ")")
		end,
		spawn = function(f, ...)
			Logger:add("task.spawn(...)")
			return Proxy.new("task.spawn(...)")
		end,
	}, { __index = function(_, k) return Proxy.new("task." .. k) end })

	env.table = setmetatable({ new = function(...) return Proxy.table({ ... }) end }, { __index = function(_, k) return Proxy.new("table." .. k) end })
	env.string = setmetatable({}, { __index = function(_, k) return Proxy.new("string." .. k) end })
	env.math = setmetatable({}, { __index = function(_, k) return Proxy.new("math." .. k) end })
	env.bit32 = setmetatable({}, { __index = function(_, k) return Proxy.new("bit32." .. k) end })
	env.http = setmetatable({ request = env.request }, { __index = function(_, k) return Proxy.new("http." .. k) end })

	setmetatable(env, {
		__index = function(_, key) return Proxy.new(tostring(key)) end,
		__newindex = function(_, key, value)
			Logger:add(tostring(key) .. " = " .. Proxy.stringify(value))
		end,
	})

	return env
end

return Sandbox
