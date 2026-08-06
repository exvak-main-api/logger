local Logger = {}

Logger.logs = {}

function Logger:log(text)
    print(text)
    table.insert(self.logs, text)
end

function Logger:dump()
    return table.concat(self.logs, "\n")
end

return Logger
