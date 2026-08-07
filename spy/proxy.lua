-- spy/proxy.luau
local Logger = require("@self/logger")
local Expr = require("@self/expr")
local Compiler = require("@self/compiler")

local Proxy = {}
local mt

local function makeLiteral(value: any)
	return { type = "literal", value = value }
end

local function toExpr(value: any)
	if type(value) == "table" then
		local e = Expr.get(value)
		if e then
			return e
		end
	end
	return makeLiteral(value)
end

local function makeBinary(op: string, left: any, right: any)
	local expr = {
		type = "binary",
		op = op,
		left = toExpr(left),
		right = toExpr(right),
	}
	Logger:add(Compiler.compile(expr))
	local proxy = {}
	Expr.set(proxy, expr)
	return setmetatable(proxy, mt)
end

local function makeUnary(op: string, operand: any)
	local expr = {
		type = "unary",
		op = op,
		operand = toExpr(operand),
	}
	Logger:add(Compiler.compile(expr))
	local proxy = {}
	Expr.set(proxy, expr)
	return setmetatable(proxy, mt)
end

local function makeLogic(op: string, left: any, right: any)
	local expr = {
		type = op,
		left = toExpr(left),
		right = toExpr(right),
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
			key = tostring(key),
		}
		local new = {}
		Expr.set(new, expr)
		return setmetatable(new, mt)
	end,

	__newindex = function(self, key, value)
		local target = {
			type = "index",
			base = Expr.get(self),
			key = tostring(key),
		}
		local assign = {
			type = "assign",
			target = target,
			value = toExpr(value),
		}
		Logger:add(Compiler.compile(assign))
	end,

	__call = function(self, ...)
		local expr = Expr.get(self)
		local args = {}
		for i, v in { ... } do
			args[i] = toExpr(v)
		end

		local newExpr
		if expr.type == "index" then
			newExpr = {
				type = "method",
				base = expr.base,
				name = expr.key,
				args = args,
			}
		else
			newExpr = {
				type = "call",
				base = expr,
				args = args,
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
		local expr = { type = "len", operand = Expr.get(self) }
		Logger:add(Compiler.compile(expr))
		local proxy = {}
		Expr.set(proxy, expr)
		return setmetatable(proxy, mt)
	end,

	__unm = function(self)
		return makeUnary("-", self)
	end,

	__add = function(a, b)
		return makeBinary("+", a, b)
	end,
	__sub = function(a, b)
		return makeBinary("-", a, b)
	end,
	__mul = function(a, b)
		return makeBinary("*", a, b)
	end,
	__div = function(a, b)
		return makeBinary("/", a, b)
	end,
	__mod = function(a, b)
		return makeBinary("%", a, b)
	end,
	__pow = function(a, b)
		return makeBinary("^", a, b)
	end,
	__idiv = function(a, b)
		return makeBinary("//", a, b)
	end,

	__eq = function(a, b)
		return makeBinary("==", a, b)
	end,
	__lt = function(a, b)
		return makeBinary("<", a, b)
	end,
	__le = function(a, b)
		return makeBinary("<=", a, b)
	end,

	__band = function(a, b)
		return makeBinary("&", a, b)
	end,
	__bor = function(a, b)
		return makeBinary("|", a, b)
	end,
	__bxor = function(a, b)
		return makeBinary("~", a, b)
	end,
	__shl = function(a, b)
		return makeBinary("<<", a, b)
	end,
	__shr = function(a, b)
		return makeBinary(">>", a, b)
	end,

	__bnot = function(self)
		return makeUnary("~", self)
	end,

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

local function makeProxy(path: string)
	local object = {}
	Expr.set(object, { type = "global", name = path })
	return setmetatable(object, mt)
end

Proxy.new = makeProxy

function Proxy.stringify(value: any): string
	local e = Expr.get(value)
	if e then
		return Compiler.compile(e)
	end
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

function Proxy.paren(value: any)
	local expr = { type = "paren", inner = toExpr(value) }
	local proxy = {}
	Expr.set(proxy, expr)
	return setmetatable(proxy, mt)
end

function Proxy.table(fields: { any }?)
	local compiledFields = {}
	for i, f in fields or {} do
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

function Proxy.pairs(operand: any)
	local expr = { type = "pairs", operand = toExpr(operand) }
	Logger:add(Compiler.compile(expr))
	local proxy = {}
	Expr.set(proxy, expr)
	return setmetatable(proxy, mt)
end

function Proxy.ipairs(operand: any)
	local expr = { type = "ipairs", operand = toExpr(operand) }
	Logger:add(Compiler.compile(expr))
	local proxy = {}
	Expr.set(proxy, expr)
	return setmetatable(proxy, mt)
end

function Proxy.for_numeric(var: string, start: any, stop: any, step: any?, body: { any }?)
	local expr = {
		type = "for_numeric",
		var = var,
		start = toExpr(start),
		stop = toExpr(stop),
		step = if step then toExpr(step) else nil,
		body = body or {},
	}
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.for_generic(vars: { string }, iter: any, body: { any }?)
	local expr = {
		type = "for_generic",
		vars = vars,
		iter = toExpr(iter),
		body = body or {},
	}
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.while_(condition: any, body: { any }?)
	local expr = {
		type = "while",
		condition = toExpr(condition),
		body = body or {},
	}
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.repeat_(body: { any }?, condition: any)
	local expr = {
		type = "repeat",
		body = body or {},
		condition = toExpr(condition),
	}
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.if_(branches: { any }?)
	local expr = { type = "if", branches = branches or {} }
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.do_(body: { any }?)
	local expr = { type = "do", body = body or {} }
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.return_(...: any)
	local values = {}
	for i, v in { ... } do
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

function Proxy.goto_(label: string)
	local expr = { type = "goto", label = label }
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.label(name: string)
	local expr = { type = "label", name = name }
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.function_(name: string?, params: { string }?, body: { any }?)
	local expr = {
		type = "function",
		name = name,
		params = params or {},
		body = body or {},
	}
	Logger:add(Compiler.compile(expr))
	local proxy = {}
	Expr.set(proxy, expr)
	return setmetatable(proxy, mt)
end

function Proxy.local_(names: { string }, values: { any }?)
	local vals = {}
	for i, v in values or {} do
		vals[i] = toExpr(v)
	end
	local expr = {
		type = "local",
		names = names or {},
		values = vals,
	}
	Logger:add(Compiler.compile(expr))
	return expr
end

function Proxy.and_(a: any, b: any)
	return makeLogic("and", a, b)
end

function Proxy.or_(a: any, b: any)
	return makeLogic("or", a, b)
end

function Proxy.not_(a: any)
	local expr = { type = "not", operand = toExpr(a) }
	Logger:add(Compiler.compile(expr))
	local proxy = {}
	Expr.set(proxy, expr)
	return setmetatable(proxy, mt)
end

function Proxy.neq(a: any, b: any)
	return makeBinary("~=", a, b)
end

function Proxy.gt(a: any, b: any)
	return makeBinary(">", a, b)
end

function Proxy.ge(a: any, b: any)
	return makeBinary(">=", a, b)
end

function Proxy.vararg()
	local expr = { type = "vararg" }
	local proxy = {}
	Expr.set(proxy, expr)
	return setmetatable(proxy, mt)
end

return Proxy
