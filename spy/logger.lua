local Logger = {
    entries = {}
}

function Logger:add(kind, expression)
    local entry = {
        kind = kind,
        expression = expression,
    }

    table.insert(self.entries, entry)

    print(("[%s] %s"):format(kind, expression))
end

function Logger:clear()
    table.clear(self.entries)
end

function Logger:dump()
    local result = {}

    for _, entry in ipairs(self.entries) do
        table.insert(
            result,
            ("[%s] %s"):format(entry.kind, entry.expression)
        )
    end

    return table.concat(result, "\n")
end

return Logger

local Expr = {}

local exprs = setmetatable({}, {
    __mode = "k"
})

function Expr.set(proxy, expr)
    exprs[proxy] = expr
end

function Expr.get(proxy)
    return exprs[proxy]
end

return Expr

local Compiler = {}

local locals = setmetatable({}, {
    __mode = "k"
})

function Compiler.compile(expr)

    if not expr then
        return "nil"
    end

    if locals[expr] then
        return locals[expr]
    end

    if expr.type == "global" then
        return expr.name
    end

    if expr.type == "index" then
        return Compiler.compile(expr.base) .. "." .. expr.key
    end

    if expr.type == "method" then

        local args = {}

        for i,v in ipairs(expr.args) do
            args[i] = Compiler.compile(v)
        end

        return Compiler.compile(expr.base)
            .. ":"
            .. expr.name
            .. "("
            .. table.concat(args,", ")
            .. ")"

    end

    if expr.type == "literal" then
        return tostring(expr.value)
    end

    return "<?>"

end

function Compiler.assign(expr,name)
    locals[expr]=name
end
