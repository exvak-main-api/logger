-- spy/expr.lua
local Expr = {}

local exprs = setmetatable({}, { __mode = "k" })
local meta = setmetatable({}, { __mode = "k" })

function Expr.set(proxy, expr)
    exprs[proxy] = expr
end

function Expr.get(proxy)
    return exprs[proxy]
end

function Expr.setMeta(proxy, data)
    meta[proxy] = data
end

function Expr.getMeta(proxy)
    return meta[proxy]
end

return Expr
