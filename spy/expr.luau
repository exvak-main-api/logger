-- spy/expr.luau
local Expr = {}

local exprs: { [any]: any } = setmetatable({}, { __mode = "k" })
local meta: { [any]: any } = setmetatable({}, { __mode = "k" })

function Expr.set(proxy: any, expr: any)
	exprs[proxy] = expr
end

function Expr.get(proxy: any): any?
	return exprs[proxy]
end

function Expr.setMeta(proxy: any, data: any)
	meta[proxy] = data
end

function Expr.getMeta(proxy: any): any?
	return meta[proxy]
end

return Expr
