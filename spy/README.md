# logger / spy

Expression-tree based Roblox/Luau tracer sandbox that reconstructs executed code.

## Structure

- `logger.luau` – logging with levels
- `expr.luau` – weak expression storage
- `compiler.luau` – expression → source reconstruction
- `proxy.luau` – proxy objects with full operator overloading
- `sandbox.luau` – environment with game/workspace + exploit APIs (hookfunction, etc.)
- `test.luau` – simple Lune test harness

## Run (Lune)

```bash
lune run spy/test.luau
```

Requires [Lune](https://github.com/lune-org/lune).
