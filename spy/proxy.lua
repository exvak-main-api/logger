local Logger   = require("./logger")
local Expr     = require("./expr")
local Compiler = require("./compiler")

local Proxy = {}

local mt

local function makeLiteral(value)
    return {
        type = "literal",
        value = value
    }
end

local function toExpr(value)
    if type(value) == "table" then
        local e = Expr.get(value)
        if e then
            return e
        end
    end
    return makeLiteral(value)
end

mt = {
    __index = function(self, key)
        local base = Expr.get(self)

        local expr = {
            type = "index",
            base = base,
            key  = tostring(key)
        }

        local new = {}
        Expr.set(new, expr)
        return setmetatable(new, mt)
    end,

    __newindex = function(self, key, value)
        local base = Expr.get(self)

        local target = {
            type = "index",
            base = base,
            key  = tostring(key)
        }

        local assign = {
            type  = "assign",
            target = target,
            value  = toExpr(value)
        }

        Logger:add(Compiler.compile(assign))
    end,

    __call = function(self, ...)
        local expr = Expr.get(self)
        local args = {}

        for i, v in ipairs({...}) do
            args[i] = toExpr(v)
        end

        local newExpr

        if expr.type == "index" then
            -- method call: base:name(...)
            newExpr = {
                type = "method",
                base = expr.base,
                name = expr.key,
                args = args
            }
        else
            -- normal call: base(...)
            newExpr = {
                type = "call",
                base = expr,
                args = args
            }
        end

        Logger:add(Compiler.compile(newExpr))

        local proxy = {}
        Expr.set(proxy, newExpr)
        return setmetatable(proxy, mt)
    end,

    __tostring = function(self)
        return Compiler.compile(Expr.get(self))
    end,

    __concat = function(a, b)
        local left  = toExpr(a)
        local right = toExpr(b)

        local expr = {
            type  = "binary",
            op    = "..",
            left  = left,
            right = right
        }

        Logger:add(Compiler.compile(expr))

        local proxy = {}
        Expr.set(proxy, expr)
        return setmetatable(proxy, mt)
    end,

    __len = function(self)
        local expr = {
            type    = "len",
            operand = Expr.get(self)
        }

        Logger:add(Compiler.compile(expr))

        local proxy = {}
        Expr.set(proxy, expr)
        return setmetatable(proxy, mt)
    end,

    __unm = function(self)
        local expr = {
            type    = "unary",
            op      = "-",
            operand = Expr.get(self)
        }

        Logger:add(Compiler.compile(expr))

        local proxy = {}
        Expr.set(proxy, expr)
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

-- keep a public stringify helper for sandbox
function Proxy.stringify(value)
    local e = Expr.get(value)
    if e then
        return Compiler.compile(e)
    end
    if type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

return Proxy
