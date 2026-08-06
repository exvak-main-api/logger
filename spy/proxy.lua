local Logger = require("./logger")

local Proxy = {}

local paths = setmetatable({}, {
    __mode = "k"
})

local function stringify(value)
    if paths[value] then
        return paths[value]
    end

    if type(value) == "string" then
        return string.format("%q", value)
    end

    return tostring(value)
end

local function makeProxy(path)
    local object = {}

    Expr.set(obj,{
            type="global",
            name=path
        })

    return setmetatable(object, {
        __index = function(_, key)
            local expression

            if type(key) == "string"
                and key:match("^[%a_][%w_]*$") then

                expression = path .. "." .. key
            else
                expression =
                    path .. "[" .. stringify(key) .. "]"
            end

            Logger:add("INDEX", expression)

            return makeProxy(expression)
        end,

        __newindex = function(_, key, value)
            local expression =
                path
                .. "["
                .. stringify(key)
                .. "] = "
                .. stringify(value)

            Logger:add("WRITE", expression)
        end,

        __call = function(_, ...)
            local args = table.pack(...)
            local output = {}

            for i = 1, args.n do
                output[i] = stringify(args[i])
            end

            local expression =
                path
                .. "("
                .. table.concat(output, ", ")
                .. ")"

            Logger:add("CALL", expression)

            return makeProxy(expression)
        end,

        __tostring = function()
            return path
        end,

        __concat = function(a, b)
            local expression =
                stringify(a) .. " .. " .. stringify(b)

            Logger:add("CONCAT", expression)

            return makeProxy("(" .. expression .. ")")
        end,
    })
end

Proxy.new = makeProxy
Proxy.stringify = stringify

return Proxy
