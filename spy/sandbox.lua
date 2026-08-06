local proxy = require(script.Parent.proxy)

local env = {
    game = proxy("game"),
    workspace = proxy("workspace"),
    print = print,
    warn = warn,
}

return env
