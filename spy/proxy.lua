local Logger = require("./logger")

local Proxy = {}

local function stringify(value)
    if type(value) == "string" then
        return string.format("%q", value)
    end

    return tostring(value)
end

local mt

mt = {
    __index = function(self, key)
        local base = Expr.get(self)

        local expr = {
            type = "index",
            base = base,
            key = tostring(key)
        }

        local new = {}

        Expr.set(new, expr)

        return setmetatable(new, mt)
    end,

    __newindex = function(self, key, value)
        local base = Expr.get(self)
        local expression =
            (base.name or tostring(base))
            .. "["
            .. stringify(key)
            .. "] = "
            .. stringify(value)

        Logger:add("WRITE", expression)
    end,

    __call = function(self, ...)
        local expr = Expr.get(self)

        if expr.type == "index" then
            local args = {}

            for i, v in ipairs({...}) do
                args[i] = {
                    type = "literal",
                    value = v
                }
            end

            local newExpr = {
                type = "method",
                base = expr.base,
                name = expr.key,
                args = args
            }

            Logger:add(
                "CALL",
                Compiler.compile(newExpr)
            )

            local proxy = {}

            Expr.set(proxy, newExpr)

            return setmetatable(proxy, mt)
        end
    end,

    __tostring = function(self)
        local expr = Expr.get(self)
        return expr.name or tostring(expr)
    end,

    __concat = function(a, b)
        local expression =
            stringify(a) .. " .. " .. stringify(b)

        Logger:add("CONCAT", expression)

        local proxy = {}
        Expr.set(proxy, {
            type = "global",
            name = "(" .. expression .. ")"
        })

        return setmetatable(proxy, mt)
    end,
}

local function makeProxy(path)
    local object = {}

    Expr.set(object, {
        type = "global",
        name = path
    })

    return setmetatable(object, mt)
end

Proxy.new = makeProxy
Proxy.stringify = stringify

return Proxy
