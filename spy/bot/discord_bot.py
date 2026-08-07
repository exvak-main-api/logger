"""
Discord bot for logger/spy tracer.

Command: .l
  Accepts: file attachment, ``` code block, or http(s) link
  Runs the script through the Lune tracer sandbox and returns reconstructed source.

Setup:
  1. pip install -U discord.py aiohttp
  2. export DISCORD_BOT_TOKEN=your_token
  3. Ensure `lune` is on PATH
  4. python bot/discord_bot.py
"""

from __future__ import annotations

import asyncio
import io
import os
import re
import traceback
from pathlib import Path

import aiohttp
import discord

TOKEN = os.environ.get("DISCORD_BOT_TOKEN", "")
COMMAND = "l"
MAX_INPUT_BYTES = 2 * 1024 * 1024
MAX_OUTPUT_PREVIEW = 1800
LUNE_TIMEOUT = 25

ROOT = Path(__file__).resolve().parent.parent
DUMPS = ROOT / "dumps"
ORIGINAL = DUMPS / "original"
DUMPED = DUMPS / "dumped"
RUNNER = ROOT / "runner.luau"

ORIGINAL.mkdir(parents=True, exist_ok=True)
DUMPED.mkdir(parents=True, exist_ok=True)

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

_cooldowns: dict[int, float] = {}
COOLDOWN_S = 5.0

CODEBLOCK_RE = re.compile(
    r"```(?:lua|luau|txt|text)?\s*\n?(.*?)```",
    re.DOTALL | re.IGNORECASE,
)
LINK_RE = re.compile(r"https?://\S+")


def extract_codeblock(text: str) -> str | None:
    m = CODEBLOCK_RE.search(text or "")
    if not m:
        return None
    body = m.group(1).strip()
    return body or None


def extract_link(text: str) -> str | None:
    m = LINK_RE.search(text or "")
    if not m:
        return None
    url = m.group(0)
    url = re.sub(r'[\]\)\'"\>.,;]+$', "", url)
    return url


async def fetch_url(url: str) -> str | None:
    if "pastebin.com/" in url and "/raw/" not in url:
        url = url.replace("pastebin.com/", "pastebin.com/raw/")
    headers = {"User-Agent": "logger-spy-bot/1.0", "Accept": "text/plain,text/*,*/*"}
    try:
        timeout = aiohttp.ClientTimeout(total=15)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.get(url, headers=headers) as resp:
                if resp.status != 200:
                    return None
                data = await resp.read()
                if len(data) > MAX_INPUT_BYTES:
                    return None
                return data.decode("utf-8", errors="replace")
    except Exception as e:
        print("fetch_url error:", e)
        return None


async def get_source_from_message(msg: discord.Message) -> tuple[str | None, str]:
    messages = [msg]
    if msg.reference and msg.reference.message_id:
        try:
            ref = await msg.channel.fetch_message(msg.reference.message_id)
            messages.append(ref)
        except Exception:
            pass

    for m in messages:
        if m.attachments:
            att = m.attachments[0]
            if att.size and att.size > MAX_INPUT_BYTES:
                return None, "attachment too large"
            try:
                data = await att.read()
                text = data.decode("utf-8", errors="replace")
                return text, f"attachment:{att.filename}"
            except Exception as e:
                return None, f"attachment read failed: {e}"

    for m in messages:
        block = extract_codeblock(m.content or "")
        if block:
            return block, "codeblock"

    for m in messages:
        url = extract_link(m.content or "")
        if url:
            text = await fetch_url(url)
            if text:
                return text, f"link:{url[:80]}"
            return None, "failed to fetch link"

    return None, "no input (attach a .lua file, paste a ``` code block, or include a link)"


