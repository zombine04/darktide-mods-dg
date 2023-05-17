local mod = get_mod("WhatTheLocalization")
local LocalizationManager = require("scripts/managers/localization/localization_manager")

local registered_fixes = mod:persistent_table("registered_fixes")

mod.on_enabled = function(initial_call)
	table.clear(Managers.localization._string_cache)
	table.clear(registered_fixes)
	local lang = Managers.localization._language
	local fix_templates = mod:io_dofile("WhatTheLocalization/scripts/mods/WhatTheLocalization/WTL_fix_templates")
	for _, fix in ipairs(fix_templates) do
		local lang_match = false
		if fix.locales then
			for _, locale in ipairs(fix.locales) do
				if locale == lang then
					lang_match = true
					break
				end
			end
		else
			lang_match = true
		end
		if lang_match then
			if fix.loc_keys then
				for _, loc_key in ipairs(fix.loc_keys) do
					registered_fixes[loc_key] = registered_fixes[loc_key] or {}
					table.insert(registered_fixes[loc_key], fix.handle_func)
				end
			end
		end
	end
end

mod.on_disabled = function(initial_call)
	table.clear(Managers.localization._string_cache)
end

mod:hook(LocalizationManager, "_lookup", function(func, self, key)
	local ret = func(self, key)
	local fixes = registered_fixes[key]
	if not fixes then
		return ret
	end
	for _, handle_func in ipairs(fixes) do
		ret = handle_func(Managers.localization._language, ret)
	end
	return ret
end)

mod.toggle_debug_mode = function()
	if not Managers.ui:chat_using_input() then
		local debug_mode = not mod:get("enable_debug_mode")
		mod:set("enable_debug_mode", debug_mode, false)
		if debug_mode then
			mod:notify(mod:localize("message_debug_mode_on"))
		else
			mod:notify(mod:localize("message_debug_mode_off"))
		end
	end
end

mod:hook(LocalizationManager, "localize", function(func, self, key, no_cache, context)
	local ret = func(self, key, no_cache, context)
	return mod:get("enable_debug_mode") and key or ret
end)

local visualize_mapping = {
	[" "] = "",
	["\t"] = "",
	["\n"] = "\n",
	["\r"] = "",
}

mod:command("loc", mod:localize("loc_command_description"), function(key)
	if not key then
		mod:echo(mod:localize("loc_command_missing_key"))
		return
	end
	local message = Managers.localization:_lookup(key)
	if message then
		message = message:gsub("%%", "%%%%")
		if mod:get("loc_command_output_visualize") then
			for pat, repl in pairs(visualize_mapping) do
				message = message:gsub(pat, repl)
			end
		end
		mod:echo(message)
		return
	end
	mod:echo(mod:localize("loc_command_not_found"))
end)
