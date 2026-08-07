"""Discord bot for logger/spy. .l uses Aspect (Lune) → tracer → Python fallback."""

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


def _load_dotenv() -> dict[str, str]:
    found: dict[str, str] = {}
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
                if k and val and k not in found:
                    found[k] = val
        except OSError:
            pass
    return found


_DOTENV = _load_dotenv()


def _env(key: str, default: str = "") -> str:
    return (os.environ.get(key) or _DOTENV.get(key) or default).strip()


def _load_token() -> str:
    for key in ("DISCORD_BOT_TOKEN", "BOT_TOKEN", "TOKEN", "DISCORD_TOKEN"):
        v = _env(key)
        if v:
            return v
    return ""


TOKEN = _load_token()
MAX_INPUT_BYTES = 2 * 1024 * 1024
MAX_OUTPUT_PREVIEW = 1800
LUNE_TIMEOUT = 90

ROOT = Path(__file__).resolve().parent.parent
DUMPS = ROOT / "dumps"
ORIGINAL = DUMPS / "original"
DUMPED = DUMPS / "dumped"
RUNNER = ROOT / "runner.luau"
PY_RUNNER = Path(__file__).resolve().parent / "py_runner.py"

ORIGINAL.mkdir(parents=True, exist_ok=True)
DUMPED.mkdir(parents=True, exist_ok=True)

OSE_HEADER = (
    "-- [[\n"
    "this file was constructed by OSE env logger\n"
    "@ discord.gg/uEWVqpnyf2\n"
    "]] --\n"
    "\n"
)


def _is_usable_binary(path: Path) -> bool:
    try:
        if not path.is_file():
            return False
        if os.access(path, os.X_OK):
            return True
        return os.access(path, os.R_OK)
    except OSError:
        return False


def find_lune() -> tuple[str, str]:
    override = _env("LUNE_PATH")
    if override:
        p = Path(override).expanduser()
        if _is_usable_binary(p):
            return str(p.resolve()), "LUNE_PATH"
        for child in ("lune", "bin/lune"):
            c = p / child
            if _is_usable_binary(c):
                return str(c.resolve()), f"LUNE_PATH/{child}"

    which = shutil.which("lune")
    if which and _is_usable_binary(Path(which)):
        return which, "PATH"

    candidates = [
        Path("/home/container/lune"),
        Path("/home/container/lune/bin/lune"),
        Path("/home/container/.lune/bin/lune"),
        Path("/home/container/bin/lune"),
        Path.home() / ".lune" / "bin" / "lune",
        Path.home() / "lune",
        Path("/usr/local/bin/lune"),
        Path("/usr/bin/lune"),
        ROOT / "lune",
        Path.cwd() / "lune",
    ]
    for c in candidates:
        if _is_usable_binary(c):
            return str(c.resolve()), str(c)

    return "lune", "fallback-string"


LUNE_BIN, LUNE_SOURCE = find_lune()
try:
    HAS_LUNE = _is_usable_binary(Path(LUNE_BIN))
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


def ensure_ose_header(text: str) -> str:
    """Guarantee OSE header is present once; strip other banners."""
    if not text:
        return OSE_HEADER + "-- (empty dump)\n"
    body = text
    # strip existing leading block comments / banners
    body = re.sub(r"^\s*--\s*\[\[.*?\]\]\s*--?\s*", "", body, count=1, flags=re.DOTALL)
    body = re.sub(r"^\s*--\[\[.*?\]\]\s*", "", body, count=1, flags=re.DOTALL)
    body = body.lstrip("\n")
    if body.startswith("-- [[") and "OSE env logger" in body[:200]:
        return body if body.endswith("\n") else body + "\n"
    return OSE_HEADER + body.rstrip() + "\n"


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
        reconstructed = ensure_ose_header(reconstructed)
        out_path.write_text(reconstructed, encoding="utf-8")
        return True, str(out_path), reconstructed
    except Exception as e:
        return False, f"python runner error: {e}", ""


