local Sandbox = require("./sandbox")
local Logger = require("./logger")
local stdio = require("@lune/stdio")

local env = Sandbox.create()
stdio.write(stdio.color("cyan") .. "=== Tracer test ===\n" .. stdio.color("reset"))

env.game.Players.LocalPlayer.Character.Humanoid.Health = 100
env.workspace:FindFirstChild("Baseplate")
env.hookfunction(env.print, env.warn)
env.getfenv(1)
env.clonefunction(env.print)
env.gethui()
env.gethwid()
env.setfpscap(144)
env.rconsoleprint("hello")
env.cache.iscached(env.game)
env.decompile(env.script)
env.debug.getupvalue(env.print, 1)
env.oth.hook(env.print, env.warn)

stdio.write(stdio.color("green") .. "\n=== dump ===\n" .. stdio.color("reset"))
print(Logger:dumpExpressions())
print("count:", Logger:count())
