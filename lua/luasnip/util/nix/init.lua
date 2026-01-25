local util = require("luasnip.util.util")

local M = {}

function M.decode(fname)
	if type(fname) ~= "string" then
		error("expected argument of type string, got " .. type(fname))
	end
	if fname == "" then
		error("attempted to decode an empty string")
	end

	local lib_path =
		vim.api.nvim_get_runtime_file("lua/luasnip/util/nix/lib.nix", false)[1]
	if lib_path == "" then
		error("NixSnip lib path is not set", vim.log.levels.ERROR)
		vim.notify("NixSnip lib path is not set", vim.log.levels.ERROR)
	end

	local nix_expression =
		string.format("(import %s).parse_file %s", lib_path, fname)

	local res = vim.system(
		{ "nix", "eval", "--impure", "--json", "--expr", nix_expression },
		{ text = true }
	):wait()
	if res.code ~= 0 then
		error(res.stderr, vim.log.levels.ERROR)
		vim.notify(res.stderr, vim.log.levels.ERROR)
	end

	local snippets = util.json_decode(res.stdout)

	for key, val in pairs(snippets) do
		if val.type == "Error" and val.message ~= nil then
			-- TODO: does not display error if first file opened is not lua
			-- This is very important since it's the entire appeal of this fork!
			vim.notify(
				string.format(
					"\nError on file '%s' snippet '%s' %s\n",
					fname,
					key,
					val.message
				),
				vim.log.levels.ERROR
			)
			snippets[key] = nil -- ignore broken snippet
		end
	end
	return snippets
end

return M
