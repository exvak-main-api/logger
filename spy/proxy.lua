local Logger = require(script.Parent.logger)

local function proxy(path)
    return setmetatable({}, {

        __index = function(_, key)
            local newPath = path .. "." .. tostring(key)
            Logger:log("READ " .. newPath)
            return proxy(newPath)
        end,

        __newindex = function(_, key, value)
            Logger:log(("WRITE %s.%s = %s")
                :format(path, key, tostring(value)))
        end,

        __call = function(_, ...)
            local args = table.pack(...)

            local s = {}

            for i = 1, args.n do
                s[i] = tostring(args[i])
            end

            Logger:log(path .. "(" .. table.concat(s, ", ") .. ")")

            return proxy(path .. "()")
        end,
    })
end

return proxy
