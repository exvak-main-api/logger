# Discord bot — `.l` reconstruction

Runs attached / pasted / linked Lua through the **logger/spy** tracer sandbox and returns reconstructed, readable call logs (expressions, method calls, assignments).

## Setup

```bash
# 1. Install Lune (https://github.com/lune-org/lune)
# 2. Python deps
pip install -r bot/requirements.txt

# 3. Discord bot token (from https://discord.com/developers/applications)
export DISCORD_BOT_TOKEN="your_token_here"

# 4. Enable MESSAGE CONTENT intent in the Discord developer portal

# 5. Run from the spy/ directory (or any cwd; paths are absolute to spy/)
cd spy
python bot/discord_bot.py
```

## Usage

In Discord:

```
.l
```

with one of:

| Input | Example |
|-------|---------|
| File attachment | `.l` + upload `script.lua` |
| Code block | `.l` then \`\`\`lua … \`\`\` |
| Link | `.l https://pastebin.com/raw/…` |
| Reply | Reply to a message that has any of the above, then `.l` |

The bot replies with `reconstructed.lua` — traced expressions rebuilt as source (prints, hooks, index chains, assignments, etc.).

## How it works

1. Extracts source from attachment / code block / URL  
2. Writes it under `dumps/original/`  
3. Runs `lune run runner.luau <input> <output>`  
4. Sandbox proxies log every operation via the expression compiler  
5. Sends `dumps/dumped/*_reconstructed.lua` back as a file  

## Notes

- Timeout: 25s (guards infinite loops)  
- Max input: 2 MB  
- Cooldown: 5s per user  
- This is a **tracer**, not a full VM deobfuscator — heavily virtualized obfuscators may only yield partial logs  
