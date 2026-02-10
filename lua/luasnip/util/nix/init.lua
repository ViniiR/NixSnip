local util = require("luasnip.util.util")
local config = require("luasnip.session").config

local M = {}

function M.is_nix_manifest(fname)
	-- NOTE: manifest.nix is a special hard-coded name, substitute for package.json(c)
	return vim.fs.basename(fname) == "manifest.nix"
end

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
		vim.notify("NixSnip lib path is not set", vim.log.levels.ERROR)
		error("NixSnip lib path is not set", vim.log.levels.ERROR)
	end

	local nix_expression =
		string.format("(import %s).parse_file %s", lib_path, fname)

	if M.is_nix_manifest(fname) then
		if config.nixsnip.enforce_manifest_properties then
			nix_expression = string.format(
				"(import %s).parse_manifest_secure %s",
				lib_path,
				fname
			)
		else
			nix_expression =
				string.format("(import %s).parse_manifest %s", lib_path, fname)
		end
	end

	local res = vim.system(
		{ "nix", "eval", "--impure", "--json", "--expr", nix_expression },
		{ text = true }
	):wait()
	if res.code ~= 0 then
		vim.notify(res.stderr, vim.log.levels.ERROR)
		error(res.stderr, vim.log.levels.ERROR)
	end

	if M.is_nix_manifest(fname) then
		local decoded = util.json_decode(res.stdout)

		-- TODO: parse manifest.contributes.snippets errors
		if decoded.type == "Error" and decoded.content ~= nil then
			for index, value in ipairs(decoded.content) do
				if value.type == "Error" then
					vim.notify(
						string.format(
							"\nManifest property: 'contributes.snippets[%i]%s\n",
							index - 1,
							value.message
						),
						vim.log.levels.ERROR
					)
					return {}
				end
			end
		elseif decoded.type == "Error" then
			vim.notify(
				string.format("\n%s\n", decoded.message),
				vim.log.levels.ERROR
			)
			return {}
		end

		return decoded
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
