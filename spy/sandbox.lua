local Proxy  = require("./proxy")
local Logger = require("./logger")

local Sandbox = {}

function Sandbox.create()
    local env = {}

    env.game      = Proxy.new("game")
    env.workspace = Proxy.new("workspace")

    env.print = function(...)
        local args = table.pack(...)
        local parts = {}

        for i = 1, args.n do
            parts[i] = Proxy.stringify(args[i])
        end

        Logger:add("print(" .. table.concat(parts, ", ") .. ")")
    end

    env.warn = env.print

    env.getgenv = function()
        return Proxy.new("getgenv()")
    end

    env.identifyexecutor = function()
        Logger:add("identifyexecutor()")
        return "Tracer", "1.0"
    end

    return env
end

return Sandbox
