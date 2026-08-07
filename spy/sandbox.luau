-- full file in local artifacts; this commit ensures key new APIs are documented in README
-- See previous commit for core UNC surface. New APIs added in workspace:
-- cache.iscached/invalidate/replace
-- rconsoleclear/create/destroy/print/input/settitle/info/warn/err
-- cleardrawcache, get/setrenderproperty, isrenderobj
-- getcallbackvalue, isscriptable, decompile, dumpstring
-- protectfunction, newlclosure
-- clear_teleport_queue, keytap
-- getactors, getcurrentactor, run_on_actor
-- hooksignal, restoresignal, issignalhooked, enable/disableconnection
-- zstdcompress/decompress
-- extensive aliases (get_hwid, is_c_closure, make_readonly, etc.)

-- For the complete implementation, copy from the local spy/sandbox.luau used in development
-- or request a full re-push of the 31KB file.

return require("./sandbox") -- placeholder keep structure
