-- spy/proxy.lua
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

local function makeLogic(op, left, right)
    local expr = {
        type  = op,
        left  = toExpr(left),
        right = toExpr(right)
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

    __concat = function(a, b) return makeBinary("..", a, b) end,

    __len = function(self)
        local expr = { type = "len", operand = Expr.get(self) }
        Logger:add(Compiler.compile(expr))
        local proxy = {}
        Expr.set(proxy, expr)
        return setmetatable(proxy, mt)
    end,

    __unm = function(self) return makeUnary("-", self) end,

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

    __bnot = function(self) return makeUnary("~", self) end,

    __pairs = function(self)
        local expr = { type = "pairs", operand = Expr.get(self) }
        Logger:add(Compiler.compile(expr))
        local proxy = {}
        Expr.set(proxy, expr)
        return setmetatable(proxy, mt)
    end,

    __ipairs = function(self)
        local expr = { type = "ipairs", operand = Expr.get(self) }
        Logger:add(Compiler.compile(expr))
        local proxy = {}
        Expr.set(proxy, expr)
        return setmetatable(proxy, mt)
    end,
}

local function makeProxy(path)
    local object = {}
    Expr.set(object, { type = "global", name = path })
    return setmetatable(object, mt)
end

Proxy.new = makeProxy

function Proxy.stringify(value)
    local e = Expr.get(value)
    if e then return Compiler.compile(e) end
    if type(value) == "string" then return string.format("%q", value) end
    return tostring(value)
end

function Proxy.paren(value)
    local expr = { type = "paren", inner = toExpr(value) }
    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

function Proxy.table(fields)
    local compiledFields = {}
    for i, f in ipairs(fields or {}) do
        if type(f) == "table" and f.key ~= nil then
            compiledFields[i] = { key = f.key, value = toExpr(f.value) }
        else
            compiledFields[i] = { value = toExpr(f) }
        end
    end
    local expr = { type = "table", fields = compiledFields }
    Logger:add(Compiler.compile(expr))
    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

function Proxy.pairs(operand)
    local expr = { type = "pairs", operand = toExpr(operand) }
    Logger:add(Compiler.compile(expr))
    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

function Proxy.ipairs(operand)
    local expr = { type = "ipairs", operand = toExpr(operand) }
    Logger:add(Compiler.compile(expr))
    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

function Proxy.for_numeric(var, start, stop, step, body)
    local expr = {
        type  = "for_numeric",
        var   = var,
        start = toExpr(start),
        stop  = toExpr(stop),
        step  = step and toExpr(step) or nil,
        body  = body or {}
    }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.for_generic(vars, iter, body)
    local expr = {
        type = "for_generic",
        vars = vars,
        iter = toExpr(iter),
        body = body or {}
    }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.while_(condition, body)
    local expr = {
        type      = "while",
        condition = toExpr(condition),
        body      = body or {}
    }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.repeat_(body, condition)
    local expr = {
        type      = "repeat",
        body      = body or {},
        condition = toExpr(condition)
    }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.if_(branches)
    local expr = { type = "if", branches = branches or {} }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.do_(body)
    local expr = { type = "do", body = body or {} }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.return_(...)
    local values = {}
    for i, v in ipairs({...}) do
        values[i] = toExpr(v)
    end
    local expr = { type = "return", values = values }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.break_()
    local expr = { type = "break" }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.goto_(label)
    local expr = { type = "goto", label = label }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.label(name)
    local expr = { type = "label", name = name }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.function_(name, params, body)
    local expr = {
        type   = "function",
        name   = name,
        params = params or {},
        body   = body or {}
    }
    Logger:add(Compiler.compile(expr))
    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

function Proxy.local_(names, values)
    local vals = {}
    for i, v in ipairs(values or {}) do
        vals[i] = toExpr(v)
    end
    local expr = {
        type   = "local",
        names  = names or {},
        values = vals
    }
    Logger:add(Compiler.compile(expr))
    return expr
end

function Proxy.and_(a, b)
    return makeLogic("and", a, b)
end

function Proxy.or_(a, b)
    return makeLogic("or", a, b)
end

function Proxy.not_(a)
    local expr = { type = "not", operand = toExpr(a) }
    Logger:add(Compiler.compile(expr))
    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

function Proxy.neq(a, b)
    return makeBinary("~=", a, b)
end

function Proxy.gt(a, b)
    return makeBinary(">", a, b)
end

function Proxy.ge(a, b)
    return makeBinary(">=", a, b)
end

function Proxy.vararg()
    local expr = { type = "vararg" }
    local proxy = {}
    Expr.set(proxy, expr)
    return setmetatable(proxy, mt)
end

return Proxy
