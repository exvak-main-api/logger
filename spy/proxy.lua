local Logger   = require("./logger")
local Expr     = require("./expr")
local Compiler = require("./compiler")

local Proxy = {}
local mt

local function makeLiteral(value)
    return { type = "literal", value = value }
end

local function toExpr(value)
    if type(value) == "table" then
        local e = Expr.get(value)
        if e then return e end
    end
    return makeLiteral(value)
end

local function makeBinary(op, left, right)
    local expr = {
        type  = "binary",
        op    = op,
        left  = toExpr(left),
        right = toExpr(right)
    }
    Logger:add(Compiler.compile(expr))

    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

local function makeUnary(op, operand)
    local expr = {
        type    = "unary",
        op      = op,
        operand = toExpr(operand)
    }
    Logger:add(Compiler.compile(expr))

    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

mt = {
    __index = function(self, key)
        local expr = {
            type = "index",
            base = Expr.get(self),
            key  = tostring(key)
        }
        local new = {}
        Expr.set(new, expr)
        return setmetatable(new, mt)
    end,

    __newindex = function(self, key, value)
        local target = {
            type = "index",
            base = Expr.get(self),
            key  = tostring(key)
        }
        local assign = {
            type   = "assign",
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
            newExpr = {
                type = "method",
                base = expr.base,
                name = expr.key,
                args = args
            }
        else
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
        return makeBinary("..", a, b)
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
        return makeUnary("-", self)
    end,

    __add  = function(a, b) return makeBinary("+",  a, b) end,
    __sub  = function(a, b) return makeBinary("-",  a, b) end,
    __mul  = function(a, b) return makeBinary("*",  a, b) end,
    __div  = function(a, b) return makeBinary("/",  a, b) end,
    __mod  = function(a, b) return makeBinary("%",  a, b) end,
    __pow  = function(a, b) return makeBinary("^",  a, b) end,
    __idiv = function(a, b) return makeBinary("//", a, b) end,
    
    __eq = function(a, b) return makeBinary("==", a, b) end,
    __lt = function(a, b) return makeBinary("<",  a, b) end,
    __le = function(a, b) return makeBinary("<=", a, b) end,

    __band = function(a, b) return makeBinary("&",  a, b) end,
    __bor  = function(a, b) return makeBinary("|",  a, b) end,
    __bxor = function(a, b) return makeBinary("~",  a, b) end,
    __shl  = function(a, b) return makeBinary("<<", a, b) end,
    __shr  = function(a, b) return makeBinary(">>", a, b) end,

    __bnot = function(self)
        return makeUnary("~", self)
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

function Proxy.paren(value)
    local expr = {
        type  = "paren",
        inner = toExpr(value)
    }
    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

return Proxy