async def run_lune_auto(source: str, stem: str) -> tuple[bool, str, str]:
    """Runner auto mode: Aspect first, tracer fallback. No extra flags."""
    in_path = ORIGINAL / f"{stem}.lua"
    out_path = DUMPED / f"{stem}_reconstructed.lua"
    in_path.write_text(source.replace("\r\n", "\n").replace("\r", "\n"), encoding="utf-8")
    cmd = [LUNE_BIN, "run", str(RUNNER), str(in_path), str(out_path)]
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
            reconstructed = ensure_ose_header(reconstructed)
            out_path.write_text(reconstructed, encoding="utf-8")
            return True, str(out_path), reconstructed
        err = (stderr or stdout).decode("utf-8", errors="replace") or "no output"
        return False, err, ""
    except FileNotFoundError:
        return False, f"lune not found ({LUNE_BIN})", ""
    except PermissionError:
        return False, f"lune not executable ({LUNE_BIN}) — try: chmod +x {LUNE_BIN}", ""
    except Exception as e:
        return False, f"runner error: {e}", ""


async def run_reconstruct(source: str, stem: str) -> tuple[bool, str, str, str]:
    """Returns ok, path_or_err, text, mode."""
    if HAS_LUNE:
        ok, path, text = await run_lune_auto(source, stem)
        if ok:
            return True, path, text, "aspect/auto"
    ok, path, text = await run_tracer_python(source, stem)
    return ok, path, text, "python-fallback"


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
                "**`.l`** — reconstruct Lua (Aspect → tracer → python)\n"
                "• file attachment\n• ``` code block\n• raw link\n• reply to a message with any of those\n\n"
                f"_{origin}_"
            )
            return
        if len(source.encode("utf-8")) > MAX_INPUT_BYTES:
            await msg.reply("input too large (max 2 MB)")
            return

        stem = f"{msg.author.id}_{msg.id}"
        ok, path_or_err, reconstructed, mode = await run_reconstruct(source, stem)

        if not ok and not reconstructed:
            await msg.reply(f"reconstruction failed:\n```diff\n- {(path_or_err or 'error')[:500]}\n```")
            return
        if not reconstructed and Path(path_or_err).is_file():
            reconstructed = Path(path_or_err).read_text(encoding="utf-8", errors="replace")

        reconstructed = ensure_ose_header(reconstructed)

        # Discord message is just the file — no extra banners in the file itself
        note = f"done for {msg.author.mention} · `{mode}` · {len(source)} → {len(reconstructed)} chars"
        try:
            await msg.reply(note, file=make_discord_file(reconstructed, "reconstructed.lua"))
        except discord.HTTPException:
            await msg.reply(note + "\n```lua\n" + reconstructed[:MAX_OUTPUT_PREVIEW] + "\n```")


@client.event
async def on_ready():
    print(f"logged in as {client.user}")
    print(f"HAS_LUNE={HAS_LUNE} bin={LUNE_BIN} (via {LUNE_SOURCE})")
    print(f"py_runner exists={PY_RUNNER.is_file()}")
    print(f"ROOT={ROOT}")
    if not HAS_LUNE:
        print("Using pure-Python fallback for .l")
        print("Hint: set LUNE_PATH=/home/container/lune in .env and chmod +x that file")
        for p in (
            "/home/container/lune",
            "/home/container/lune/bin/lune",
            "/home/container/.lune/bin/lune",
        ):
            pp = Path(p)
            print(f"  check {p}: exists={pp.exists()} is_file={pp.is_file() if pp.exists() else False}")


@client.event
async def on_message(msg: discord.Message):
    if msg.author.bot:
        return
    content = (msg.content or "").strip()
    # .l and .la both go through the same pipeline (Aspect-first)
    if re.match(r"^\.la?(\s|$)", content, re.IGNORECASE):
        try:
            await handle_l(msg)
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
        raise SystemExit(1)
    client.run(TOKEN)


if __name__ == "__main__":
    main()
