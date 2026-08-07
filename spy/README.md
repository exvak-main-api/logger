# logger / spy

Expression-tree based Roblox/Luau tracer sandbox that reconstructs executed code for logging.

Inspired by UNC/sUNC surfaces and tools like [unveilr](https://github.com/bbbbbbbbbbbbbb121/thee-bot/tree/main/unveilr).

## Modules

| File | Role |
|------|------|
| `logger.luau` | Levelled logger, dump/filter helpers |
| `expr.luau` | Weak-keyed expression storage |
| `compiler.luau` | Expression tree → source reconstruction |
| `proxy.luau` | Proxy objects + full operator overloading |
| `sandbox.luau` | Full executor env (hooks, debug, fs, input, Drawing, syn.oth, …) |
| `test.luau` | Lune test harness |
| `init.luau` | Package entry |

## Run with Lune

```bash
lune run spy/test.luau
```

## Coverage highlights

- Environments: `getgenv`, `getrenv`, `getfenv`/`setfenv`, `getsenv`
- Closures: `hookfunction`, `hookmetamethod`, `clonefunction`, `newcclosure`, `is*closure`, `restorefunction`
- Metatable: `getrawmetatable`, `setrawmetatable`, `setreadonly`, `get/setnamecallmethod`
- Instances: `gethui`, `cloneref`, `fire*`, hidden properties, `getcallbackvalue`
- Scripts: bytecode/closure/hash, `getcallingscript`, `decompile`
- Debug library (upvalues, constants, protos, stack)
- Filesystem, clipboard, FPS, HWID, input simulation
- `syn` / `oth` / `cache` / `crypt` / Drawing / WebSocket
- Console (`rconsole*`), actors, signals, compression (lz4/zstd)

All calls are logged as reconstructed Lua source.
