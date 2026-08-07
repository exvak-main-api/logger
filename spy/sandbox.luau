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

	-- Environments
	env.getgenv = function() Logger:add("getgenv()") return Proxy.new("getgenv()") end
	env.getrenv = function() Logger:add("getrenv()") return Proxy.new("getrenv()") end
	env.getfenv = function(target: any?)
		local arg = if target ~= nil then Proxy.stringify(target) else ""
		Logger:add(`getfenv({arg})`)
		return Proxy.new(`getfenv({arg})`)
	end
	env.setfenv = function(target: any, e: any)
		Logger:add(`setfenv({Proxy.stringify(target)}, {Proxy.stringify(e)})`)
		return Proxy.new(`setfenv({Proxy.stringify(target)}, {Proxy.stringify(e)})`)
	end
	env.getsenv = function(scr: any)
		Logger:add(`getsenv({Proxy.stringify(scr)})`)
		return Proxy.new(`getsenv({Proxy.stringify(scr)})`)
	end
	env.gettenv = function(th: any?)
		local arg = if th ~= nil then Proxy.stringify(th) else ""
		Logger:add(`gettenv({arg})`)
		return Proxy.new(`gettenv({arg})`)
	end
	env.identifyexecutor = function() Logger:add("identifyexecutor()") return "Tracer", "1.0" end
	env.getexecutorname = function() Logger:add("getexecutorname()") return "Tracer" end

	-- Closures
	env.hookfunction = function(old, new)
		Logger:add(`hookfunction({Proxy.stringify(old)}, {Proxy.stringify(new)})`)
		return Proxy.new(`hookfunction({Proxy.stringify(old)}, {Proxy.stringify(new)})`)
	end
	env.replaceclosure = env.hookfunction
	env.hookfunc = env.hookfunction
	env.hookmetamethod = function(obj, method, hook)
		Logger:add(`hookmetamethod({Proxy.stringify(obj)}, {Proxy.stringify(method)}, {Proxy.stringify(hook)})`)
		return Proxy.new(`hookmetamethod({Proxy.stringify(obj)}, {Proxy.stringify(method)}, {Proxy.stringify(hook)})`)
	end
	env.newcclosure = function(fn)
		Logger:add(`newcclosure({Proxy.stringify(fn)})`)
		return Proxy.new(`newcclosure({Proxy.stringify(fn)})`)
	end
	env.clonefunction = function(fn)
		Logger:add(`clonefunction({Proxy.stringify(fn)})`)
		return Proxy.new(`clonefunction({Proxy.stringify(fn)})`)
	end
	env.restorefunction = function(fn) Logger:add(`restorefunction({Proxy.stringify(fn)})`) end
	env.isfunctionhooked = function(fn) Logger:add(`isfunctionhooked({Proxy.stringify(fn)})`) return false end
	env.iscclosure = function(fn) Logger:add(`iscclosure({Proxy.stringify(fn)})`) return false end
	env.islclosure = function(fn) Logger:add(`islclosure({Proxy.stringify(fn)})`) return true end
	env.isexecutorclosure = function(fn) Logger:add(`isexecutorclosure({Proxy.stringify(fn)})`) return true end
	env.checkclosure = env.isexecutorclosure
	env.isourclosure = env.isexecutorclosure
	env.comparefunctions = function(a, b) Logger:add(`comparefunctions({Proxy.stringify(a)}, {Proxy.stringify(b)})`) return false end
	env.compareclosures = env.comparefunctions
	env.getfunctionhash = function(fn) Logger:add(`getfunctionhash({Proxy.stringify(fn)})`) return Proxy.new(`getfunctionhash({Proxy.stringify(fn)})`) end
	env.checkcaller = function() Logger:add("checkcaller()") return false end
	env.getcallingscript = function() Logger:add("getcallingscript()") return Proxy.new("getcallingscript()") end

	-- Metatable
	env.getrawmetatable = function(obj) Logger:add(`getrawmetatable({Proxy.stringify(obj)})`) return Proxy.new(`getrawmetatable({Proxy.stringify(obj)})`) end
	env.setrawmetatable = function(obj, mt) Logger:add(`setrawmetatable({Proxy.stringify(obj)}, {Proxy.stringify(mt)})`) return Proxy.new(`setrawmetatable({Proxy.stringify(obj)}, {Proxy.stringify(mt)})`) end
	env.setreadonly = function(t, ro) Logger:add(`setreadonly({Proxy.stringify(t)}, {Proxy.stringify(ro)})`) end
	env.isreadonly = function(t) Logger:add(`isreadonly({Proxy.stringify(t)})`) return false end
	env.getnamecallmethod = function() Logger:add("getnamecallmethod()") return Proxy.new("getnamecallmethod()") end
	env.setnamecallmethod = function(m) Logger:add(`setnamecallmethod({Proxy.stringify(m)})`) end

	-- Identity
	env.getthreadidentity = function() Logger:add("getthreadidentity()") return 8 end
	env.setthreadidentity = function(id) Logger:add(`setthreadidentity({Proxy.stringify(id)})`) end
	env.getidentity = env.getthreadidentity
	env.setidentity = env.setthreadidentity

	-- Instances
	env.Instance = { new = function(class: any, parent: any?)
		local args = Proxy.stringify(class)
		if parent then args ..= `, {Proxy.stringify(parent)}` end
		Logger:add(`Instance.new({args})`)
		return Proxy.new(`Instance.new({args})`)
	end }
	env.gethui = function() Logger:add("gethui()") return Proxy.new("gethui()") end
	env.cloneref = function(obj) Logger:add(`cloneref({Proxy.stringify(obj)})`) return Proxy.new(`cloneref({Proxy.stringify(obj)})`) end
	env.compareinstances = function(a, b) Logger:add(`compareinstances({Proxy.stringify(a)}, {Proxy.stringify(b)})`) return false end
	env.gethiddenproperty = function(obj, prop) Logger:add(`gethiddenproperty({Proxy.stringify(obj)}, {Proxy.stringify(prop)})`) return Proxy.new(`gethiddenproperty({Proxy.stringify(obj)}, {Proxy.stringify(prop)})`), true end
	env.sethiddenproperty = function(obj, prop, value) Logger:add(`sethiddenproperty({Proxy.stringify(obj)}, {Proxy.stringify(prop)}, {Proxy.stringify(value)})`) end
	env.setscriptable = function(obj, prop, s) Logger:add(`setscriptable({Proxy.stringify(obj)}, {Proxy.stringify(prop)}, {Proxy.stringify(s)})`) end
	env.firesignal = function(signal, ...) local a={Proxy.stringify(signal)} for _,v in {...} do table.insert(a,Proxy.stringify(v)) end Logger:add(`firesignal({table.concat(a,", ")})`) end
	env.replicatesignal = function(signal, ...) local a={Proxy.stringify(signal)} for _,v in {...} do table.insert(a,Proxy.stringify(v)) end Logger:add(`replicatesignal({table.concat(a,", ")})`) end
	env.fireclickdetector = function(d, dist) local a=Proxy.stringify(d) if dist then a ..= `, {Proxy.stringify(dist)}` end Logger:add(`fireclickdetector({a})`) end
	env.fireproximityprompt = function(p) Logger:add(`fireproximityprompt({Proxy.stringify(p)})`) end
	env.firetouchinterest = function(part, to, t) Logger:add(`firetouchinterest({Proxy.stringify(part)}, {Proxy.stringify(to)}, {Proxy.stringify(t)})`) end
	env.isnetworkowner = function(p) Logger:add(`isnetworkowner({Proxy.stringify(p)})`) return true end
	env.setsimulationradius = function(r, m) local a=Proxy.stringify(r) if m then a ..= `, {Proxy.stringify(m)}` end Logger:add(`setsimulationradius({a})`) end

	-- Scripts
	env.getscriptbytecode = function(s) Logger:add(`getscriptbytecode({Proxy.stringify(s)})`) return Proxy.new(`getscriptbytecode({Proxy.stringify(s)})`) end
	env.getscriptclosure = function(s) Logger:add(`getscriptclosure({Proxy.stringify(s)})`) return Proxy.new(`getscriptclosure({Proxy.stringify(s)})`) end
	env.getscripthash = function(s) Logger:add(`getscripthash({Proxy.stringify(s)})`) return Proxy.new(`getscripthash({Proxy.stringify(s)})`) end
	env.getscripts = function() Logger:add("getscripts()") return Proxy.new("getscripts()") end
	env.getrunningscripts = function() Logger:add("getrunningscripts()") return Proxy.new("getrunningscripts()") end
	env.getloadedmodules = function(e) local a=if e~=nil then Proxy.stringify(e) else "" Logger:add(`getloadedmodules({a})`) return Proxy.new(`getloadedmodules({a})`) end

	-- GC
	env.getgc = function(t) Logger:add(`getgc({Proxy.stringify(t)})`) return {} end
	env.filtergc = function(ft, o) Logger:add(`filtergc({Proxy.stringify(ft)}, {Proxy.stringify(o)})`) return {} end
	env.getreg = function() Logger:add("getreg()") return Proxy.new("getreg()") end
	env.getinstances = function() Logger:add("getinstances()") return Proxy.new("getinstances()") end
	env.getnilinstances = function() Logger:add("getnilinstances()") return Proxy.new("getnilinstances()") end
	env.getconnections = function(s) Logger:add(`getconnections({Proxy.stringify(s)})`) return {} end

	env.protectgui = function(o) Logger:add(`protectgui({Proxy.stringify(o)})`) end
	env.unprotectgui = function(o) Logger:add(`unprotectgui({Proxy.stringify(o)})`) end
	env.protect_gui = env.protectgui
	env.unprotect_gui = env.unprotectgui

	env.gethwid = function() Logger:add("gethwid()") return "00000000-0000-0000-0000-000000000000" end
	env.setfpscap = function(c) Logger:add(`setfpscap({Proxy.stringify(c)})`) end
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

	env.request = function(o) Logger:add(`request({Proxy.stringify(o)})`) return Proxy.new(`request({Proxy.stringify(o)})`) end
	env.http_request = env.request
	env.http = setmetatable({ request = env.request }, { __index = function(_, k) return Proxy.new(`http.{k}`) end })
	env.queue_on_teleport = function(s) Logger:add(`queue_on_teleport({Proxy.stringify(s)})`) end
	env.queueonteleport = env.queue_on_teleport
	env.setfflag = function(n, v) Logger:add(`setfflag({Proxy.stringify(n)}, {Proxy.stringify(v)})`) end
	env.getfflag = function(n) Logger:add(`getfflag({Proxy.stringify(n)})`) return Proxy.new(`getfflag({Proxy.stringify(n)})`) end
	env.saveinstance = function(...) local a={} for _,v in {...} do table.insert(a,Proxy.stringify(v)) end Logger:add(`saveinstance({table.concat(a,", ")})`) end
	env.messagebox = function(t,c,f) Logger:add(`messagebox({Proxy.stringify(t)}, {Proxy.stringify(c)}, {Proxy.stringify(f)})`) return 1 end
	env.isrbxactive = function() Logger:add("isrbxactive()") return true end
	env.iswindowactive = env.isrbxactive

	env.mouse1click = function() Logger:add("mouse1click()") end
	env.mouse1press = function() Logger:add("mouse1press()") end
	env.mouse1release = function() Logger:add("mouse1release()") end
	env.mouse2click = function() Logger:add("mouse2click()") end
	env.mousemoverel = function(x,y) Logger:add(`mousemoverel({Proxy.stringify(x)}, {Proxy.stringify(y)})`) end
	env.mousemoveabs = function(x,y) Logger:add(`mousemoveabs({Proxy.stringify(x)}, {Proxy.stringify(y)})`) end
	env.mousescroll = function(d) Logger:add(`mousescroll({Proxy.stringify(d)})`) end
	env.keypress = function(k) Logger:add(`keypress({Proxy.stringify(k)})`) end
	env.keyrelease = function(k) Logger:add(`keyrelease({Proxy.stringify(k)})`) end

	env.lz4compress = function(d) Logger:add(`lz4compress({Proxy.stringify(d)})`) return Proxy.new(`lz4compress({Proxy.stringify(d)})`) end
	env.lz4decompress = function(d,s) Logger:add(`lz4decompress({Proxy.stringify(d)}, {Proxy.stringify(s)})`) return Proxy.new(`lz4decompress({Proxy.stringify(d)}, {Proxy.stringify(s)})`) end

	env.debug = setmetatable({
		traceback = function(...) local a={} for _,v in {...} do table.insert(a,Proxy.stringify(v)) end Logger:add(`debug.traceback({table.concat(a,", ")})`) return Proxy.new("debug.traceback(...)") end,
		info = function(...) local a={} for _,v in {...} do table.insert(a,Proxy.stringify(v)) end Logger:add(`debug.info({table.concat(a,", ")})`) return Proxy.new("debug.info(...)") end,
		getinfo = function(...) local a={} for _,v in {...} do table.insert(a,Proxy.stringify(v)) end Logger:add(`debug.getinfo({table.concat(a,", ")})`) return Proxy.new("debug.getinfo(...)") end,
		getupvalue = function(fn,i) Logger:add(`debug.getupvalue({Proxy.stringify(fn)}, {Proxy.stringify(i)})`) return Proxy.new("debug.getupvalue(...)") end,
		setupvalue = function(fn,i,v) Logger:add(`debug.setupvalue({Proxy.stringify(fn)}, {Proxy.stringify(i)}, {Proxy.stringify(v)})`) end,
		getupvalues = function(fn) Logger:add(`debug.getupvalues({Proxy.stringify(fn)})`) return Proxy.new("debug.getupvalues(...)") end,
		getconstant = function(fn,i) Logger:add(`debug.getconstant({Proxy.stringify(fn)}, {Proxy.stringify(i)})`) return Proxy.new("debug.getconstant(...)") end,
		setconstant = function(fn,i,v) Logger:add(`debug.setconstant({Proxy.stringify(fn)}, {Proxy.stringify(i)}, {Proxy.stringify(v)})`) end,
		getconstants = function(fn) Logger:add(`debug.getconstants({Proxy.stringify(fn)})`) return Proxy.new("debug.getconstants(...)") end,
		getproto = function(fn,i,a) local args=`{Proxy.stringify(fn)}, {Proxy.stringify(i)}` if a~=nil then args ..= `, {Proxy.stringify(a)}` end Logger:add(`debug.getproto({args})`) return Proxy.new("debug.getproto(...)") end,
		getprotos = function(fn) Logger:add(`debug.getprotos({Proxy.stringify(fn)})`) return Proxy.new("debug.getprotos(...)") end,
		getstack = function(l,i) local a=Proxy.stringify(l) if i~=nil then a ..= `, {Proxy.stringify(i)}` end Logger:add(`debug.getstack({a})`) return Proxy.new("debug.getstack(...)") end,
		setstack = function(l,i,v) Logger:add(`debug.setstack({Proxy.stringify(l)}, {Proxy.stringify(i)}, {Proxy.stringify(v)})`) end,
		getregistry = function() Logger:add("debug.getregistry()") return Proxy.new("debug.getregistry()") end,
		getmetatable = function(o) Logger:add(`debug.getmetatable({Proxy.stringify(o)})`) return Proxy.new("debug.getmetatable(...)") end,
		setmetatable = function(o,m) Logger:add(`debug.setmetatable({Proxy.stringify(o)}, {Proxy.stringify(m)})`) return Proxy.new("debug.setmetatable(...)") end,
	}, { __index = function(_,k) return Proxy.new(`debug.{k}`) end })

	env.Drawing = setmetatable({ new = function(c) Logger:add(`Drawing.new({Proxy.stringify(c)})`) return Proxy.new(`Drawing.new({Proxy.stringify(c)})`) end }, { __index = function(_,k) return Proxy.new(`Drawing.{k}`) end })
	env.WebSocket = setmetatable({ connect = function(u) Logger:add(`WebSocket.connect({Proxy.stringify(u)})`) return Proxy.new(`WebSocket.connect({Proxy.stringify(u)})`) end }, { __index = function(_,k) return Proxy.new(`WebSocket.{k}`) end })
	env.crypt = setmetatable({
		base64encode = function(s) Logger:add(`crypt.base64encode({Proxy.stringify(s)})`) return Proxy.new("crypt.base64encode(...)") end,
		base64decode = function(s) Logger:add(`crypt.base64decode({Proxy.stringify(s)})`) return Proxy.new("crypt.base64decode(...)") end,
	}, { __index = function(_,k) return Proxy.new(`crypt.{k}`) end })
	env.base64 = setmetatable({
		encode = function(s) Logger:add(`base64.encode({Proxy.stringify(s)})`) return Proxy.new("base64.encode(...)") end,
		decode = function(s) Logger:add(`base64.decode({Proxy.stringify(s)})`) return Proxy.new("base64.decode(...)") end,
	}, { __index = function(_,k) return Proxy.new(`base64.{k}`) end })

	env.syn = setmetatable({
		request = env.request,
		queue_on_teleport = env.queue_on_teleport,
		protect_gui = env.protectgui,
		unprotect_gui = env.unprotectgui,
		set_thread_identity = env.setthreadidentity,
		get_thread_identity = env.getthreadidentity,
		crypt = env.crypt,
		oth = setmetatable({
			hook = env.hookfunction,
			hook_metamethod = env.hookmetamethod,
		}, { __index = function(_,k) return Proxy.new(`syn.oth.{k}`) end }),
	}, { __index = function(_,k) return Proxy.new(`syn.{k}`) end })
	env.oth = env.syn.oth
	env.fluxus = setmetatable({}, { __index = function(_,k) return Proxy.new(`fluxus.{k}`) end })
	env.Krnl = setmetatable({}, { __index = function(_,k) return Proxy.new(`Krnl.{k}`) end })

	env.pairs = Proxy.pairs
	env.ipairs = Proxy.ipairs
	env.typeof = function(v) Logger:add(`typeof({Proxy.stringify(v)})`) return "Instance" end
	env.loadstring = function(src, chunk)
		local a = Proxy.stringify(src)
		if chunk then a ..= `, {Proxy.stringify(chunk)}` end
		Logger:add(`loadstring({a})`)
		return Proxy.new(`loadstring({a})`)
	end

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
	}, { __index = function(_,k) return Proxy.new(`task.{k}`) end })

	env.table = setmetatable({ new = function(...: any) return Proxy.table({...}) end }, { __index = function(_,k) return Proxy.new(`table.{k}`) end })
	env.string = setmetatable({}, { __index = function(_,k) return Proxy.new(`string.{k}`) end })
	env.math = setmetatable({}, { __index = function(_,k) return Proxy.new(`math.{k}`) end })
	env.bit32 = setmetatable({}, { __index = function(_,k) return Proxy.new(`bit32.{k}`) end })
	env.coroutine = setmetatable({}, { __index = function(_,k) return Proxy.new(`coroutine.{k}`) end })
	env.os = setmetatable({}, { __index = function(_,k) return Proxy.new(`os.{k}`) end })

	setmetatable(env, {
		__index = function(_, key) return Proxy.new(tostring(key)) end,
		__newindex = function(_, key, value) Logger:add(`{tostring(key)} = {Proxy.stringify(value)}`) end,
	})

	return env
end

return Sandbox
