"""Discord bot for logger/spy. Commands .l (tracer) and .la (Aspect)."""

from __future__ import annotations

import asyncio
import io
import os
import re
import shutil
import traceback
from pathlib import Path

import aiohttp
import discord


def _load_token() -> str:
    for key in ("DISCORD_BOT_TOKEN", "BOT_TOKEN", "TOKEN", "DISCORD_TOKEN"):
        v = os.environ.get(key, "").strip()
        if v:
            return v
    for env_path in (
        Path(__file__).resolve().parent / ".env",
        Path(__file__).resolve().parent.parent / ".env",
        Path("/home/container/.env"),
        Path.cwd() / ".env",
    ):
        try:
            if not env_path.is_file():
                continue
            for line in env_path.read_text(encoding="utf-8", errors="replace").splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, val = line.partition("=")
                k, val = k.strip(), val.strip().strip('"').strip("'")
                if k in ("DISCORD_BOT_TOKEN", "BOT_TOKEN", "TOKEN", "DISCORD_TOKEN") and val:
                    return val
        except OSError:
            pass
    return ""


TOKEN = _load_token()
MAX_INPUT_BYTES = 2 * 1024 * 1024
MAX_OUTPUT_PREVIEW = 1800
LUNE_TIMEOUT = 60  # Aspect can be slower

ROOT = Path(__file__).resolve().parent.parent
DUMPS = ROOT / "dumps"
ORIGINAL = DUMPS / "original"
DUMPED = DUMPS / "dumped"
RUNNER = ROOT / "runner.luau"
PY_RUNNER = Path(__file__).resolve().parent / "py_runner.py"

ORIGINAL.mkdir(parents=True, exist_ok=True)
DUMPED.mkdir(parents=True, exist_ok=True)


def find_lune() -> str:
    override = os.environ.get("LUNE_PATH")
    if override and Path(override).is_file():
        return override
    which = shutil.which("lune")
    if which:
        return which
    for c in [
        Path.home() / ".lune" / "bin" / "lune",
        Path("/usr/local/bin/lune"),
        Path("/usr/bin/lune"),
    ]:
        try:
            if c.is_file() and os.access(c, os.X_OK):
                return str(c)
        except OSError:
            pass
    return "lune"


LUNE_BIN = find_lune()
try:
    HAS_LUNE = Path(LUNE_BIN).is_file() and os.access(LUNE_BIN, os.X_OK)
except OSError:
    HAS_LUNE = False

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

_cooldowns: dict[int, float] = {}
COOLDOWN_S = 5.0

CODEBLOCK_RE = re.compile(r"```(?:lua|luau|txt|text)?\s*\n?(.*?)```", re.DOTALL | re.IGNORECASE)
LINK_RE = re.compile(r"https?://\S+")


def extract_codeblock(text: str) -> str | None:
    m = CODEBLOCK_RE.search(text or "")
    return m.group(1).strip() if m and m.group(1).strip() else None


def extract_link(text: str) -> str | None:
    m = LINK_RE.search(text or "")
    if not m:
        return None
    return re.sub(r"[\]\)\'\"\>.,;]+$", "", m.group(0))


async def fetch_url(url: str) -> str | None:
    if "pastebin.com/" in url and "/raw/" not in url:
        url = url.replace("pastebin.com/", "pastebin.com/raw/")
    try:
        timeout = aiohttp.ClientTimeout(total=15)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.get(url, headers={"User-Agent": "logger-spy-bot/1.0"}) as resp:
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
            messages.append(await msg.channel.fetch_message(msg.reference.message_id))
        except Exception:
            pass

    for m in messages:
        if m.attachments:
            att = m.attachments[0]
            if att.size and att.size > MAX_INPUT_BYTES:
                return None, "attachment too large"
            try:
                data = await att.read()
                return data.decode("utf-8", errors="replace"), f"attachment:{att.filename}"
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

    return None, "no input (attach a .lua file, paste a code block, or include a link)"


async def run_tracer_python(source: str, stem: str) -> tuple[bool, str, str]:
    in_path = ORIGINAL / f"{stem}.lua"
    out_path = DUMPED / f"{stem}_reconstructed.lua"
    in_path.write_text(source.replace("\r\n", "\n").replace("\r", "\n"), encoding="utf-8")
    try:
        import importlib.util

        spec = importlib.util.spec_from_file_location("py_runner", PY_RUNNER)
        if spec is None or spec.loader is None:
            return False, "py_runner.py missing next to discord_bot.py", ""
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        reconstructed = mod.reconstruct_file(in_path, out_path)
        return True, str(out_path), reconstructed
    except Exception as e:
        return False, f"python runner error: {e}", ""


