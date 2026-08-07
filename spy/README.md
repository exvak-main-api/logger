# logger / spy

OSE env logger — reconstructs Roblox/Luau scripts via **Aspect** (default) with a lightweight tracer and Python fallback.

## Output format

Every dump is a clean file with only this header + reconstructed code:

```lua
-- [[
this file was constructed by OSE env logger
@ discord.gg/uEWVqpnyf2
]] --

-- reconstructed code only
```

No original source, no Aspect banners, no extra noise.

## Modules

| Path | Role |
|------|------|
| `logger.luau` | Levelled logger + dump/filter |
| `expr.luau` | Weak expression storage |
| `compiler.luau` | Expression → source |
| `proxy.luau` | Operator-overloading proxies |
| `sandbox.luau` | Lightweight executor API surface |
| `runner.luau` | CLI: Aspect → tracer |
| `aspect.lua` | Full Aspect environment emulator |
| `aspect_bridge.luau` | Aspect API + OSE header wrapping |
| `test.luau` | Lune smoke test |
| `bot/discord_bot.py` | Discord bot (`.l`) |

## CLI

```bash
# auto: Aspect first, tracer fallback
lune run runner.luau path/to/script.lua dumps/out.lua

# force Aspect
lune run runner.luau --aspect path/to/script.lua dumps/out.lua

# force tracer
lune run runner.luau --tracer path/to/script.lua dumps/out.lua
```

**Note:** Aspect expects `core/io/apidump.json` relative to the working directory. Without it, auto mode falls back to the tracer.

## Discord bot

```bash
pip install -r bot/requirements.txt
export DISCORD_BOT_TOKEN=your_token
# optional:
# export LUNE_PATH=/home/container/lune
python bot/discord_bot.py
```

| Command | Backend |
|---------|---------|
| `.l` / `.la` | Aspect (Lune) → tracer → Python fallback |

Attach a file, paste a code block, or send a raw link.
