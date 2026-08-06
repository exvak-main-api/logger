local Expr = {}

local exprs = setmetatable({}, { __mode = "k" })

function Expr.set(proxy, expr)
    exprs[proxy] = expr
end

function Expr.get(proxy)
    return exprs[proxy]
end

return Expr
