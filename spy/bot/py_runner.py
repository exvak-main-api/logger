"""
Pure-Python reconstruction fallback for environments without Lune.
Output is clean: OSE header + reconstructed bodies only (no original source dump).
"""

from __future__ import annotations

import re
from pathlib import Path

OSE_HEADER = (
    "-- [[\n"
    "this file was constructed by OSE env logger\n"
    "@ discord.gg/uEWVqpnyf2\n"
    "]] --\n"
    "\n"
)


def _decode_lua_string(s: str) -> str:
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            mapping = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
            if n in mapping:
                out.append(mapping[n])
                i += 2
                continue
            if n.isdigit():
                j = i + 1
                while j < len(s) and s[j].isdigit() and j < i + 4:
                    j += 1
                try:
                    out.append(chr(int(s[i + 1 : j]) % 256))
                except Exception:
                    out.append(s[i:j])
                i = j
                continue
            out.append(n)
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def extract_long_strings(src: str) -> list[str]:
    results = []
    for m in re.finditer(r"\[(=*)\[(.*?)\]\1\]", src, re.DOTALL):
        body = m.group(2)
        if len(body) > 20:
            results.append(body)
    return results


def extract_loadstring_calls(src: str) -> list[str]:
    bodies = []
    for m in re.finditer(
        r"""(?:loadstring|load)\s*\(\s*(["'])((?:\\.|(?!\1).)*)\1""",
        src,
        re.DOTALL,
    ):
        bodies.append(_decode_lua_string(m.group(2)))
    for m in re.finditer(
        r"(?:loadstring|load)\s*\(\s*\[(=*)\[(.*?)\]\1\]",
        src,
        re.DOTALL,
    ):
        bodies.append(m.group(2))
    return bodies


def extract_game_api_calls(src: str) -> list[str]:
    patterns = [
        r"game:GetService\s*\(\s*['\"][^'\"]+['\"]\s*\)",
        r"workspace(?:\.[A-Za-z_][\w]*)+",
        r"game(?:\.[A-Za-z_][\w]*)+",
        r"(?:hookfunction|hookmetamethod|getgenv|getrenv|getrawmetatable|setclipboard|writefile|readfile|request|http_request|firetouchinterest|firesignal)\s*\([^)]*\)",
        r"Instance\.new\s*\(\s*['\"][^'\"]+['\"]\s*\)",
    ]
    found = []
    seen = set()
    for pat in patterns:
        for m in re.finditer(pat, src):
            s = m.group(0)
            if s not in seen:
                seen.add(s)
                found.append(s)
    return found


def simple_beautify(src: str) -> str:
    src = src.replace("\r\n", "\n").replace("\r", "\n")
    src = re.sub(r"\n{3,}", "\n\n", src)
    src = re.sub(r";(?=\S)", ";\n", src)
    return src.strip()


def reconstruct(source: str) -> str:
    parts: list[str] = []

    load_bodies = extract_loadstring_calls(source)
    long_strs = extract_long_strings(source)
    api_calls = extract_game_api_calls(source)

    if api_calls:
        for c in api_calls[:200]:
            parts.append(c)

    if load_bodies:
        for body in load_bodies:
            pretty = simple_beautify(body)
            if len(pretty) > 200_000:
                pretty = pretty[:200_000]
            parts.append(pretty)
            for nb in extract_loadstring_calls(body)[:8]:
                nested = simple_beautify(nb)
                if nested:
                    parts.append(nested[:50000])

    if not load_bodies:
        for s in long_strs:
            if any(k in s for k in ("function", "local ", "return", "game", "getgenv", "loadstring")):
                parts.append(simple_beautify(s)[:80000])

    # If nothing useful extracted, emit normalized source as last resort (still no banners)
    if not parts:
        parts.append(simple_beautify(source))

    core = "\n\n".join(p for p in parts if p).strip()
    return OSE_HEADER + core + "\n"


def reconstruct_file(input_path: str | Path, output_path: str | Path) -> str:
    src = Path(input_path).read_text(encoding="utf-8", errors="replace")
    out = reconstruct(src)
    Path(output_path).write_text(out, encoding="utf-8")
    return out


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("usage: python py_runner.py <input.lua> [output.lua]")
        raise SystemExit(1)
    inp = sys.argv[1]
    outp = sys.argv[2] if len(sys.argv) > 2 else inp.rsplit(".", 1)[0] + "_reconstructed.lua"
    reconstruct_file(inp, outp)
    print("success")
    print(outp)