async def run_lune(source: str, stem: str, aspect: bool = False) -> tuple[bool, str, str]:
    in_path = ORIGINAL / f"{stem}.lua"
    suffix = "_aspect.lua" if aspect else "_reconstructed.lua"
    out_path = DUMPED / f"{stem}{suffix}"
    in_path.write_text(source.replace("\r\n", "\n").replace("\r", "\n"), encoding="utf-8")
    cmd = [LUNE_BIN, "run", str(RUNNER)]
    if aspect:
        cmd.append("--aspect")
    cmd.extend([str(in_path), str(out_path)])
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd, cwd=str(ROOT), stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
        )
        try:
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=LUNE_TIMEOUT)
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            return False, "timeout", ""
        if out_path.is_file():
            reconstructed = out_path.read_text(encoding="utf-8", errors="replace")
            return True, str(out_path), reconstructed
        err = (stderr or stdout).decode("utf-8", errors="replace") or "no output"
        return False, err, ""
    except FileNotFoundError:
        return False, f"lune not found ({LUNE_BIN})", ""
    except Exception as e:
        return False, f"runner error: {e}", ""


async def run_tracer(source: str, stem: str) -> tuple[bool, str, str]:
    if HAS_LUNE:
        ok, path, text = await run_lune(source, stem, aspect=False)
        if ok:
            return ok, path, text
    return await run_tracer_python(source, stem)


async def run_aspect(source: str, stem: str) -> tuple[bool, str, str]:
    if not HAS_LUNE:
        return False, "Aspect requires Lune (not available on this host)", ""
    return await run_lune(source, stem, aspect=True)


def make_discord_file(text: str, filename: str) -> discord.File:
    buf = io.BytesIO(text.encode("utf-8"))
    buf.seek(0)
    return discord.File(buf, filename=filename)


async def handle_reconstruct(msg: discord.Message, *, aspect: bool):
    now = asyncio.get_event_loop().time()
    last = _cooldowns.get(msg.author.id, 0)
    if now - last < COOLDOWN_S:
        await msg.reply(f"cooldown — wait {COOLDOWN_S - (now - last):.1f}s")
        return
    _cooldowns[msg.author.id] = now

    async with msg.channel.typing():
        source, origin = await get_source_from_message(msg)
        if not source:
            cmd = ".la" if aspect else ".l"
            await msg.reply(
                f"**`{cmd}`** — reconstruct Lua\n"
                "• file attachment\n• ``` code block\n• raw link\n• reply to a message with any of those\n\n"
                f"_{origin}_"
            )
            return
        if len(source.encode("utf-8")) > MAX_INPUT_BYTES:
            await msg.reply("input too large (max 2 MB)")
            return

        stem = f"{msg.author.id}_{msg.id}"
        if aspect:
            ok, path_or_err, reconstructed = await run_aspect(source, stem)
            mode = "aspect"
            filename = "aspect_dump.lua"
        else:
            ok, path_or_err, reconstructed = await run_tracer(source, stem)
            mode = "lune" if HAS_LUNE else "python-fallback"
            filename = "reconstructed.lua"

        if not ok and not reconstructed:
            await msg.reply(f"reconstruction failed:\n```diff\n- {(path_or_err or 'error')[:500]}\n```")
            return
        if not reconstructed and Path(path_or_err).is_file():
            reconstructed = Path(path_or_err).read_text(encoding="utf-8", errors="replace")

        header = (
            f"reconstructed for {msg.author.mention} ({mode})\n"
            f"origin: `{origin}` · {len(source)} → {len(reconstructed)} chars"
        )
        try:
            await msg.reply(header, file=make_discord_file(reconstructed, filename))
        except discord.HTTPException:
            await msg.reply(header + "\n```lua\n" + reconstructed[:MAX_OUTPUT_PREVIEW] + "\n```")


@client.event
async def on_ready():
    print(f"logged in as {client.user}")
    print(f"HAS_LUNE={HAS_LUNE} bin={LUNE_BIN}")
    print(f"py_runner exists={PY_RUNNER.is_file()}")
    if not HAS_LUNE:
        print("Using pure-Python fallback for .l (Aspect / .la unavailable without Lune)")


@client.event
async def on_message(msg: discord.Message):
    if msg.author.bot:
        return
    content = (msg.content or "").strip()
    try:
        if re.match(r"^\.la(\s|$)", content, re.IGNORECASE):
            await handle_reconstruct(msg, aspect=True)
        elif re.match(r"^\.l(\s|$)", content, re.IGNORECASE):
            await handle_reconstruct(msg, aspect=False)
    except Exception:
        traceback.print_exc()
        try:
            await msg.reply("internal error — check bot logs")
        except Exception:
            pass


def main():
    if not TOKEN:
        print("Set DISCORD_BOT_TOKEN first")
        print("Checked env: DISCORD_BOT_TOKEN, BOT_TOKEN, TOKEN, DISCORD_TOKEN")
        print("Also checked .env next to bot / /home/container/.env")
        print("On Wispbyte: create file .env with one line:")
        print("  DISCORD_BOT_TOKEN=your_token_here")
        raise SystemExit(1)
    client.run(TOKEN)


if __name__ == "__main__":
    main()
