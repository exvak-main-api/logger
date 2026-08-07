"""
Pure-Python reconstruction fallback for environments without Lune (e.g. Pydroid 3).
"""

from __future__ import annotations

import re
from pathlib import Path


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


def extract_http_urls(src: str) -> list[str]:
    urls = re.findall(r"https?://[^\s'\"\\\]\)]+", src)
    seen = set()
    out = []
    for u in urls:
        u = re.sub(r"[.,;]+$", "", u)
        if u not in seen:
            seen.add(u)
            out.append(u)
    return out


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
    return src.strip() + "\n"


def reconstruct(source: str) -> str:
    lines: list[str] = []
    lines.append("-- reconstructed by logger/spy (Python fallback \u2014 no Lune)")
    lines.append("-- note: static heuristic dump; not full VM execution")
    lines.append("")

    load_bodies = extract_loadstring_calls(source)
    long_strs = extract_long_strings(source)
    urls = extract_http_urls(source)
    api_calls = extract_game_api_calls(source)

    if urls:
        lines.append("-- === URLs found ===")
        for u in urls[:50]:
            lines.append(f"-- {u}")
        lines.append("")

    if api_calls:
        lines.append("-- === notable API / path calls ===")
        for c in api_calls[:100]:
            lines.append(c)
        lines.append("")

    if load_bodies:
        lines.append("-- === loadstring / load bodies ===")
        for i, body in enumerate(load_bodies, 1):
            lines.append(f"-- --- load body #{i} ({len(body)} bytes) ---")
            nested = extract_loadstring_calls(body)
            pretty = simple_beautify(body)
            if len(pretty) > 100_000:
                lines.append(pretty[:100_000])
                lines.append(f"-- ... truncated ({len(pretty)} total chars)")
            else:
                lines.append(pretty)
            if nested:
                lines.append(f"-- (nested loadstring count: {len(nested)})")
                for j, nb in enumerate(nested[:5], 1):
                    lines.append(f"-- nested #{j}:")
                    lines.append(simple_beautify(nb)[:20000])
            lines.append("")

    code_like = []
    for s in long_strs:
        if any(k in s for k in ("function", "local ", "return", "game", "getgenv", "loadstring")):
            code_like.append(s)
    if code_like and not load_bodies:
        lines.append("-- === long strings that look like code ===")
        for i, body in enumerate(code_like[:10], 1):
            lines.append(f"-- --- long string #{i} ---")
            lines.append(simple_beautify(body)[:50000])
            lines.append("")

    lines.append("-- === original source (normalized) ===")
    cleaned = simple_beautify(source)
    if len(cleaned) > 150_000:
        lines.append(cleaned[:150_000])
        lines.append(f"-- ... truncated original ({len(cleaned)} chars)")
    else:
        lines.append(cleaned)

    return "\n".join(lines)


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
