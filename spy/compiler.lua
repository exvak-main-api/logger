local Compiler = {}

local locals = setmetatable({}, { __mode = "k" })

local function isIdentifier(str)
    return type(str) == "string" and str:match("^[%a_][%w_]*$") ~= nil
end

local function stringify(value)
    local t = type(value)
    if t == "string" then
        return string.format("%q", value)
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "nil" then
        return "nil"
    end
    return tostring(value)
end

function Compiler.compile(expr)
    if not expr then
        return "nil"
    end

    if locals[expr] then
        return locals[expr]
    end

    local t = expr.type

    if t == "global" then
        return expr.name
    end

    if t == "literal" then
        return stringify(expr.value)
    end

    if t == "index" then
        local base = Compiler.compile(expr.base)
        local key  = expr.key

        if isIdentifier(key) then
            return base .. "." .. key
        else
            return base .. "[" .. stringify(key) .. "]"
        end
    end

    if t == "method" then
        local args = {}
        for i, v in ipairs(expr.args or {}) do
            args[i] = Compiler.compile(v)
        end
        return Compiler.compile(expr.base)
            .. ":"
            .. expr.name
            .. "("
            .. table.concat(args, ", ")
            .. ")"
    end

    if t == "call" then
        local args = {}
        for i, v in ipairs(expr.args or {}) do
            args[i] = Compiler.compile(v)
        end
        return Compiler.compile(expr.base)
            .. "("
            .. table.concat(args, ", ")
            .. ")"
    end

    if t == "assign" then
        return Compiler.compile(expr.target)
            .. " = "
            .. Compiler.compile(expr.value)
    end

    if t == "binary" then
        return "("
            .. Compiler.compile(expr.left)
            .. " "
            .. expr.op
            .. " "
            .. Compiler.compile(expr.right)
            .. ")"
    end

    if t == "unary" then
        return "(" .. expr.op .. Compiler.compile(expr.operand) .. ")"
    end

    if t == "len" then
        return "#(" .. Compiler.compile(expr.operand) .. ")"
    end

    if t == "paren" then
        return "(" .. Compiler.compile(expr.inner) .. ")"
    end

    return "<?>"
end

function Compiler.assign(expr, name)
    locals[expr] = name
end

return Compiler
