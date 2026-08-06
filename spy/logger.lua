-- spy/logger.lua
local Logger = {
    entries = {},
    enabled = true,
    level = "all"
}

local levels = {
    all = 0,
    debug = 1,
    info = 2,
    warn = 3,
    error = 4
}

function Logger:add(expression, level)
    if not self.enabled then return end
    level = level or "info"
    if levels[level] < levels[self.level] then return end

    local entry = {
        time = os.clock(),
        level = level,
        expression = expression
    }
    table.insert(self.entries, entry)
    print(("[%s] %s"):format(level:upper(), expression))
end

function Logger:debug(expression)
    self:add(expression, "debug")
end

function Logger:info(expression)
    self:add(expression, "info")
end

function Logger:warn(expression)
    self:add(expression, "warn")
end

function Logger:error(expression)
    self:add(expression, "error")
end

function Logger:clear()
    table.clear(self.entries)
end

function Logger:dump()
    local result = {}
    for _, entry in ipairs(self.entries) do
        table.insert(result, ("[%.4f][%s] %s"):format(entry.time, entry.level:upper(), entry.expression))
    end
    return table.concat(result, "\n")
end

function Logger:setLevel(level)
    self.level = level or "all"
end

function Logger:enable()
    self.enabled = true
end

function Logger:disable()
    self.enabled = false
end

return Logger
