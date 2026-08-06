local Proxy = require("./proxy")
local Logger = require("./logger")

local Sandbox = {}

function Sandbox.create()
    local env = {}

    env.game = Proxy.new("game")
    env.workspace = Proxy.new("workspace")

    env.print = function(...)
        local args = table.pack(...)
        local result = {}

        for i = 1, args.n do
            result[i] = Proxy.stringify(args[i])
        end

        Logger:add(
            "PRINT",
            "print(" .. table.concat(result, ", ") .. ")"
        )
    end

    env.warn = env.print

    env.getgenv = function()
        return Proxy.new("getgenv()")
    end

    env.identifyexecutor = function()
        Logger:add(
            "CALL",
            "identifyexecutor()"
        )

        return "Tracer", "1.0"
    end

    return env
end

return Sandbox
