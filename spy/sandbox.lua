-- spy/sandbox.lua
local Proxy  = require("./proxy")
local Logger = require("./logger")

local Sandbox = {}

function Sandbox.create()
    local env = {}

    env.game      = Proxy.new("game")
    env.workspace = Proxy.new("workspace")
    env.script    = Proxy.new("script")

    env.print = function(...)
        local args = table.pack(...)
        local parts = {}
        for i = 1, args.n do
            parts[i] = Proxy.stringify(args[i])
        end
        Logger:add("print(" .. table.concat(parts, ", ") .. ")")
    end

    env.warn = function(...)
        local args = table.pack(...)
        local parts = {}
        for i = 1, args.n do
            parts[i] = Proxy.stringify(args[i])
        end
        Logger:warn("warn(" .. table.concat(parts, ", ") .. ")")
    end

    env.error = function(...)
        local args = table.pack(...)
        local parts = {}
        for i = 1, args.n do
            parts[i] = Proxy.stringify(args[i])
        end
        Logger:error("error(" .. table.concat(parts, ", ") .. ")")
    end

    env.getgenv = function()
        Logger:add("getgenv()")
        return Proxy.new("getgenv()")
    end

    env.getrenv = function()
        Logger:add("getrenv()")
        return Proxy.new("getrenv()")
    end

    env.getsenv = function(scr)
        Logger:add("getsenv(" .. Proxy.stringify(scr) .. ")")
        return Proxy.new("getsenv(" .. Proxy.stringify(scr) .. ")")
    end

    env.getfenv = function(lvl)
        Logger:add("getfenv(" .. (lvl and Proxy.stringify(lvl) or "") .. ")")
        return Proxy.new("getfenv(" .. (lvl and Proxy.stringify(lvl) or "") .. ")")
    end

    env.setfenv = function(f, e)
        Logger:add("setfenv(" .. Proxy.stringify(f) .. ", " .. Proxy.stringify(e) .. ")")
        return Proxy.new("setfenv(" .. Proxy.stringify(f) .. ", " .. Proxy.stringify(e) .. ")")
    end

    env.identifyexecutor = function()
        Logger:add("identifyexecutor()")
        return "Tracer", "1.0"
    end

    env.typeof = function(v)
        Logger:add("typeof(" .. Proxy.stringify(v) .. ")")
        return "Instance"
    end

    env.type = function(v)
        Logger:add("type(" .. Proxy.stringify(v) .. ")")
        return "userdata"
    end

    env.tonumber = function(v, base)
        local args = Proxy.stringify(v)
        if base then args = args .. ", " .. Proxy.stringify(base) end
        Logger:add("tonumber(" .. args .. ")")
        return Proxy.new("tonumber(" .. args .. ")")
    end

    env.tostring = function(v)
        Logger:add("tostring(" .. Proxy.stringify(v) .. ")")
        return Proxy.stringify(v)
    end

    env.loadstring = function(src, chunk)
        local args = Proxy.stringify(src)
        if chunk then args = args .. ", " .. Proxy.stringify(chunk) end
        Logger:add("loadstring(" .. args .. ")")
        return Proxy.new("loadstring(" .. args .. ")")
    end

    env.Instance = {
        new = function(class, parent)
            local args = Proxy.stringify(class)
            if parent then args = args .. ", " .. Proxy.stringify(parent) end
            Logger:add("Instance.new(" .. args .. ")")
            return Proxy.new("Instance.new(" .. args .. ")")
        end
    }

    env.pairs  = Proxy.pairs
    env.ipairs = Proxy.ipairs

    env.next = function(t, k)
        local args = Proxy.stringify(t)
        if k then args = args .. ", " .. Proxy.stringify(k) end
        Logger:add("next(" .. args .. ")")
        return Proxy.new("next(" .. args .. ")")
    end

    env.select = function(idx, ...)
        local args = { Proxy.stringify(idx) }
        for i, v in ipairs({...}) do
            args[#args + 1] = Proxy.stringify(v)
        end
        Logger:add("select(" .. table.concat(args, ", ") .. ")")
        return Proxy.new("select(" .. table.concat(args, ", ") .. ")")
    end

    env.unpack = function(t, i, j)
        local args = Proxy.stringify(t)
        if i then args = args .. ", " .. Proxy.stringify(i) end
        if j then args = args .. ", " .. Proxy.stringify(j) end
        Logger:add("unpack(" .. args .. ")")
        return Proxy.new("unpack(" .. args .. ")")
    end

    env.pcall = function(f, ...)
        local args = { Proxy.stringify(f) }
        for i, v in ipairs({...}) do
            args[#args + 1] = Proxy.stringify(v)
        end
        Logger:add("pcall(" .. table.concat(args, ", ") .. ")")
        return true, Proxy.new("pcall(" .. table.concat(args, ", ") .. ")")
    end

    env.xpcall = function(f, err, ...)
        local args = { Proxy.stringify(f), Proxy.stringify(err) }
        for i, v in ipairs({...}) do
            args[#args + 1] = Proxy.stringify(v)
        end
        Logger:add("xpcall(" .. table.concat(args, ", ") .. ")")
        return true, Proxy.new("xpcall(" .. table.concat(args, ", ") .. ")")
    end

    env.table = setmetatable({
        new = function(...)
            return Proxy.table({...})
        end,
        insert = function(t, ...)
            local args = { Proxy.stringify(t) }
            for i, v in ipairs({...}) do
                args[#args + 1] = Proxy.stringify(v)
            end
            Logger:add("table.insert(" .. table.concat(args, ", ") .. ")")
        end,
        remove = function(t, pos)
            local args = Proxy.stringify(t)
            if pos then args = args .. ", " .. Proxy.stringify(pos) end
            Logger:add("table.remove(" .. args .. ")")
        end,
        concat = function(t, sep, i, j)
            local args = Proxy.stringify(t)
            if sep then args = args .. ", " .. Proxy.stringify(sep) end
            if i then args = args .. ", " .. Proxy.stringify(i) end
            if j then args = args .. ", " .. Proxy.stringify(j) end
            Logger:add("table.concat(" .. args .. ")")
            return Proxy.new("table.concat(" .. args .. ")")
        end,
        sort = function(t, comp)
            local args = Proxy.stringify(t)
            if comp then args = args .. ", " .. Proxy.stringify(comp) end
            Logger:add("table.sort(" .. args .. ")")
        end,
        find = function(t, val, init)
            local args = Proxy.stringify(t) .. ", " .. Proxy.stringify(val)
            if init then args = args .. ", " .. Proxy.stringify(init) end
            Logger:add("table.find(" .. args .. ")")
            return Proxy.new("table.find(" .. args .. ")")
        end,
        clear = function(t)
            Logger:add("table.clear(" .. Proxy.stringify(t) .. ")")
        end,
        clone = function(t)
            Logger:add("table.clone(" .. Proxy.stringify(t) .. ")")
            return Proxy.new("table.clone(" .. Proxy.stringify(t) .. ")")
        end,
        freeze = function(t)
            Logger:add("table.freeze(" .. Proxy.stringify(t) .. ")")
            return Proxy.new("table.freeze(" .. Proxy.stringify(t) .. ")")
        end,
        isfrozen = function(t)
            Logger:add("table.isfrozen(" .. Proxy.stringify(t) .. ")")
            return false
        end,
    }, {
        __index = function(_, key)
            return Proxy.new("table." .. key)
        end
    })

    env.string = setmetatable({}, {
        __index = function(_, key)
            return Proxy.new("string." .. key)
        end
    })

    env.math = setmetatable({}, {
        __index = function(_, key)
            return Proxy.new("math." .. key)
        end
    })

    env.bit32 = setmetatable({}, {
        __index = function(_, key)
            return Proxy.new("bit32." .. key)
        end
    })

    env.coroutine = setmetatable({}, {
        __index = function(_, key)
            return Proxy.new("coroutine." .. key)
        end
    })

    env.debug = setmetatable({}, {
        __index = function(_, key)
            return Proxy.new("debug." .. key)
        end
    })

    env.os = setmetatable({}, {
        __index = function(_, key)
            return Proxy.new("os." .. key)
        end
    })

    env.task = setmetatable({
        wait = function(t)
            Logger:add("task.wait(" .. (t and Proxy.stringify(t) or "") .. ")")
            return Proxy.new("task.wait(" .. (t and Proxy.stringify(t) or "") .. ")")
        end,
        spawn = function(f, ...)
            local args = { Proxy.stringify(f) }
            for i, v in ipairs({...}) do
                args[#args + 1] = Proxy.stringify(v)
            end
            Logger:add("task.spawn(" .. table.concat(args, ", ") .. ")")
            return Proxy.new("task.spawn(" .. table.concat(args, ", ") .. ")")
        end,
        delay = function(t, f, ...)
            local args = { Proxy.stringify(t), Proxy.stringify(f) }
            for i, v in ipairs({...}) do
                args[#args + 1] = Proxy.stringify(v)
            end
            Logger:add("task.delay(" .. table.concat(args, ", ") .. ")")
            return Proxy.new("task.delay(" .. table.concat(args, ", ") .. ")")
        end,
        defer = function(f, ...)
            local args = { Proxy.stringify(f) }
            for i, v in ipairs({...}) do
                args[#args + 1] = Proxy.stringify(v)
            end
            Logger:add("task.defer(" .. table.concat(args, ", ") .. ")")
            return Proxy.new("task.defer(" .. table.concat(args, ", ") .. ")")
        end,
    }, {
        __index = function(_, key)
            return Proxy.new("task." .. key)
        end
    })

    setmetatable(env, {
        __index = function(_, key)
            return Proxy.new(tostring(key))
        end,
        __newindex = function(_, key, value)
            Logger:add(tostring(key) .. " = " .. Proxy.stringify(value))
        end
    })

    return env
end

return Sandbox
