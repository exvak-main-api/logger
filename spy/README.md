# logger / spy

Expression-tree based Roblox/Luau **tracer sandbox** that reconstructs executed code for logging and readable dumps.

Also includes **Aspect** (full environment dumper) and a **Discord bot** with the `.l` command.

## Modules

| Path | Role |
|------|------|
| `logger.luau` | Levelled logger + dump/filter |
| `expr.luau` | Weak expression storage |
| `compiler.luau` | Expression → source |
| `proxy.luau` | Operator-overloading proxies |
| `sandbox.luau` | Lightweight executor API surface (UNC-style) |
| `runner.luau` | CLI: tracer **or** Aspect dump |
| `aspect.lua` | Full Aspect environment emulator / dumper |
| `aspect_bridge.luau` | Stable API over Aspect for the rest of the package |
| `test.luau` | Lune smoke test (tracer) |
| `bot/discord_bot.py` | Discord bot (`.l` / `.la`) |

## Two backends

### 1. Tracer (default, lightweight)

Runs the script inside the expression-tree sandbox and emits reconstructed calls.

```bash
lune run runner.luau path/to/script.lua dumps/out.lua
# or explicit
lune run runner.luau --tracer path/to/script.lua dumps/out.lua
```

### 2. Aspect (heavy, high-fidelity)

Uses the full Aspect emulator (from `aspect.lua`) for deeper dumps of obfuscated / executor-heavy scripts.

```bash
lune run runner.luau --aspect path/to/script.lua dumps/out_aspect.lua
# short flag
lune run runner.luau -a path/to/script.lua
```

**Note:** Aspect expects a Roblox API dump at `core/io/apidump.json` relative to the working directory when it starts. If that file is missing, Aspect will fail on load — place a valid dump there or run from a tree that already has one.

## Package require

```lua
local spy = require("./init")
-- tracer pieces
local env = spy.Sandbox.create()
-- Aspect (lazy)
local aspect = spy.aspect()
local bridge = spy.bridge()
local ok, path = bridge.dumpFile("in.lua", "out.lua")
```

## Lune smoke test

```bash
lune run test.luau
```

## Discord bot

```bash
pip install -r bot/requirements.txt
export DISCORD_BOT_TOKEN=your_token
python bot/discord_bot.py
```

| Command | Backend |
|---------|---------|
| `.l` | Tracer (Lune) → Python fallback |
| `.la` | Aspect (Lune only) |

Attach a file, paste a ``` code block, or send a raw link (or reply to a message that has one).

See [bot/README.md](bot/README.md) for details.

## Coverage (tracer sandbox)

Environments, closures/hooks, metatables, identity, instances/signals, scripts, filesystem, input, Drawing, crypt, syn/oth, cache, rconsole, debug.*, and common aliases from UNC/sUNC-style executors.

Aspect covers a much larger surface (full proxy game/workspace, hooks, crypt, Drawing, WebSocket, etc.) and is better for heavily obfuscated dumps.
