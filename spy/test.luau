local Sandbox = require("./sandbox")
local Logger = require("./logger")
local stdio = require("@lune/stdio")

local env = Sandbox.create()

stdio.write(stdio.color("cyan") .. "=== Tracer test start ===\n" .. stdio.color("reset"))

local game = env.game
local players = game.Players
local localPlayer = players.LocalPlayer
local humanoid = localPlayer.Character.Humanoid
humanoid.Health = 100

env.print(localPlayer.Name .. " hp=" .. humanoid.Health)
env.workspace:FindFirstChild("Baseplate")
env.Instance.new("Part", env.workspace)

env.hookfunction(env.print, env.warn)
env.gethwid()
env.setfpscap(144)
env.debug.getupvalue(env.print, 1)
env.debug.info(1, "n")
env.setclipboard("test")
env.writefile("x.txt", "data")

stdio.write(stdio.color("green") .. "\n=== Log dump ===\n" .. stdio.color("reset"))
print(Logger:dump())
