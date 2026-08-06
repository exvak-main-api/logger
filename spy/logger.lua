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