async def run_tracer(source: str, stem: str) -> tuple[bool, str, str]:
    in_path = ORIGINAL / f"{stem}.lua"
    out_path = DUMPED / f"{stem}_reconstructed.lua"
    in_path.write_text(source.replace("\r\n", "\n").replace("\r", "\n"), encoding="utf-8")

    cmd = ["lune", "run", str(RUNNER), str(in_path), str(out_path)]
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            cwd=str(ROOT),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        try:
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=LUNE_TIMEOUT)
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            return False, "timeout: script ran too long (possible infinite loop)", ""

        out_text = stdout.decode("utf-8", errors="replace")
        err_text = stderr.decode("utf-8", errors="replace")

        if out_path.is_file():
            reconstructed = out_path.read_text(encoding="utf-8", errors="replace")
            ok = "success" in out_text or len(reconstructed) > 0
            return ok, str(out_path), reconstructed

        return False, err_text or out_text or "runner produced no output", ""
    except FileNotFoundError:
        return False, "lune not found on PATH — install Lune: https://github.com/lune-org/lune", ""
    except Exception as e:
        return False, f"runner error: {e}", ""


def make_discord_file(text: str, filename: str) -> discord.File:
    buf = io.BytesIO(text.encode("utf-8"))
    buf.seek(0)
    return discord.File(buf, filename=filename)


async def handle_l(msg: discord.Message):
    now = asyncio.get_event_loop().time()
    last = _cooldowns.get(msg.author.id, 0)
    if now - last < COOLDOWN_S:
        await msg.reply(f"cooldown — wait {COOLDOWN_S - (now - last):.1f}s")
        return
    _cooldowns[msg.author.id] = now

    async with msg.channel.typing():
        source, origin = await get_source_from_message(msg)
        if not source:
            await msg.reply(
                f"**`.l`** — reconstruct Lua via tracer sandbox\n"
                f"Provide one of:\n"
                f"• a `.lua` / `.txt` **file attachment**\n"
                f"• a **``` code block**\n"
                f"• a **raw link** (pastebin, github raw, etc.)\n"
                f"• reply to a message that has any of the above\n\n"
                f"_{origin}_"
            )
            return

        if len(source.encode("utf-8")) > MAX_INPUT_BYTES:
            await msg.reply("input too large (max 2 MB)")
            return

        stem = f"{msg.author.id}_{msg.id}"
        ok, path_or_err, reconstructed = await run_tracer(source, stem)

        if not ok and not reconstructed:
            preview = (path_or_err or "unknown error")[:500]
            await msg.reply(f"reconstruction failed:\n```diff\n- {preview}\n```")
            return

        if not reconstructed and Path(path_or_err).is_file():
            reconstructed = Path(path_or_err).read_text(encoding="utf-8", errors="replace")

        header = (
            f"reconstructed for {msg.author.mention}\n"
            f"origin: `{origin}` · size: {len(source)} → {len(reconstructed)} chars"
        )

        filename = "reconstructed.lua"
        try:
            await msg.reply(header, file=make_discord_file(reconstructed, filename))
        except discord.HTTPException:
            await msg.reply(
                header
                + "\n```lua\n"
                + reconstructed[:MAX_OUTPUT_PREVIEW]
                + ("\n-- …truncated" if len(reconstructed) > MAX_OUTPUT_PREVIEW else "")
                + "\n```"
            )


@client.event
async def on_ready():
    print(f"logged in as {client.user} (id={client.user and client.user.id})")
    print(f"spy root: {ROOT}")
    print(f"runner: {RUNNER} exists={RUNNER.is_file()}")


@client.event
async def on_message(msg: discord.Message):
    if msg.author.bot:
        return
    content = (msg.content or "").strip()
    if re.match(r"^\.l(\s|$)", content, re.IGNORECASE):
        try:
            await handle_l(msg)
        except Exception:
            traceback.print_exc()
            try:
                await msg.reply("internal error while reconstructing — check bot logs")
            except Exception:
                pass


def main():
    if not TOKEN:
        print("Set DISCORD_BOT_TOKEN environment variable first.")
        print("  export DISCORD_BOT_TOKEN=your_bot_token")
        raise SystemExit(1)
    client.run(TOKEN)


if __name__ == "__main__":
    main()
