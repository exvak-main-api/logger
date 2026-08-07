# Discord bot — `.l` reconstruction

Runs attached / pasted / linked Lua through the tracer and returns reconstructed source.

## Pydroid 3 (Android)

Lune does **not** run on Pydroid. The bot automatically uses a **pure-Python fallback** (`py_runner.py`) that:

- extracts `loadstring` / `load` bodies  
- finds URLs and common Roblox/executor API calls  
- normalizes the original source for reading  

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
5. Run the launcher. On start you should see:
   `Lune missing — using pure-Python reconstruction fallback`

Then in Discord use `.l` with a file, code block, or link.

## PC / VPS (full Lune tracer)

```bash
# Install Lune: https://github.com/lune-org/lune
pip install -r requirements.txt
export DISCORD_BOT_TOKEN=your_token
python discord_bot.py
```

With Lune installed you get live sandbox tracing; without it the Python fallback still runs.

## Optional env vars

| Variable | Meaning |
|----------|---------|
| `DISCORD_BOT_TOKEN` | Bot token (required) |
| `LUNE_PATH` | Full path to `lune` binary if not on PATH |

## Usage

```
.l
```

+ attachment, code block, raw link, or reply to a message that has one.
