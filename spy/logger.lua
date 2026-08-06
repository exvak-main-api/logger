-- spy/logger.lua
local Logger = {
    entries = {}
}

function Logger:add(expression)
    table.insert(self.entries, expression)
    print(expression)
end

function Logger:clear()
    table.clear(self.entries)
end

function Logger:dump()
    return table.concat(self.entries, "\n")
end

return Logger
