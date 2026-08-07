-- spy/compiler.luau
local Compiler = {}

local locals: { [any]: string } = setmetatable({}, { __mode = "k" })

local function isIdentifier(str: any): boolean
	return type(str) == "string" and str:match("^[%a_][%w_]*$") ~= nil
end

local function stringify(value: any): string
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

function Compiler.compile(expr: any): string
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
		local key = expr.key
		if isIdentifier(key) then
			return `{base}.{key}`
		else
			return `{base}[{stringify(key)}]`
		end
	end

	if t == "method" then
		local args = {}
		for i, v in expr.args or {} do
			args[i] = Compiler.compile(v)
		end
		return `{Compiler.compile(expr.base)}:{expr.name}({table.concat(args, ", ")})`
	end

	if t == "call" then
		local args = {}
		for i, v in expr.args or {} do
			args[i] = Compiler.compile(v)
		end
		return `{Compiler.compile(expr.base)}({table.concat(args, ", ")})`
	end

	if t == "assign" then
		return `{Compiler.compile(expr.target)} = {Compiler.compile(expr.value)}`
	end

	if t == "binary" then
		return `({Compiler.compile(expr.left)} {expr.op} {Compiler.compile(expr.right)})`
	end

	if t == "unary" then
		return `({expr.op}{Compiler.compile(expr.operand)})`
	end

	if t == "len" then
		return `#({Compiler.compile(expr.operand)})`
	end

	if t == "paren" then
		return `({Compiler.compile(expr.inner)})`
	end

	if t == "table" then
		local parts = {}
		for i, field in expr.fields or {} do
			if field.key then
				if isIdentifier(field.key) then
					parts[i] = `{field.key} = {Compiler.compile(field.value)}`
				else
					parts[i] = `[{stringify(field.key)}] = {Compiler.compile(field.value)}`
				end
			else
				parts[i] = Compiler.compile(field.value)
			end
		end
		return `\{{table.concat(parts, ", ")}\}`
	end

	if t == "pairs" then
		return `pairs({Compiler.compile(expr.operand)})`
	end

	if t == "ipairs" then
		return `ipairs({Compiler.compile(expr.operand)})`
	end

	if t == "for_numeric" then
		local body = {}
		for i, s in expr.body or {} do
			body[i] = Compiler.compile(s)
		end
		local step = if expr.step then `, {Compiler.compile(expr.step)}` else ""
		return `for {expr.var} = {Compiler.compile(expr.start)}, {Compiler.compile(expr.stop)}{step} do\n  {table.concat(body, "\n  ")}\nend`
	end

	if t == "for_generic" then
		local body = {}
		for i, s in expr.body or {} do
			body[i] = Compiler.compile(s)
		end
		return `for {table.concat(expr.vars, ", ")} in {Compiler.compile(expr.iter)} do\n  {table.concat(body, "\n  ")}\nend`
	end

	if t == "while" then
		local body = {}
		for i, s in expr.body or {} do
			body[i] = Compiler.compile(s)
		end
		return `while {Compiler.compile(expr.condition)} do\n  {table.concat(body, "\n  ")}\nend`
	end

	if t == "repeat" then
		local body = {}
		for i, s in expr.body or {} do
			body[i] = Compiler.compile(s)
		end
		return `repeat\n  {table.concat(body, "\n  ")}\nuntil {Compiler.compile(expr.condition)}`
	end

	if t == "if" then
		local parts = {}
		for i, branch in expr.branches or {} do
			local body = {}
			for j, s in branch.body or {} do
				body[j] = Compiler.compile(s)
			end
			if i == 1 then
				parts[i] = `if {Compiler.compile(branch.condition)} then\n  {table.concat(body, "\n  ")}`
			elseif branch.condition then
				parts[i] = `elseif {Compiler.compile(branch.condition)} then\n  {table.concat(body, "\n  ")}`
			else
				parts[i] = `else\n  {table.concat(body, "\n  ")}`
			end
		end
		return table.concat(parts, "\n") .. "\nend"
	end

	if t == "do" then
		local body = {}
		for i, s in expr.body or {} do
			body[i] = Compiler.compile(s)
		end
		return `do\n  {table.concat(body, "\n  ")}\nend`
	end

	if t == "return" then
		local vals = {}
		for i, v in expr.values or {} do
			vals[i] = Compiler.compile(v)
		end
		return `return {table.concat(vals, ", ")}`
	end

	if t == "break" then
		return "break"
	end

	if t == "goto" then
		return `goto {expr.label}`
	end

	if t == "label" then
		return `::{expr.name}::`
	end

	if t == "function" then
		local params = table.concat(expr.params or {}, ", ")
		local body = {}
		for i, s in expr.body or {} do
			body[i] = Compiler.compile(s)
		end
		local name = if expr.name then ` {expr.name}` else ""
		return `function{name}({params})\n  {table.concat(body, "\n  ")}\nend`
	end

	if t == "local" then
		local names = table.concat(expr.names or {}, ", ")
		local values = {}
		for i, v in expr.values or {} do
			values[i] = Compiler.compile(v)
		end
		if #values > 0 then
			return `local {names} = {table.concat(values, ", ")}`
		end
		return `local {names}`
	end

	if t == "vararg" then
		return "..."
	end

	if t == "and" then
		return `({Compiler.compile(expr.left)} and {Compiler.compile(expr.right)})`
	end

	if t == "or" then
		return `({Compiler.compile(expr.left)} or {Compiler.compile(expr.right)})`
	end

	if t == "not" then
		return `(not {Compiler.compile(expr.operand)})`
	end

	if t == "statement" then
		return Compiler.compile(expr.inner)
	end

	return "<?>"
end

function Compiler.assign(expr: any, name: string)
	locals[expr] = name
end

return Compiler
