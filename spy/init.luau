local M = {
	Logger = require("./logger"),
	Expr = require("./expr"),
	Compiler = require("./compiler"),
	Proxy = require("./proxy"),
	Sandbox = require("./sandbox"),
}

-- Aspect is optional / heavy. Lazy-load so requiring the package never fails
-- when aspect.lua or its deps (core/io/apidump.json) are missing.
function M.aspect()
	return require("./aspect")
end

function M.bridge()
	return require("./aspect_bridge")
end

return M
