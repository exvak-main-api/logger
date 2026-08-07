# Discord bot — `.l` / `.la` reconstruction

Runs attached / pasted / linked Lua through the tracer or Aspect and returns reconstructed source.

## Commands

| Command | Backend |
|---------|---------|
| `.l` | Tracer (Lune sandbox) → pure-Python fallback if no Lune |
| `.la` | Aspect full dumper (requires Lune) |

Both accept a file attachment, ``` code block, raw link, or a reply to a message that has one of those.

## Pydroid 3 (Android)

Lune does **not** run on Pydroid. The bot automatically uses a **pure-Python fallback** (`py_runner.py`) for `.l` that:

- extracts `loadstring` / `load` bodies  
- finds URLs and common Roblox/executor API calls  
- normalizes the original source for reading  

`.la` (Aspect) is unavailable without Lune.

### Setup on Pydroid 3

1. Install packages in Pydroid (Pip):
   - `discord.py`
   - `aiohttp`
2. Copy the whole `spy/` folder onto the device (or clone the repo).
3. In Pydroid terminal / script:

```python
import os
os.environ["DISCORD_BOT_TOKEN"] = "your_bot_token_here"
# then run:
#  exec(open("bot/discord_bot.py").read())
```

Or create a small launcher:

```python
import os, runpy
os.environ["DISCORD_BOT_TOKEN"] = "YOUR_TOKEN"
runpy.run_path("bot/discord_bot.py", run_name="__main__")
```

4. Enable **Message Content Intent** in the Discord Developer Portal for your bot.
5. Run the launcher. On start you should see a note about the Python fallback.

Then in Discord use `.l` with a file, code block, or link.

## PC / VPS (full Lune + Aspect)

```bash
# Install Lune: https://github.com/lune-org/lune
pip install -r requirements.txt
export DISCORD_BOT_TOKEN=your_token
python discord_bot.py
```

With Lune installed:
- `.l` → live tracer sandbox
- `.la` → Aspect dump (needs `core/io/apidump.json` relative to the working dir when Aspect loads)

Without Lune, `.l` still works via the Python fallback; `.la` will report that Aspect needs Lune.

## Optional env vars

| Variable | Meaning |
|----------|---------|
| `DISCORD_BOT_TOKEN` | Bot token (required) |
| `LUNE_PATH` | Full path to `lune` binary if not on PATH |
