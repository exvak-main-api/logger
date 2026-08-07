# logger / spy

Expression-tree based Roblox/Luau **tracer sandbox** that reconstructs executed code for logging and readable dumps.

Also includes a **Discord bot** with the `.l` command.

## Modules

| Path | Role |
|------|------|
| `logger.luau` | Levelled logger + dump/filter |
| `expr.luau` | Weak expression storage |
| `compiler.luau` | Expression → source |
| `proxy.luau` | Operator-overloading proxies |
| `sandbox.luau` | Full executor API surface (UNC-style) |
| `runner.luau` | CLI: run a script through the sandbox → reconstructed output |
| `test.luau` | Lune smoke test |
| `bot/discord_bot.py` | Discord bot (`.l` command) |

## Lune CLI

```bash
# smoke test
lune run test.luau

# reconstruct a script
lune run runner.luau path/to/script.lua dumps/out.lua
```

## Discord bot (`.l`)

```bash
pip install -r bot/requirements.txt
export DISCORD_BOT_TOKEN=your_token
python bot/discord_bot.py
```

Then in Discord:

```
.l
```

with a **file**, **``` code block**, or **raw link** (or reply to a message that has one).

The bot runs the code through the tracer and replies with `reconstructed.lua`.

See [bot/README.md](bot/README.md) for details.

## Coverage (sandbox)

Environments, closures/hooks, metatables, identity, instances/signals, scripts, filesystem, input, Drawing, crypt, syn/oth, cache, rconsole, debug.*, and common aliases from UNC/sUNC-style executors.
